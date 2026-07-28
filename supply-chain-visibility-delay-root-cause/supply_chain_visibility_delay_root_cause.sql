/*===========================================================
SUPPLY CHAIN VISIBILITY, DISRUPTION &
DELAY ROOT CAUSE INTELLIGENCE

## THE OPERATIONS PROBLEM

Knowing that a shipment is delayed is useful.

Knowing why it was delayed, where the problem occurred, how
often it happens, and how serious the disruption is provides
the information needed to actually improve the supply chain.

Management needs visibility beyond shipment status.

The real questions are:

Where are delays concentrated?

What problems repeatedly disrupt shipments?

Which ports and routes create the greatest exposure?

Is congestion contributing to longer delays?

How much disruption is associated with weather conditions?

How severe are the delays occurring across the network?

And where should operational teams focus improvement efforts?

This analysis moves from detecting delays to diagnosing the
conditions behind them.

===========================================================*/

/*-----------------------------------------------------------
CORRECTION LOG (read this before running the queries below)

This script was in reasonably good shape logically. Two
things were changed after checking it against the actual data.

1. MISSING "IF EXISTS" GUARD ON THE VIEW
   The original script created v_supply_chain_visibility
   without checking whether it already existed. Re-running the
   script on a database where the view is already present
   would fail. A guard was added so the script can be run more
   than once safely.

2. ONE HEADLINE METRIC WAS TOO NARROW
   The original "how big is the delay problem" query only
   counted shipments where shipment_status = 'Delayed'. That
   is a fair headline number, but it only reflects shipments
   currently sitting in delayed status. A shipment that was
   delayed in transit and then recorded as "Delivered" once it
   finally arrived would never show up in that count, even
   though it has a full record sitting in delays_events. That
   is not a broken query, it is a narrower question than it
   first appears to be.
   FIX: a second version of the metric was added, comparing
   the status-based delay rate against an event-based delay
   rate built from DISTINCT shipment_id values in
   delays_events. Running both side by side gives a more
   honest picture of how much of the network has been touched
   by a disruption at some point, not just how much is
   delayed right now.

No other structural issues were found. The joins in this
script are appropriately scoped: INNER JOIN is used
deliberately in the cause, port, and route breakdowns because
those questions are only meaningful for shipments that
actually have a recorded delay event, and ports.port_name is
unique across all 8 ports, so joining on it does not create
any duplication risk.
-----------------------------------------------------------*/

/*-----------------------------------------------------------
FIRST LOOK: DATA AVAILABILITY CHECK

Confirm the volume of shipment records and review the delay
event data before beginning the operational analysis.

This provides an initial understanding of the shipment
portfolio and the disruption records available for analysis.
-----------------------------------------------------------*/

SELECT COUNT(*)
FROM shipments;

SELECT TOP 10 *
FROM delays_events;

/*-----------------------------------------------------------
BUILD THE SUPPLY CHAIN VISIBILITY LAYER

Connect shipment movements with recorded delay events and
destination port conditions.

The resulting view provides one analytical layer containing
shipment status, route information, financial performance,
delay causes, weather impact, and congestion indicators.

This becomes the foundation for investigating where and why
supply chain disruptions occur.
-----------------------------------------------------------*/

IF OBJECT_ID('v_supply_chain_visibility', 'V') IS NOT NULL
    DROP VIEW v_supply_chain_visibility;
GO

CREATE VIEW v_supply_chain_visibility AS
SELECT
    s.shipment_id,
    s.customer_id,
    s.origin_port,
    s.destination_port,
    s.departure_date,
    s.arrival_date,
    s.shipment_status,
    s.revenue,
    s.cost,
    d.delay_reason,
    d.delay_days,
    d.weather_impact,
    d.port_congestion AS delay_congestion,
    p.congestion_level AS port_congestion_level
FROM shipments s
LEFT JOIN delays_events d
    ON s.shipment_id = d.shipment_id
LEFT JOIN ports p
    ON s.destination_port = p.port_name;
GO

/*-----------------------------------------------------------
HOW BIG IS THE DELAY PROBLEM?

Measure the proportion of shipments currently classified as
delayed, and compare that against the share of shipments that
have any recorded delay event at all.

The first figure is the headline service performance
indicator based on current shipment status. The second figure
picks up shipments that experienced a disruption along the
way even if they were eventually marked as delivered. Looking
at both prevents management from underestimating how much of
the network has been touched by a delay event at some point.
-----------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM shipments WHERE shipment_status = 'Delayed') * 1.0
        / (SELECT COUNT(*) FROM shipments) AS status_based_delay_rate,
    (SELECT COUNT(DISTINCT shipment_id) FROM delays_events) * 1.0
        / (SELECT COUNT(*) FROM shipments) AS event_based_delay_rate;

/*-----------------------------------------------------------
WHAT IS CAUSING THE DELAYS?

Break recorded delays down by cause and measure both how
frequently each issue occurs and how long the resulting
disruption typically lasts.

Frequency shows which problems happen most often.

Average delay duration shows which problems create greater
operational disruption.

Together, they help separate common problems from high impact
problems.
-----------------------------------------------------------*/

SELECT
    delay_reason,
    COUNT(*) AS total_delays,
    AVG(delay_days) AS avg_delay_days
FROM delays_events
GROUP BY delay_reason
ORDER BY total_delays DESC;

/*-----------------------------------------------------------
WHERE ARE DELAYS CONCENTRATED?

Compare destination ports based on the number of recorded
delay events and their average duration.

This highlights locations where shipment reliability may
require closer operational review. The count here reflects
delay events, not distinct shipments, since a single shipment
can in principle carry more than one recorded delay event.
-----------------------------------------------------------*/

SELECT
    s.destination_port,
    COUNT(d.shipment_id) AS delay_count,
    AVG(d.delay_days) AS avg_delay
FROM shipments s
JOIN delays_events d
    ON s.shipment_id = d.shipment_id
GROUP BY s.destination_port
ORDER BY delay_count DESC;

/*-----------------------------------------------------------
IS PORT CONGESTION DRIVING DISRUPTION?

Compare congestion levels with average shipment delays across
destination ports.

This helps determine whether highly congested ports are also
associated with longer delivery disruptions and identifies
locations where congestion exposure may need to be managed.
-----------------------------------------------------------*/

SELECT
    p.port_name,
    p.congestion_level,
    AVG(d.delay_days) AS avg_delay
FROM ports p
JOIN shipments s
    ON p.port_name = s.destination_port
JOIN delays_events d
    ON s.shipment_id = d.shipment_id
GROUP BY p.port_name, p.congestion_level
ORDER BY avg_delay DESC;

/*-----------------------------------------------------------
WHICH ROUTES ARE REPEATEDLY UNDERPERFORMING?

Analyze shipment delays across origin and destination pairs to
identify routes experiencing repeated disruptions.

Routes with both frequent and longer delays represent stronger
candidates for scheduling, carrier, routing, or operational
review.
-----------------------------------------------------------*/

SELECT
    s.origin_port,
    s.destination_port,
    COUNT(d.shipment_id) AS delays,
    AVG(d.delay_days) AS avg_delay
FROM shipments s
JOIN delays_events d
    ON s.shipment_id = d.shipment_id
GROUP BY s.origin_port, s.destination_port
ORDER BY delays DESC;

/*-----------------------------------------------------------
WEATHER EXPOSURE

Measure average recorded weather impact alongside average
delay duration.

This provides a high level view of weather related exposure
within the delay records and supports further investigation
into external causes of shipment disruption.
-----------------------------------------------------------*/

SELECT
    AVG(weather_impact) AS avg_weather_impact,
    AVG(delay_days) AS avg_delay
FROM delays_events;

/*-----------------------------------------------------------
FINANCIAL VIEW OF SHIPMENT OPERATIONS

Measure revenue, operating cost, profit, and the number of
delay events linked to the shipment portfolio.

This connects operational performance with financial
performance so management can evaluate disruption alongside
the commercial value moving through the network.
-----------------------------------------------------------*/

SELECT
    SUM(s.revenue) AS total_revenue,
    SUM(s.cost) AS total_cost,
    SUM(s.revenue - s.cost) AS profit,
    COUNT(d.shipment_id) AS delay_events_linked
FROM shipments s
LEFT JOIN delays_events d
    ON s.shipment_id = d.shipment_id;

/*-----------------------------------------------------------
HOW SEVERE ARE THE DELAYS?

Group disruptions into practical severity bands based on the
number of delay days.

Short Delay:
Three days or less.

Medium Delay:
More than three days and up to seven days.

Severe Delay:
More than seven days.

This converts raw delay duration into operational categories
that can be used to prioritize investigation and response.
-----------------------------------------------------------*/

SELECT
    CASE
        WHEN delay_days <= 3 THEN 'Short Delay'
        WHEN delay_days <= 7 THEN 'Medium Delay'
        ELSE 'Severe Delay'
    END AS delay_category,
    COUNT(*) AS shipments
FROM delays_events
GROUP BY
    CASE
        WHEN delay_days <= 3 THEN 'Short Delay'
        WHEN delay_days <= 7 THEN 'Medium Delay'
        ELSE 'Severe Delay'
    END;

/*===========================================================
FROM DELAY DATA TO OPERATIONAL ACTION
-------------------------------------

The purpose of this analysis is not simply to report that
shipments arrived late.

It gives Operations and Supply Chain teams a structured way to
trace disruption back to the parts of the network where
problems are occurring.

Management can use the analysis to measure the overall level
of shipment delays, identify the most frequent causes of
disruption, distinguish frequent delays from more severe
disruptions, find destination ports experiencing repeated
problems, assess congestion alongside shipment delay
performance, identify routes with recurring reliability
issues, monitor weather exposure within recorded delay events,
view shipment economics alongside operational disruption, and
prioritize severe delays for deeper investigation.

The result is a SQL based root cause analysis framework that
turns shipment and delay records into a clearer picture of
where supply chain reliability is breaking down and where
operational teams should investigate first.
===========================================================*/
