# FlowPlan: Demand, Inventory & Capacity Intelligence

**A SQL planning intelligence system for aligning shipment demand, inventory exposure, and network capacity across a maritime logistics operation.**

---

## Project Overview

Logistics planning has two expensive failure modes.

**Too little capacity or inventory**, and the business risks stockouts, service failures, rushed replenishment, and missed demand.

**Too much capacity or inventory**, and cash gets trapped in stock, warehouse space sits occupied, and operational resources are committed where they are not needed.

Both problems come from the same planning gap:

> **Resources are being positioned without a reliable view of where demand is actually occurring.**

FlowPlan addresses that problem by connecting shipment activity, customer demand, inventory position, and origin-level capacity signals into one planning framework.

Built in SQL across **3,000 shipments and 3,000 inventory records**, the system helps planners answer:

> **Where is demand growing?**
> **Which routes and customers are driving it?**
> **Where is inventory becoming dangerously thin?**
> **Where is excess stock tying up working capital?**
> **Which origins are experiencing volatile demand?**
> **Where should capacity increase, decrease, or remain stable?**

The objective is to move planning from:

> **"What do we think we will need?"**

toward:

> **"What is actual network activity telling us to prepare for?"**

---

# Business Problem

Demand, inventory, and capacity are connected decisions.

But they are often managed separately.

Commercial teams see customer demand.

Warehouse teams see inventory.

Operations teams see port activity and capacity.

When those views are disconnected, the business can simultaneously have:

* Excess Stock in One Location
* Shortages in Another
* Capacity Sitting Idle
* Busy Origins Under Pressure
* High-Demand Accounts Competing for Limited Resources
* Working Capital Trapped in Slow-Moving Inventory

A revenue report will not expose those problems.

FlowPlan creates a planning layer between commercial activity and operational resources.

---

# Planning Questions

The system is designed around three connected decisions.

### Demand

**Where, when, and from whom is demand coming?**

### Inventory

**Where is stock becoming constrained or excessive?**

### Capacity

**Where does network activity justify more or less operating capacity?**

Together, these create a planning chain:

```text id="xgphn5"
DEMAND
   ↓
INVENTORY REQUIREMENTS
   ↓
CAPACITY REQUIREMENTS
   ↓
RESOURCE ALLOCATION
```

The principle is simple:

> **Inventory and capacity should respond to observed demand rather than static assumptions.**

---

# Data Sources

FlowPlan uses three core datasets from the maritime logistics environment.

| Dataset              |  Rows | Business Role                                   |
| -------------------- | ----: | ----------------------------------------------- |
| `shipments`          | 3,000 | Shipment demand across origin-destination lanes |
| `customers_maritime` | 3,000 | Customer accounts generating network demand     |
| `inventory`          | 3,000 | Warehouse and product-level stock position      |

Shipment records provide:

* Origin Port
* Destination Port
* Departure Date
* Shipment Weight
* Shipment Volume

Inventory records provide:

* Warehouse
* Product
* Current Stock
* Inbound Quantity
* Outbound Quantity

Customer records connect shipment activity to the accounts generating that demand.

---

# Planning Intelligence Architecture

```text id="vdr5rc"
                         NETWORK ACTIVITY
                                |
              --------------------------------
              |                              |
              ↓                              ↓
          SHIPMENTS                       CUSTOMERS
              |                              |
              -------------------------------
                             |
                             ↓
                     DEMAND INTELLIGENCE
                             |
              -------------------------------
              |              |              |
              ↓              ↓              ↓
           Monthly         Route         Customer
            Demand         Demand          Demand
              |              |              |
              -------------------------------
                             |
                             ↓
                       DEMAND SIGNAL
                             |
          -----------------------------------------
          |                                       |
          ↓                                       ↓
      INVENTORY                                CAPACITY
          |                                       |
          ↓                                       ↓
     Net Position                         Origin Activity
          |                                       |
    -------------                          ----------------
    |           |                          |              |
    ↓           ↓                          ↓              ↓
 Stockout    Overstock                 Volatility    Utilization
   Risk       Exposure                     |              |
    |           |                          ----------------
    -------------                                  |
          |                                        ↓
          ↓                               Capacity Signal
 Inventory Action                                  |
          |                                        |
          ------------------------------------------
                             |
                             ↓
                     PLANNING ACTIONS
                             |
           ------------------------------------
           |                |                 |
           ↓                ↓                 ↓
       REPLENISH        REBALANCE          ADJUST
         STOCK           INVENTORY         CAPACITY
```

---

# Methodology

The analysis is structured around three planning layers.

---

# Layer 1: Demand Intelligence

A reusable demand view, `v_demand_base`, standardizes the shipment fields required for planning.

It captures:

* Shipment ID
* Origin
* Destination
* Departure Date
* Shipment Weight
* Shipment Volume

From this base, demand is evaluated across three dimensions.

### Time

Monthly shipment activity shows how network demand changes over time.

### Route

Origin-destination analysis identifies where shipment activity is concentrated.

### Customer

Account-level analysis identifies which customer relationships generate the most network demand.

Together, these answer:

> **Where is demand coming from, when is it happening, and who is driving it?**

---

# Layer 2: Inventory Intelligence

Inventory planning requires more than looking at current stock.

FlowPlan calculates:

```text id="77d0nq"
Net Stock
=
Current Stock
+
Inbound Quantity
-
Outbound Quantity
```

This creates a more useful forward position than current stock alone.

The system then screens inventory for two opposite risks.

---

## Stockout Exposure

Inventory is flagged where available stock is insufficient relative to expected outbound movement.

This identifies product-warehouse combinations requiring immediate planning attention.

Potential business consequences include:

* Order Delays
* Service-Level Failures
* Emergency Replenishment
* Lost Sales
* Higher Expediting Costs

---

## Overstock Exposure

Inventory above the defined planning threshold is flagged for review.

Overstock creates a different economic problem:

* Working Capital Becomes Trapped
* Warehouse Space Is Consumed
* Handling Requirements Increase
* Inventory Can Remain Idle
* Capital Cannot Be Deployed Elsewhere

The system therefore treats inventory risk in both directions:

> **Too little stock creates service risk.**

> **Too much stock creates capital-efficiency risk.**

---

# Layer 3: Capacity Intelligence

Shipment activity is aggregated by origin to understand where operating pressure is concentrated.

The model evaluates:

* Shipment Count
* Shipment Weight
* Demand Variability

A capacity signal then classifies each origin into:

### Increase Capacity

Activity is sufficiently high to justify additional planning attention.

### Maintain Capacity

Current activity sits within the expected operating range.

### Reduce Capacity

Activity is comparatively low and may not justify the current resource level.

These signals are planning prompts, not automatic operating instructions.

They tell planners:

> **Where should we investigate capacity allocation?**

not:

> **Change capacity immediately without operational review.**

---

# Demand Volatility

Average demand alone is not enough for capacity planning.

Two origins can process the same average shipment weight while behaving very differently.

```text id="tl06x8"
Origin A
Weekly Demand:
98, 101, 99, 102, 100

Origin B
Weekly Demand:
20, 180, 40, 200, 60
```

Their averages may be similar.

Their planning requirements are not.

Origin B requires greater flexibility because demand is less predictable.

FlowPlan uses standard deviation to measure this variability.

The planning question therefore becomes:

> **How much demand do we handle, and how predictable is it?**

---

# Critical Finding 1: The Original Demand-to-Inventory Join Was Not a Real Join

The most serious problem in the original analysis occurred when shipment demand was compared with inventory.

The join condition was effectively:

```sql id="al85qw"
ON shipment.destination_port IS NOT NULL
```

That condition does not connect a shipment to:

* A Warehouse
* A Product
* An Inventory Record

For almost every valid shipment, the condition is simply true.

The result behaves like a cross join.

With:

```text id="ol7iw5"
3,000 Shipments
×
3,000 Inventory Records
```

the query could create:

```text id="4pbj3m"
9,000,000 combined rows
```

before aggregation.

---

# Why This Matters

The resulting inventory total may look like a legitimate supply figure.

But the same stock records are being repeated for shipment after shipment.

The query therefore answers no meaningful planning question.

This is more dangerous than a SQL error.

An error stops the report.

A fan-out can produce a polished number that management assumes is correct.

---

# Correction: Separate Demand and Supply Before Comparing Them

Shipment demand and inventory are now summarized independently.

```text id="zyql5j"
SHIPMENTS
    |
    ↓
Aggregate Demand
    |
    ----------------
                    |
                    ↓
             Planning Context
                    ↑
    ----------------
    |
    ↓
Aggregate Inventory
    ↑
    |
INVENTORY
```

Only after both sides have been reduced to their intended analytical level are they combined.

This eliminates the millions of artificial shipment-inventory combinations.

---

# An Important Limitation

Fixing the SQL does **not** create a relationship that does not exist in the source data.

The available datasets do not provide a reliable key connecting:

```text id="m6qoz8"
Destination Port
        ↓
Warehouse
        ↓
Product Demand
```

That means FlowPlan cannot honestly claim:

> **Port X requires 4,500 units of Product Y from Warehouse Z.**

The data does not support that level of precision.

The corrected comparison therefore provides **network-level demand and inventory context**, not destination-level supply matching.

This distinction is deliberate.

> **A smarter query cannot compensate for a missing business relationship in the data model.**

---

# What the Data Model Needs Next

To turn the current planning model into true demand-to-inventory allocation, the source system needs additional relationships.

Ideally:

```text id="g6j8fn"
Shipment
   |
   ↓
Product / SKU
   |
   ↓
Destination
   |
   ↓
Serving Warehouse
   |
   ↓
Available Inventory
```

That would require fields or mapping tables connecting:

* Shipments to Product/SKU
* Ports to Serving Warehouses
* Warehouses to Service Regions
* Shipment Demand to Inventory Units

With those relationships, the system could support:

* SKU-Level Demand Planning
* Destination-Level Stock Coverage
* Replenishment Requirements
* Warehouse Rebalancing
* Days of Supply
* Safety Stock
* Inventory Allocation

The current project identifies that architectural requirement instead of inventing precision the data cannot support.

---

# Critical Finding 2: Company Name Was Not a Customer Key

The customer dataset contains repeated company names across separate:

* Customer IDs
* Countries
* Contract Values

Grouping demand only by company name would merge independent customer relationships.

A large brand could therefore appear to generate enormous demand simply because hundreds of separate accounts were collapsed into one label.

---

# Correction: Account-Level Demand

Demand is grouped using:

```text id="o5d22u"
Customer ID
+
Company Name
```

Customer ID defines the account.

Company name provides the readable business label.

This allows commercial and operations teams to understand which **actual customer relationships** are driving demand.

---

# Monthly Demand Intelligence

Monthly shipment trends provide the first layer of planning visibility.

They help identify:

* Rising Demand
* Falling Demand
* Seasonal Peaks
* Activity Slowdowns
* Periods Requiring Capacity Review

This creates a stronger basis for planning than static annual averages.

---

# Route Demand Intelligence

Origin-destination lanes are ranked by shipment activity.

This identifies where network demand is concentrated.

High-demand lanes may require:

* Greater Capacity
* More Frequent Scheduling
* Stronger Inventory Support
* Priority Service Planning
* Closer Operational Monitoring

Low-demand lanes may indicate opportunities to:

* Consolidate Shipments
* Reduce Frequency
* Reallocate Capacity

The point is not simply to know which route is busiest.

It is to understand:

> **Where network resources are actually being consumed.**

---

# Customer Demand Intelligence

Customer demand is evaluated at account level.

This allows planners to identify:

* Accounts Driving Significant Shipment Volume
* Customers Creating Concentrated Capacity Requirements
* Relationships That May Require Dedicated Planning
* Accounts Whose Demand Changes Could Materially Affect Network utilization

This also supports commercial conversations.

If one account consumes a meaningful share of capacity on a lane, contract discussions should consider that operational footprint.

---

# Inventory Position Intelligence

Net stock provides a forward-looking inventory view.

The system separates inventory into planning states:

### Stockout Risk

Potential service exposure requiring urgent review.

### Healthy Position

Inventory currently operating within the defined planning range.

### Overstock Exposure

Potential working-capital inefficiency requiring rebalancing or procurement review.

The objective is to turn warehouse records into a planning queue.

---

# Working Capital Perspective

Overstock is not merely a warehouse problem.

Inventory represents capital.

When stock sits unused, money that could fund:

* Operations
* Fleet Capacity
* Technology
* Commercial Growth
* Other Inventory

remains tied up.

That makes inventory optimization both an operational and financial problem.

---

# Capacity Planning Intelligence

Origin-level shipment activity is converted into a capacity signal.

The current model uses transparent planning thresholds.

Those thresholds are intentionally treated as conventions rather than universal truths.

Their purpose is to identify:

> **Where planners should investigate capacity**

rather than prescribe capacity automatically.

A production implementation should eventually incorporate:

* Seasonal Patterns
* Actual Port Capacity
* Vessel Availability
* Customer Commitments
* Service-Level Agreements
* Forecast Demand
* Historical Utilization

---

# Planning Priorities

FlowPlan produces three types of operational attention.

## Priority 1: Service Protection

Address stockout exposure first.

These conditions can directly affect customer service and revenue.

---

## Priority 2: Capacity Alignment

Review origins showing sustained high activity or high volatility.

Capacity decisions should account for both demand level and unpredictability.

---

## Priority 3: Working Capital Efficiency

Review overstocked product-warehouse combinations.

These are generally less urgent than stockout risks but represent opportunities to release capital and warehouse capacity.

---

# Business Recommendations

## 1. Build a Stockout Review Queue

Product-warehouse combinations flagged for stockout exposure should be reviewed regularly.

The immediate questions are:

* Is replenishment already inbound?
* Is outbound demand accelerating?
* Can inventory be transferred?
* Does procurement need to act?

The goal is to intervene before inventory shortage becomes service failure.

---

## 2. Review Overstock as a Cash Problem

Overstocked inventory should be analyzed for:

* Slow Movement
* Procurement Frequency
* Transfer Opportunities
* Excess Safety Stock
* Demand Changes

The objective is not simply to reduce inventory.

It is to release capital without creating future service risk.

---

## 3. Prioritize High-Demand Lanes

The busiest origin-destination pairs should receive closer planning attention.

If demand remains consistently high, operations should review whether:

* Capacity Is Sufficient
* Scheduling Frequency Is Appropriate
* Inventory Support Is Adequate
* Customer Commitments Match Available Resources

---

## 4. Account for Volatility Before Changing Capacity

A high-demand origin with stable activity requires a different planning response from one experiencing sharp demand swings.

Capacity decisions should therefore consider both:

> **Demand Level**

and:

> **Demand Variability**

---

## 5. Fix the Missing Demand-to-Supply Relationship

The largest next step is architectural.

Connect shipments, products, destinations, and warehouses through proper operational keys.

That upgrade would move FlowPlan from:

> **Demand and inventory visibility**

to:

> **true inventory allocation and replenishment planning.**

---

# Business Value

FlowPlan improves planning across four areas.

## Service Reliability

Stockout exposure becomes visible before shortages create shipment or customer-service problems.

## Working Capital

Excess inventory can be identified and reviewed rather than remaining invisible inside warehouse totals.

## Capacity Allocation

Origins can be evaluated according to actual activity and demand volatility, helping resources move toward areas of greater operational pressure.

## Planning Confidence

Invalid joins and unsupported supply-demand relationships are removed, preventing misleading numbers from becoming planning decisions.

The shift is from:

> **"How much inventory and capacity do we have?"**

to:

> **"Does the inventory and capacity we have align with where demand is actually occurring?"**

---

# Technical Corrections

Three analytical issues were corrected.

| Issue                             | Business Consequence                                                      | Correction                                                     |
| --------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Shipment-to-inventory pseudo-join | Up to 9 million artificial row combinations and meaningless supply totals | Aggregate demand and inventory independently before comparison |
| Customer grouping by company name | Separate customer accounts merged into inflated demand totals             | Group using customer ID and company name                       |
| Non-idempotent view creation      | Script could fail when rerun                                              | Add safe view recreation logic                                 |

The project also documents a critical data-model limitation:

> **No valid product-destination-warehouse relationship exists in the source data.**

That limitation is preserved explicitly rather than hidden behind an approximate join.

---

# Tools & Techniques

### SQL

The planning workflow is implemented entirely in SQL.

### Reusable Demand View

`v_demand_base` standardizes shipment demand for downstream analysis.

### Common Table Expressions

CTEs separate demand and inventory calculations before the results are combined.

This prevents many-to-many multiplication when the underlying datasets do not share a valid transactional key.

### `CASE`

Used to convert inventory and capacity conditions into readable planning signals.

### Standard Deviation

Measures variability in shipment activity by origin.

### Aggregation

Supports monthly, route, customer, warehouse, and origin-level planning views.

### Numeric Casting

Protects large inventory calculations and keeps aggregations numerically safe.

---

# Skills Demonstrated

This project demonstrates proficiency in:

* SQL
* Demand Planning
* Inventory Analytics
* Capacity Planning
* Logistics Analytics
* Supply Chain Analytics
* Inventory Optimization
* Working Capital Analysis
* Network Planning
* Customer Demand Analysis
* Data Modeling
* SQL Debugging
* Data Quality Validation
* Join Grain Management
* KPI Development
* Decision Support Systems

---

# Project Deliverables

The completed system provides:

* Monthly Demand Analysis
* Route Demand Ranking
* Customer Demand Analysis
* Net Inventory Position
* Stockout Risk Screening
* Overstock Exposure Screening
* Network-Level Demand vs. Inventory Context
* Origin-Level Demand Volatility
* Capacity Planning Signals
* Data Model Gap Identification
* Corrected Reusable Demand View

---

# Results

FlowPlan transforms **3,000 shipment records and 3,000 inventory positions** into a connected demand, inventory, and capacity planning system.

The project identifies where network demand is concentrated, which customer accounts drive that demand, where inventory presents shortage or excess exposure, and which origins warrant capacity review.

More importantly, the analysis corrects a major modeling issue in the original implementation:

> **3,000 shipments and 3,000 inventory records could have been combined into as many as 9 million artificial rows because the original join did not contain a real demand-to-inventory relationship.**

The corrected system removes that fan-out and clearly distinguishes between what the data can support today and what requires additional operational relationships.

The final output helps planning teams answer:

> **Where is demand concentrating?**

> **Where are we exposed to stockouts?**

> **Where is working capital trapped in excess inventory?**

> **Which origins require capacity review?**

> **How predictable is demand at each location?**

> **And what data relationships must be added before true inventory allocation and replenishment optimization become possible?**

The result is not simply an inventory report.

It is a planning framework for putting **the right resources behind the right demand, at the right time, with fewer assumptions.**

---

# Repository Structure

```text id="v6l7y9"
demand-inventory-capacity-planning/
├── README.md
├── demand_inventory_optimization.sql
└── data/
    ├── shipments.csv
    ├── customers_maritime.csv
    └── inventory.csv
```
