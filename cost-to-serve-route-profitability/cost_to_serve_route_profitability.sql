/*===========================================================
COST-TO-SERVE, ROUTE ECONOMICS &
CUSTOMER PROFITABILITY ANALYSIS

## THE BUSINESS PROBLEM

Revenue alone does not tell management whether a shipment,
customer, or route is worth serving.

A high revenue route can still destroy value if operating
costs consistently exceed what customers are paying.

Likewise, a large customer may generate significant revenue
while contributing weak profit once the cost of fulfilling
their shipments is considered.

Management therefore needs to understand where money is
actually being made across the logistics network and where
commercial activity is consuming value instead.

The analysis focuses on three levels of profitability:

SHIPMENT ECONOMICS
Is each individual shipment generating a positive return?

ROUTE ECONOMICS
Which origin and destination combinations consistently create
or destroy profit?

CUSTOMER ECONOMICS
Which customer relationships contribute the greatest
commercial value after shipment costs are considered?

The goal is to move from revenue reporting to profitability
management.

===========================================================*/

/*-----------------------------------------------------------
CORRECTION LOG (read this before running the queries below)

Three issues were found while reviewing this script against
the actual data and fixed before this version was finalized.

1. ROUTE JOIN FAN-OUT (v_profitability)
   The routes table only covers 8 ports, which means there
   are at most 64 possible origin-destination pairs. The
   table actually holds 3,000 route rows, so on average each
   origin-destination pair appears close to 47 times with
   different distance, time, and fuel figures. The original
   view joined shipments to routes on origin_port and
   destination_port alone. Because that join key is not
   unique in the routes table, every shipment matched dozens
   of route rows at once, and each shipment was duplicated
   in the result set. Any average or total built on top of
   that view was inflated and unreliable.
   FIX: routes are pre-aggregated to one row per
   origin-destination pair (using AVG on distance, time, and
   fuel cost) inside a subquery before the join happens.

2. FUEL PRICE VS SHIPMENT COST (biased join)
   The original query joined fuel_data to shipments on
   YEAR(date) = YEAR(departure_date) only, with no shared key
   between a fuel record and a specific shipment. That turns
   the join into a partial cross join: every fuel price row
   for a year gets matched against every shipment in that
   same year, and the match has nothing to do with which
   region actually shipped the cargo. Because different years
   have different shipment volumes, the resulting averages
   end up skewed toward whichever year happens to contribute
   the most matched rows, not a true regional average.
   FIX: fuel prices are averaged by region and year first,
   shipment cost is averaged by year first, and only those
   two already-summarized result sets are joined together.
   That keeps the comparison honest: one row per region per
   year, sitting next to one row per year, nothing multiplied.

3. GROUPING BY A CONTINUOUS NUMBER (shipment weight)
   The original "weight vs profitability" query grouped
   directly by weight_tons. Since weight is recorded to two
   decimal places, almost every shipment has a distinct
   weight, so the GROUP BY produced close to one row per
   shipment. It looked like an aggregation but was not doing
   any real grouping.
   FIX: weight is bucketed into ranges (under 50 tons, 50 to
   99, and so on) so the comparison actually pools shipments
   together.

4. CUSTOMER GROUPING BY COMPANY NAME ONLY
   The customers_maritime table has 3,000 rows, but only a
   handful of company names repeat across them (for example,
   "Toyota Logistics" appears under many different customer
   IDs, countries, and contract values). Grouping by
   company_name alone silently merges hundreds of distinct
   customer accounts into a single row, which misrepresents
   "customer relationship" profitability.
   FIX: the grouping now includes customer_id alongside
   company_name, so profitability is measured at the actual
   account level, with company_name kept only as a label.

A data quality note worth flagging separately: some shipment
records have an arrival_date earlier than the departure_date,
which is not physically possible. Neither this script nor the
two others compute duration directly from those two columns,
so the queries below are not affected, but anyone extending
this analysis to calculate transit time from departure and
arrival dates should clean or exclude those rows first.
-----------------------------------------------------------*/

/*-----------------------------------------------------------
CREATE THE PROFITABILITY LAYER

Combine shipment financials with route characteristics to
create a single view of revenue, cost, profit, distance,
transit time, and fuel cost.

This connects commercial performance with the operational
characteristics of each route. Routes are averaged to one
row per origin-destination pair first, so a shipment is
never duplicated by a route table that holds many records
for the same lane.
-----------------------------------------------------------*/

IF OBJECT_ID('v_profitability', 'V') IS NOT NULL
    DROP VIEW v_profitability;
GO

CREATE VIEW v_profitability AS
SELECT
    s.shipment_id,
    s.customer_id,
    s.origin_port,
    s.destination_port,
    s.revenue,
    s.cost,
    (s.revenue - s.cost) AS profit,
    r.avg_distance_km AS distance_km,
    r.avg_time_days AS average_time_days,
    r.avg_fuel_cost AS fuel_cost
FROM shipments s
LEFT JOIN (
    SELECT
        origin_port,
        destination_port,
        AVG(distance_km) AS avg_distance_km,
        AVG(average_time_days) AS avg_time_days,
        AVG(fuel_cost) AS avg_fuel_cost
    FROM routes
    GROUP BY origin_port, destination_port
) r
    ON s.origin_port = r.origin_port
    AND s.destination_port = r.destination_port;
GO

/*-----------------------------------------------------------
THE PROFITABILITY BASELINE

Start with the commercial position of the entire shipment
portfolio.

Total revenue shows what the business earned from shipments.

Total cost shows the recorded cost associated with serving
those shipments.

The difference provides the overall profit generated by the
shipment portfolio.

This establishes the baseline before investigating where
profit is being created or lost.
-----------------------------------------------------------*/

SELECT
    SUM(revenue) AS total_revenue,
    SUM(cost) AS total_cost,
    SUM(revenue - cost) AS total_profit
FROM shipments;

/*-----------------------------------------------------------
WHERE DOES THE NETWORK MAKE MONEY?

Evaluate each origin and destination pair as its own
commercial lane.

For every route, measure shipment volume, revenue generated,
cost incurred, total profit contribution, and average profit
earned per shipment.

Ordering routes from lowest profit upward immediately exposes
the lanes requiring commercial or operational attention.
-----------------------------------------------------------*/

SELECT
    origin_port,
    destination_port,
    COUNT(*) AS shipments,
    SUM(revenue) AS total_revenue,
    SUM(cost) AS total_cost,
    SUM(revenue - cost) AS total_profit,
    AVG(revenue - cost) AS avg_profit_per_shipment
FROM shipments
GROUP BY origin_port, destination_port
ORDER BY total_profit ASC;

/*-----------------------------------------------------------
LOSS-MAKING ROUTE WATCHLIST

Isolate routes where total shipment costs exceed total
revenue.

These lanes are directly destroying value based on the
recorded shipment economics and should be investigated for
pricing, cost, volume, or operating efficiency issues.
-----------------------------------------------------------*/

SELECT
    origin_port,
    destination_port,
    SUM(revenue - cost) AS total_profit
FROM shipments
GROUP BY origin_port, destination_port
HAVING SUM(revenue - cost) < 0;

/*-----------------------------------------------------------
DISTANCE COST EFFICIENCY

Standardize shipment cost against route distance by
calculating the recorded cost per kilometre.

This makes it easier to compare transportation efficiency
across routes of different lengths instead of comparing
absolute shipment costs alone. Because v_profitability now
carries one averaged distance per lane, each shipment_id
appears exactly once here.
-----------------------------------------------------------*/

SELECT
    shipment_id,
    cost * 1.0 / NULLIF(distance_km, 0) AS cost_per_km
FROM v_profitability;

/*-----------------------------------------------------------
WHO IS ACTUALLY PROFITABLE TO SERVE?

Move the analysis from shipments to customer relationships.

For each customer account, compare shipment volume, revenue,
cost, and resulting profit contribution.

Sorting from the least profitable customers upward exposes
accounts that may generate business activity without creating
enough financial value.

Grouping includes customer_id because several different
customer accounts share the same company_name in this data
set. Grouping by company_name alone would merge unrelated
accounts and misstate profitability at the relationship
level.
-----------------------------------------------------------*/

SELECT
    c.customer_id,
    c.company_name,
    COUNT(s.shipment_id) AS shipments,
    SUM(s.revenue) AS total_revenue,
    SUM(s.cost) AS total_cost,
    SUM(s.revenue - s.cost) AS profit
FROM shipments s
JOIN customers_maritime c
    ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.company_name
ORDER BY profit ASC;

/*-----------------------------------------------------------
FUEL PRICE & SHIPMENT COST EXPOSURE

Compare regional fuel prices with average shipment costs to
provide visibility into whether higher fuel environments are
associated with higher transportation costs.

Fuel prices and shipment costs are each summarized to one row
per year before being joined, so no side of the comparison
gets multiplied by the other. This gives management an
external cost perspective when reviewing shipment economics
across regions and years, without a join key that does not
really exist in the data (fuel records and shipments are not
linked to each other directly, only by year).
-----------------------------------------------------------*/

WITH fuel_by_region_year AS (
    SELECT
        region,
        YEAR(date) AS report_year,
        AVG(fuel_price) AS avg_fuel_price
    FROM fuel_data
    GROUP BY region, YEAR(date)
),
cost_by_year AS (
    SELECT
        YEAR(departure_date) AS report_year,
        AVG(cost) AS avg_shipment_cost
    FROM shipments
    GROUP BY YEAR(departure_date)
)
SELECT
    f.region,
    f.report_year,
    f.avg_fuel_price,
    c.avg_shipment_cost
FROM fuel_by_region_year f
JOIN cost_by_year c
    ON f.report_year = c.report_year
ORDER BY f.region, f.report_year;

/*-----------------------------------------------------------
TRANSIT TIME VS PROFITABILITY

Compare average route duration with average shipment profit
to examine the commercial performance of routes with
different transit times.

This helps identify whether longer service times are being
supported by sufficient profitability or whether certain
transit profiles require further review.
-----------------------------------------------------------*/

SELECT
    average_time_days,
    AVG(revenue - cost) AS avg_profit
FROM v_profitability
GROUP BY average_time_days
ORDER BY average_time_days;

/*-----------------------------------------------------------
SHIPMENT WEIGHT & PROFITABILITY

Compare shipment weight with average profit to examine how
shipment size relates to commercial performance.

Weight is bucketed into ranges rather than grouped on its raw
value. Weight is recorded to two decimal places, so grouping
directly on weight_tons would produce almost one group per
shipment and would not show a real pattern. Bucketing pools
shipments together so the comparison means something.
-----------------------------------------------------------*/

SELECT
    CASE
        WHEN weight_tons < 50 THEN '01: Under 50 tons'
        WHEN weight_tons < 100 THEN '02: 50 to 99 tons'
        WHEN weight_tons < 150 THEN '03: 100 to 149 tons'
        WHEN weight_tons < 200 THEN '04: 150 to 199 tons'
        ELSE '05: 200 tons and above'
    END AS weight_band,
    COUNT(*) AS shipments,
    AVG(revenue - cost) AS avg_profit
FROM shipments
GROUP BY
    CASE
        WHEN weight_tons < 50 THEN '01: Under 50 tons'
        WHEN weight_tons < 100 THEN '02: 50 to 99 tons'
        WHEN weight_tons < 150 THEN '03: 100 to 149 tons'
        WHEN weight_tons < 200 THEN '04: 150 to 199 tons'
        ELSE '05: 200 tons and above'
    END
ORDER BY weight_band;

/*-----------------------------------------------------------
COMMERCIAL ACTION ENGINE

Convert shipment profitability into clear actions that
Operations and Commercial teams can investigate.

Increase Price or Cut Cost:
The shipment generated a negative profit and requires
immediate pricing or cost review.

Optimize Cost:
The shipment remains profitable but contributes less than
the defined $2,000 profit threshold.

Good:
The shipment currently generates profit above the defined
commercial threshold.

The objective is not simply to label performance. It is to
identify where pricing or operational intervention may
improve shipment economics.
-----------------------------------------------------------*/

SELECT
    shipment_id,
    revenue,
    cost,
    (revenue - cost) AS profit,
    CASE
        WHEN revenue - cost < 0 THEN 'Increase Price or Cut Cost'
        WHEN revenue - cost < 2000 THEN 'Optimize Cost'
        ELSE 'Good'
    END AS action
FROM shipments;

/*===========================================================
THE DECISION VIEW
-----------------

This analysis changes the conversation from:

"How much revenue did we generate?"

to:

"How much value did we retain after serving the business?"

Management can now examine profitability from multiple
angles:

ROUTES
Which lanes create value and which consistently lose money?

CUSTOMERS
Which accounts contribute real profit after shipment costs?

SHIPMENTS
Which individual movements require pricing or cost action?

DISTANCE
How efficiently are transportation costs managed across
different route lengths?

FUEL
How does the external fuel environment relate to shipment
costs?

TRANSIT TIME
Are longer routes producing enough profit to justify their
operational requirements?

SHIPMENT SIZE
Does higher shipment weight translate into stronger
commercial performance?

The result is a SQL based profitability framework that helps
Commercial, Finance, and Operations teams identify where
value is being created, where margins are weak, and where
pricing or cost intervention should be investigated.

The core principle is simple:

Revenue tells management how much business is moving through
the network.

Profitability tells management whether that business is
worth serving.
===========================================================*/
