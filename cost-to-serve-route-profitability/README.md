# LaneProfit: Freight Margin & Cost-to-Serve Intelligence

**A SQL profitability intelligence system for identifying loss-making routes, expensive customer relationships, inefficient freight movements, and shipment-level margin leakage across a maritime logistics network.**

---

## Project Overview

A full ship is not necessarily a profitable ship.

A busy route is not necessarily a good route.

And a large customer is not necessarily a valuable customer.

That is the commercial problem behind LaneProfit.

Logistics businesses generate huge amounts of operational data around shipments, ports, routes, customers, transit times, fuel, revenue, and cost. But if management mainly tracks shipment volume and revenue, poor economics can remain hidden underneath strong activity.

A route can carry hundreds of shipments and still destroy margin.

A major account can generate significant revenue while costing too much to serve.

A shipment can look commercially successful until transport cost is included.

LaneProfit brings those economics together into one decision system.

Built in SQL across **3,000 maritime shipments and an eight-port international network**, the analysis evaluates profitability at four levels:

* Portfolio
* Route
* Customer Account
* Individual Shipment

The objective is to help commercial and operations teams answer a more useful question than:

> **How much freight did we move?**

The question is:

> **How much value did we keep after moving it, where are we losing margin, and what should we do about it?**

---

# Business Problem

Shipping economics are driven by more than revenue.

A shipment generates income, but delivering that shipment also consumes:

* Transport Capacity
* Fuel
* Route Time
* Operational Resources
* Port and Network Capacity
* Customer-Specific Commercial Terms

If those costs are not connected to revenue at the correct level, management can mistake activity for performance.

Consider two routes:

```text
Route A
Revenue: $10M
Cost:     $6M
Profit:   $4M

Route B
Revenue: $15M
Cost:     $14.5M
Profit:   $0.5M
```

Route B generates 50% more revenue.

But Route A generates eight times more profit.

A revenue dashboard may prioritize Route B.

A profitability system would ask why the network is committing so much capacity to business that produces so little economic value.

LaneProfit is designed to make that difference visible.

---

# Business Questions

The system answers nine commercial and operational questions:

1. Is the shipping portfolio profitable overall?
2. Which trade lanes create the most value?
3. Which routes are generating revenue but weak or negative margins?
4. Which customer accounts are expensive to serve?
5. Are the highest-volume customers also the most profitable?
6. Which individual shipments require pricing or cost intervention?
7. Which routes carry unusually high cost relative to distance?
8. How does shipment size relate to profitability?
9. How much of the cost environment is associated with changing fuel prices?

The result is a profitability model that moves from:

> **Network Performance**

to:

> **Route Economics**

to:

> **Account Economics**

to:

> **Individual Shipment Action**

---

# Network Scope

The simulated maritime network covers eight major ports:

* Shanghai
* Rotterdam
* Lagos
* Los Angeles
* Singapore
* Dubai
* Hamburg
* Durban

The dataset contains **3,000 shipment records** across this network.

---

# Data Sources

LaneProfit combines four connected datasets.

| Dataset       | Business Role                                                                                |
| ------------- | -------------------------------------------------------------------------------------------- |
| **Shipments** | Shipment-level revenue, cost, cargo, weight, volume, origin, destination, and movement dates |
| **Routes**    | Distance, expected transit time, and route-level fuel characteristics                        |
| **Customers** | Account identity, industry, country, and contract value                                      |
| **Fuel Data** | Regional fuel-price movements over time                                                      |

Together, these allow shipment activity to be evaluated from both an operational and financial perspective.

---

# Profitability Architecture

```text
                       SHIPPING NETWORK
                              |
          ------------------------------------------
          |                    |                   |
          ↓                    ↓                   ↓
      SHIPMENTS              ROUTES            CUSTOMERS
          |                    |                   |
          |                    ↓                   |
          |              Route Rollup              |
          |                    |                   |
          ----------------------                   |
                    |                              |
                    ↓                              |
           SHIPMENT ECONOMICS                      |
                    |                              |
                    -------------------------------
                              |
                              ↓
                     PROFITABILITY MODEL
                              |
         ---------------------------------------------
         |                |              |            |
         ↓                ↓              ↓            ↓
      Portfolio         Routes        Customers    Shipments
      Economics        Economics      Economics     Economics
         |                |              |            |
         ---------------------------------------------
                              |
                              ↓
                      MARGIN LEAKAGE ENGINE
                              |
             ---------------------------------
             |               |               |
             ↓               ↓               ↓
         REPRICE        REDUCE COST        HEALTHY
             |               |
             -----------------
                    |
                    ↓
             MANAGEMENT ACTION
```

---

# Methodology

The analysis follows four stages.

## 1. Establish Portfolio Economics

Before identifying weak routes or customers, the analysis calculates the economics of the entire shipment portfolio.

Core metrics include:

```text
Total Revenue
Total Cost
Total Profit
```

with:

```text
Profit = Revenue - Cost
```

This establishes the financial baseline against which every subsequent breakdown is evaluated.

---

## 2. Build the Route Profitability Model

Shipment financials are connected to route characteristics through a reusable profitability view.

The model combines:

* Origin
* Destination
* Shipment Revenue
* Shipment Cost
* Shipment Profit
* Route Distance
* Transit Time
* Route Characteristics

This creates the foundation for route-level commercial analysis.

---

## 3. Evaluate Customer Cost-to-Serve

Profitability is then evaluated at individual customer-account level.

This matters because:

> **Revenue measures account size.**

while:

> **Profit measures account value.**

A customer can rank highly on revenue and still be commercially weak once the cost of servicing its freight is included.

---

## 4. Convert Analysis Into Shipment Actions

Individual shipments are classified according to their economics.

Instead of giving the commercial team thousands of transaction rows, the system converts profitability into action categories such as:

### Reprice

The shipment economics indicate that the current commercial terms require review.

### Optimize Cost

Revenue may be acceptable, but the cost structure requires operational investigation.

### Healthy

The shipment is currently operating within an acceptable profitability range.

The purpose is not classification for its own sake.

It is to create a **commercial work queue**.

---

# Critical Finding 1: The Original Route Join Duplicated Shipments

The most important technical problem appeared in the route model.

The network contains eight ports.

Even if every port could connect to every other port, there are only a limited number of origin-destination combinations.

But the route dataset contains **3,000 records**.

That means an origin-destination pair appears repeatedly with different:

* Distance Values
* Transit Times
* Fuel Costs

The original model joined shipments directly to routes using:

```text
Origin Port
+
Destination Port
```

The problem is that this combination is not unique in the route table.

---

# How the Fan-Out Happened

Suppose:

```text
Lagos → Rotterdam
```

appears 45 times in the route dataset.

One Lagos-to-Rotterdam shipment joined to that table becomes:

```text
1 Shipment × 45 Route Records
=
45 Rows
```

The shipment's revenue and cost are repeated across those rows.

Do that across thousands of shipments and the analytical model no longer represents shipments.

It represents duplicated shipment-route combinations.

The SQL still runs.

The numbers still look numerical.

They are simply wrong.

---

# Business Consequence

The fan-out contaminated analyses involving:

* Route Cost
* Cost per Kilometer
* Transit-Time Economics
* Shipment Profitability

A route could therefore appear more commercially significant simply because its origin-destination pair occurred more times in the route table.

That is a data-model problem with a direct business consequence:

> **Commercial decisions could be driven by duplication rather than economics.**

---

# Correction: Establish One Route Record Per Lane

The route table is first aggregated to one analytical record per:

```text
Origin → Destination
```

Route characteristics are summarized before any shipment joins occur.

The corrected model becomes:

```text
Raw Route Records
        |
        ↓
Aggregate by Lane
        |
        ↓
One Route Profile
        |
        ↓
Join to Shipments
        |
        ↓
One Shipment + One Route Profile
```

This preserves shipment grain while still providing the route context required for profitability analysis.

---

# Critical Finding 2: Customer Names Were Not Customer Accounts

The customer dataset contains 3,000 rows.

But company names repeat across multiple:

* Customer IDs
* Countries
* Contract Values

For example, the same corporate brand can appear hundreds of times as separate customer relationships.

Grouping only by:

```text
Company Name
```

would merge those separate accounts into one artificial customer.

That creates a major problem for cost-to-serve analysis.

One profitable account and one unprofitable account belonging to the same corporate brand could cancel each other out.

Management would never see the weak relationship.

---

# Correction: Analyze Accounts, Not Labels

Customer profitability is therefore grouped using:

```text
Customer ID
+
Company Name
```

The ID defines the commercial account.

The company name remains the readable label.

This means:

> **Each customer relationship keeps its own economics.**

That is the level at which pricing, contracts, service terms, and account reviews can actually be changed.

---

# Critical Finding 3: Fuel Comparison Used an Invalid Relationship

The original fuel analysis matched shipments and fuel prices by year.

But there was no direct relationship between a specific shipment and a specific regional fuel-price observation.

Joining the raw tables on year could therefore multiply records heavily.

The resulting average would reflect the shape of the join rather than a clean comparison of annual shipment cost and fuel conditions.

---

# Correction: Aggregate Before Comparing

Fuel and shipment data are summarized independently.

```text
Fuel Data
    |
    ↓
Region + Year Summary
```

and:

```text
Shipment Data
    |
    ↓
Yearly Cost Summary
```

Only then are the summarized results compared.

This prevents raw transactional records from multiplying each other and produces a cleaner basis for evaluating the external fuel-cost environment.

---

# Critical Finding 4: Shipment Weight Was Too Granular

Shipment weight is recorded with decimal precision.

Grouping directly by exact weight therefore creates almost one category per shipment.

For example:

```text
71.28 tons
71.31 tons
71.47 tons
71.83 tons
```

are technically different groups.

But commercially, that tells management almost nothing.

---

# Correction: Weight Bands

Shipments are grouped into meaningful ranges such as:

```text
Under 50 Tons
50–99 Tons
100–149 Tons
150–199 Tons
200+ Tons
```

The analysis can then test whether larger shipments tend to produce stronger economics or whether certain size bands consistently carry weak margins.

---

# Route Profitability Intelligence

Routes are ranked using:

* Shipment Volume
* Revenue
* Cost
* Profit

The objective is not simply to identify the busiest lanes.

It is to identify:

> **Which lanes convert network activity into economic value?**

A high-volume route with weak or negative profit is a candidate for:

* Repricing
* Carrier Negotiation
* Cost Reduction
* Schedule Review
* Service Redesign
* Capacity Reallocation

---

# Customer Cost-to-Serve Intelligence

Customer accounts are ranked by actual profitability.

The analysis distinguishes between:

> **Large Accounts**

and:

> **Profitable Accounts**

because those categories do not necessarily contain the same customers.

This helps management identify:

### High-Volume, High-Profit Accounts

Protect and grow.

### High-Volume, Low-Profit Accounts

Review pricing and service terms.

### Lower-Volume, Strong-Margin Accounts

Potential growth opportunities.

### Loss-Making Accounts

Reprice, restructure, or reassess the relationship.

---

# Shipment-Level Margin Intelligence

Portfolio averages can hide bad individual movements.

LaneProfit therefore evaluates individual shipment economics.

A shipment can be profitable while its route is weak overall.

A route can be profitable while individual shipments are being badly priced.

Both levels matter.

The shipment-level action engine surfaces movements requiring attention before repeated weak economics accumulate into a quarterly margin problem.

---

# Cost per Kilometer

Absolute route cost is difficult to compare because routes have different distances.

LaneProfit normalizes route economics using:

```text
Cost per Kilometer
```

This creates a common scale for comparing lanes.

A long route may have a large total cost but still operate efficiently.

A shorter route may look cheap in absolute terms while costing disproportionately more for every kilometer moved.

Normalization makes that difference visible.

---

# Transit-Time Economics

Transit time is evaluated against profitability to identify whether slower routes are producing enough commercial value to justify the network resources they consume.

This does not assume that:

> **Longer Transit = Bad Route**

because some longer services may carry premium economics.

The useful question is:

> **Are we being compensated for the time and capacity this lane consumes?**

---

# Shipment Size Economics

Weight bands allow the analysis to compare shipment size against profit.

This can help identify whether:

* Larger shipments produce economies of scale
* Smaller shipments carry disproportionately high servicing cost
* Certain shipment sizes need different pricing structures

The analysis turns shipment weight into a commercial variable rather than leaving it as descriptive operational data.

---

# Fuel Cost Context

Fuel is a major external cost driver in maritime logistics.

LaneProfit compares changing fuel-price environments with shipment cost trends to provide context around cost pressure.

This distinction matters.

If route economics deteriorate while fuel prices rise sharply, part of the problem may be external.

If costs deteriorate while fuel conditions remain stable, the issue is more likely internal to:

* Carrier Terms
* Route Design
* Operational Efficiency
* Service Structure
* Pricing

The analysis helps management know where to investigate.

---

# Data Quality Finding: Impossible Shipment Dates

The dataset contains shipment records where:

```text
Arrival Date < Departure Date
```

That is physically impossible.

The current profitability analysis does not calculate shipment duration directly from these dates, so the issue does not change the financial results presented here.

But it creates an important boundary:

> **Raw departure and arrival dates should not be used for transit-time calculations until those records are validated and corrected.**

This is documented rather than silently cleaned because the available data does not establish what the correct dates should have been.

---

# Business Recommendations

## 1. Put Loss-Making Lanes on a Commercial Review List

Routes with sustained weak economics should be reviewed jointly by commercial and operations teams.

The question is not automatically:

> **Should we stop serving this route?**

First determine whether the problem comes from:

* Pricing
* Transport Cost
* Route Structure
* Customer Mix
* Service Requirements

Different causes require different interventions.

---

## 2. Review High-Volume, Low-Profit Accounts Before Renewal

Large customers with weak economics should be identified before contracts are renewed.

Potential interventions include:

* Price Renegotiation
* Minimum Volume Commitments
* Fuel Surcharges
* Service-Level Changes
* Route Restrictions
* Contract Restructuring

Revenue size alone should not protect an account from profitability review.

---

## 3. Operationalize the Shipment Action List

The shipment-level recommendation engine should run regularly.

Instead of discovering weak pricing after a quarter closes, commercial teams can identify problematic movements as they occur.

This converts profitability analysis from:

> **Historical Reporting**

into:

> **Margin Management**

---

## 4. Negotiate Routes Using Normalized Cost

Carrier and route discussions should use cost per kilometer and route-level profitability rather than total cost alone.

That creates a fairer comparison across lanes of different lengths.

---

## 5. Separate External Cost Pressure From Internal Inefficiency

Fuel trends should be reviewed alongside shipment cost.

When costs rise, management needs to know whether the network became less efficient or whether external fuel conditions changed.

Without that distinction, the wrong part of the business may be targeted for cost reduction.

---

# Business Value

LaneProfit improves profitability management across four areas.

## Margin Protection

Loss-making routes, accounts, and shipments become visible before they accumulate into larger financial problems.

## Pricing Discipline

Commercial teams can identify where revenue is not producing enough profit and target repricing where it matters most.

## Account Management

Customers can be evaluated according to the economics of the actual account rather than brand recognition or shipment volume.

## Network Efficiency

Route distance, transit time, shipment size, and fuel conditions provide context for why margins differ across the network.

The shift is from:

> **"How much cargo moved through the network?"**

to:

> **"Which cargo, customers, and lanes deserve the capacity we're giving them?"**

---

# Technical Corrections

Four material analytical problems were identified and corrected.

| Issue                             | Business Consequence                               | Correction                                              |
| --------------------------------- | -------------------------------------------------- | ------------------------------------------------------- |
| Non-unique route join             | Shipments duplicated across repeated route records | Aggregate routes to one profile per lane before joining |
| Customer grouping by company name | Separate accounts merged into artificial customers | Group by customer ID and company name                   |
| Raw fuel-to-shipment year join    | Record multiplication distorted comparison         | Aggregate both sides before joining                     |
| Exact shipment-weight grouping    | Almost one group per shipment                      | Introduce meaningful weight bands                       |

A separate data-quality issue involving impossible arrival and departure dates was also documented for future transit-time analysis.

---

# Tools & Techniques

### SQL

The complete profitability system is implemented using relational SQL.

### Reusable Profitability View

`v_profitability` provides a standardized source for shipment financials and route characteristics.

### Pre-Aggregation

Route data is reduced to the required analytical grain before joining to shipments, preventing fan-out.

### Common Table Expressions

CTEs independently summarize fuel and shipment data before comparisons are made.

### `CASE`

Used to convert shipment economics into business-readable action categories.

### Aggregate Functions

Support portfolio, route, customer, and shipment-level profitability analysis.

### `NULLIF()`

Protects normalized cost calculations from division by zero.

### Analytical Bucketing

Continuous shipment weight is converted into decision-useful categories rather than near-unique values.

---

# Skills Demonstrated

This project demonstrates proficiency in:

* SQL
* Logistics Analytics
* Maritime Shipping Analytics
* Cost-to-Serve Analysis
* Route Profitability
* Customer Profitability
* Commercial Analytics
* Margin Analysis
* Freight Economics
* Transport Cost Analysis
* Data Modeling
* Data Quality Validation
* Join Grain Management
* SQL Debugging
* KPI Development
* Decision Support Systems

---

# Project Deliverables

The completed analysis provides:

* Portfolio Revenue, Cost & Profit Baseline
* Route Profitability Ranking
* Loss-Making Lane Identification
* Customer Cost-to-Serve Analysis
* Customer Profitability Ranking
* Shipment-Level Action Engine
* Cost-per-Kilometer Analysis
* Transit-Time Profitability Analysis
* Shipment Weight Profitability Bands
* Fuel Cost Context Analysis
* Data Quality Findings
* Corrected Reusable Profitability Model

---

# Results

LaneProfit transforms **3,000 maritime shipments across an eight-port international network** into a route, customer, and shipment-level profitability system.

The project identified and corrected four analytical issues that could otherwise distort commercial decisions.

Most importantly:

> **The original route join could duplicate each shipment across dozens of route records because origin and destination were not unique in the route dataset.**

and:

> **Grouping customers by company name could combine hundreds of separate commercial relationships into one artificial account.**

The corrected system preserves shipment-level financial integrity, evaluates actual customer accounts, normalizes route costs, adds external fuel context, and converts individual shipment economics into a commercial action list.

The result is not another logistics dashboard.

It is a decision system designed to answer:

> **Which routes should we reprice or optimize?**

> **Which customer relationships are worth growing?**

> **Which accounts are consuming capacity without enough margin?**

> **Which shipments need intervention now?**

> **And where is the network generating activity without generating enough economic value?**

---

# Repository Structure

```text
cost-to-serve-route-profitability/
├── README.md
├── cost_to_serve_analysis.sql
└── data/
    ├── shipments.csv
    ├── routes.csv
    ├── customers.csv
    └── fuel_data.csv
```
