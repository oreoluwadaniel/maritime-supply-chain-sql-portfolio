/*===========================================================
DEMAND PLANNING, INVENTORY RISK &
CAPACITY OPTIMIZATION

## PLANNING CHALLENGE

Supply chain planning becomes expensive when capacity and
inventory decisions are made without a clear understanding of
actual demand.

Too little inventory creates stockout risk and limits the
business's ability to meet demand.

Too much inventory ties up resources in stock that may not be
required.

The same problem applies to logistics capacity.

Underestimating demand can create congestion and service
pressure, while overestimating demand leaves resources
underutilized.

The purpose of this analysis is to understand where demand is
coming from, how demand changes over time, where inventory
risk exists, and how capacity decisions can better reflect
shipment activity.

## PLANNING QUESTIONS

Where is shipment demand growing?

Which routes carry the greatest demand?

Which customers contribute the most shipment activity?

What is the current inventory position?

Which products are exposed to stockout risk?

Where are inventory levels unusually high?

How stable or volatile is demand across origins?

Where should capacity increase, decrease, or remain stable?

===========================================================*/

/*-----------------------------------------------------------
CORRECTION LOG (read this before running the queries below)

Three issues were found and fixed in this script.

1. NO KEY LINKING SHIPMENTS TO INVENTORY
   The original "demand vs inventory availability" query
   joined shipments to inventory using ON s.destination_port
   IS NOT NULL. That condition is true for almost every row on
   both sides, so it does not function as a real join
   condition. It produces a full cross join: every shipment
   gets matched with every inventory record. With 3,000
   shipments and 3,000 inventory rows, that is up to nine
   million combined rows, and the SUM(stock_level) in the
   original query ends up counting the same inventory figures
   over and over, once for every shipment in that destination.
   The original script's own comments already flagged that the
   join does not map to a specific destination, warehouse, or
   product, which was the right instinct. This version acts on
   that instinct instead of just noting it.
   FIX: shipment demand by destination and total available
   inventory across the network are calculated separately,
   each already reduced to a small summary table, and then
   combined with a CROSS JOIN of two single summarized result
   sets rather than the raw tables. That removes the row
   multiplication problem. It is still not a true product level
   demand-to-supply match, because the source data has no
   column connecting a warehouse or product to a destination
   port. That is a data modeling gap, not something a query
   can fix, so the corrected query is clearly labeled as a
   network-level comparison rather than a mapped calculation.

2. CUSTOMER GROUPING BY COMPANY NAME ONLY
   The same issue found in the cost-to-serve script shows up
   here. customers_maritime has 3,000 rows, but the same
   company_name value (for example, "Toyota Logistics" or
   "Shell Trading") is reused across hundreds of different
   customer_id records with different countries and contract
   values. Grouping "who is driving demand" by company_name
   alone merges unrelated customer accounts into one row.
   FIX: the grouping now includes customer_id, so demand is
   measured at the actual account level.

3. MISSING "IF EXISTS" GUARD ON THE VIEW
   Added the same safeguard used in the other two scripts so
   v_demand_base can be recreated without erroring out if it
   already exists.

No issues were found with the stockout, overstock, or capacity
signal logic. Those thresholds (5,000 units for overstock, 100
and 30 shipments for capacity direction) are planning rules
rather than fixed business laws, and the script already says
so directly, which is good practice.
-----------------------------------------------------------*/

/*-----------------------------------------------------------
CREATE THE DEMAND ANALYSIS BASE

Create a simplified shipment view containing the core
variables required for demand analysis.

Shipment counts represent activity, while weight and volume
provide additional measures of the physical demand moving
through the network.
-----------------------------------------------------------*/

IF OBJECT_ID('v_demand_base', 'V') IS NOT NULL
    DROP VIEW v_demand_base;
GO

CREATE VIEW v_demand_base AS
SELECT
    shipment_id,
    origin_port,
    destination_port,
    departure_date,
    weight_tons,
    volume_cbm
FROM shipments;
GO

/*-----------------------------------------------------------
WHEN DOES DEMAND OCCUR?

Track shipment activity by month using three demand signals:
shipment count, total weight, and total volume.

Shipment Count is the number of shipment movements processed.

Total Weight is the physical weight moved through the network.

Total Volume is the amount of cargo space represented by those
shipments.

Looking at these measures together provides a stronger view of
demand than shipment count alone and helps reveal changes in
network activity over time.
-----------------------------------------------------------*/

SELECT
    YEAR(departure_date) AS year,
    MONTH(departure_date) AS month,
    COUNT(*) AS shipment_count,
    SUM(weight_tons) AS total_weight,
    SUM(volume_cbm) AS total_volume
FROM shipments
GROUP BY YEAR(departure_date), MONTH(departure_date)
ORDER BY year, month;

/*-----------------------------------------------------------
WHERE IS DEMAND CONCENTRATED?

Measure shipment activity across origin and destination pairs
to identify the busiest routes in the network.

Shipment count shows movement frequency, while total weight
shows the physical demand carried by each route.

This helps planners identify lanes requiring greater
operational attention and capacity.
-----------------------------------------------------------*/

SELECT
    origin_port,
    destination_port,
    COUNT(*) AS shipments,
    SUM(weight_tons) AS total_weight
FROM shipments
GROUP BY origin_port, destination_port
ORDER BY shipments DESC;

/*-----------------------------------------------------------
WHO IS DRIVING DEMAND?

Measure customer contribution using shipment frequency and
total cargo weight.

This identifies customers responsible for significant network
activity and provides useful context for capacity planning and
customer demand management.

Grouping includes customer_id because several different
customer accounts in this data set share the same
company_name. Grouping by company_name alone would combine
unrelated accounts and overstate how much demand comes from a
single relationship.
-----------------------------------------------------------*/

SELECT
    c.customer_id,
    c.company_name,
    COUNT(s.shipment_id) AS shipments,
    SUM(s.weight_tons) AS total_weight
FROM shipments s
JOIN customers_maritime c
    ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.company_name
ORDER BY shipments DESC;

/*-----------------------------------------------------------
WHAT INVENTORY IS AVAILABLE?

Calculate the resulting inventory position after considering
current stock, expected inbound quantities, and outbound
movement.

Net Stock = Current Stock + Inbound - Outbound

This provides a simple view of inventory availability at the
warehouse and product level.
-----------------------------------------------------------*/

SELECT
    warehouse_id,
    product_id,
    stock_level,
    inbound,
    outbound,
    (stock_level + inbound - outbound) AS net_stock
FROM inventory;

/*-----------------------------------------------------------
WHERE COULD INVENTORY RUN SHORT?

Flag warehouse and product combinations where current stock is
below recorded outbound requirements.

These records represent potential stockout exposure and may
require replenishment or inventory reallocation review.
-----------------------------------------------------------*/

SELECT
    warehouse_id,
    product_id,
    stock_level,
    outbound,
    CASE
        WHEN stock_level < outbound THEN 'Stockout Risk'
        ELSE 'Safe'
    END AS stock_status
FROM inventory;

/*-----------------------------------------------------------
WHERE COULD INVENTORY BE EXCESSIVE?

Identify products with stock levels above the defined 5,000
unit threshold.

This provides a simple overstock screening rule that helps
surface inventory positions requiring further review.

The threshold is a planning rule, not a universal definition of
excess inventory. Actual overstock should ultimately be
evaluated against expected demand, lead time, and required
safety stock.
-----------------------------------------------------------*/

SELECT
    warehouse_id,
    product_id,
    stock_level,
    CASE
        WHEN stock_level > 5000 THEN 'Overstock'
        ELSE 'Normal'
    END AS inventory_status
FROM inventory;

/*-----------------------------------------------------------
SHIPMENT DEMAND & NETWORK INVENTORY CONTEXT

Compare shipment demand by destination against the total
inventory available across the whole network.

IMPORTANT:
Inventory records are not linked to a destination port,
customer, or shipment in this data set, so this is a
network-level comparison for context, not a true
demand-to-supply match. Demand by destination is calculated
first and reduced to one row per destination. Total network
supply is calculated separately as a single value. The two
summarized result sets are then combined with a CROSS JOIN,
which is safe here because network_supply only ever returns
one row, so no shipment or inventory record gets duplicated.

A complete planning model would require a valid relationship
between destination demand and the inventory location or
product expected to satisfy that demand. That relationship
does not exist in the current data model and would need to be
added at the source before a true demand-to-supply calculation
is possible.
-----------------------------------------------------------*/

WITH demand_by_destination AS (
    SELECT
        destination_port,
        COUNT(shipment_id) AS demand
    FROM shipments
    GROUP BY destination_port
),
network_supply AS (
    SELECT SUM(CAST(stock_level AS BIGINT)) AS total_supply
    FROM inventory
)
SELECT
    d.destination_port,
    d.demand,
    n.total_supply
FROM demand_by_destination d
CROSS JOIN network_supply n
ORDER BY d.demand DESC;

/*-----------------------------------------------------------
HOW PREDICTABLE IS DEMAND?

Measure the variation in shipment weight across origin ports
using standard deviation.

Higher variability indicates less consistent shipment demand
and may require more flexible capacity planning.

Lower variability indicates more stable shipment patterns that
may be easier to plan around.
-----------------------------------------------------------*/

SELECT
    origin_port,
    STDEV(weight_tons) AS demand_variability
FROM shipments
GROUP BY origin_port;

/*-----------------------------------------------------------
CAPACITY PLANNING SIGNAL

Translate shipment activity at each origin into a simple
capacity recommendation.

Increase Capacity:
More than 100 shipments indicate relatively high activity
under the defined planning rule.

Reduce Capacity:
Fewer than 30 shipments indicate lower activity and potential
excess capacity.

Stable:
Shipment activity remains between the defined thresholds.

Average shipment weight is included to provide additional
context on the physical demand being handled at each origin.
-----------------------------------------------------------*/

SELECT
    origin_port,
    COUNT(*) AS demand,
    AVG(weight_tons) AS avg_weight,
    CASE
        WHEN COUNT(*) > 100 THEN 'Increase Capacity'
        WHEN COUNT(*) < 30 THEN 'Reduce Capacity'
        ELSE 'Stable'
    END AS planning_action
FROM shipments
GROUP BY origin_port;

/*===========================================================
PLANNING TAKEAWAY
-----------------

This analysis gives supply chain planners three connected
views of the operation.

DEMAND

Monthly trends show when shipment activity changes.

Route analysis shows where demand is concentrated.

Customer analysis shows who is contributing that demand.

INVENTORY

Net stock provides visibility into available inventory.

Stockout screening identifies products that may not have
enough stock to support outbound requirements.

Overstock screening identifies inventory positions requiring
further review.

CAPACITY

Demand variability shows where shipment requirements are less
predictable.

The planning engine identifies origins where current shipment
activity suggests capacity should be reviewed.

Together, these analyses provide a SQL based planning
framework for understanding demand patterns, identifying
inventory risk, and supporting better capacity allocation.

The planning principle is straightforward:

Inventory should follow demand.

Capacity should follow network activity.

And both decisions should be driven by evidence rather than
assumptions.
===========================================================*/
