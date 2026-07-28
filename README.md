# Maritime Operations Intelligence

**A SQL portfolio that turns maritime shipping data into decisions across profitability, network reliability, and operational planning.**

---

## Overview

Moving more cargo does not automatically mean a shipping operation is performing well.

A network can generate strong revenue while expensive routes destroy margin. It can move thousands of shipments while recurring congestion and delays weaken service reliability. It can hold significant inventory while stock and capacity remain poorly aligned with where demand is actually occurring.

These problems are connected, but they require different decisions.

This repository contains **three standalone SQL case studies built around one simulated maritime logistics operation**, using 3,000 shipments moving across an eight-port network alongside route, customer, vessel, container, delay, fuel, and inventory data.

Together, the projects answer three management questions:

> **Are we moving freight profitably?**

> **Where is the network failing, and why?**

> **Are inventory and capacity aligned with demand?**

The result is a portfolio focused not on producing SQL queries, but on using operational data to support **commercial, operations, and planning decisions**.

---

## The Business System

```text
                     MARITIME OPERATIONS
                            |
          -----------------------------------------
          |                   |                   |
          ↓                   ↓                   ↓
     PROFITABILITY        RELIABILITY          PLANNING
          |                   |                   |
          ↓                   ↓                   ↓
       Routes              Delays              Demand
      Customers             Ports             Inventory
      Shipments             Causes            Capacity
          |                   |                   |
          ↓                   ↓                   ↓
   Margin Decisions    Network Decisions   Resource Decisions
```

Each project solves a different part of the operating model while working from the same underlying business environment.

---

# Projects

## 01. LaneProfit: Freight Margin & Cost-to-Serve Intelligence

**[View Project](./cost-to-serve-route-profitability)**

### Business Question

**Which routes, customer accounts, and individual shipments are actually worth serving?**

Revenue alone does not tell a logistics company whether freight is profitable.

A high-volume route can consume significant capacity while producing weak margins. A large customer can generate substantial revenue while costing too much to serve. Individual shipments can lose money even when portfolio-level profitability looks healthy.

LaneProfit builds a cost-to-serve and profitability model across:

* Portfolio Economics
* Route Profitability
* Customer Profitability
* Shipment-Level Margin
* Cost per Kilometer
* Transit-Time Economics
* Shipment Size Economics
* Fuel Cost Context

The project also identifies and corrects analytical problems capable of distorting commercial decisions, including a non-unique route join that could duplicate shipment financials and customer aggregation that could merge separate commercial accounts.

### Business Outcome

The analysis helps commercial and operations teams identify:

> **Which business should we grow, which business should we reprice, and where are network resources producing too little economic value?**

---

## 02. DelayWatch: Supply Chain Disruption & Root Cause Intelligence

**[View Project](./supply-chain-visibility-delay-root-cause)**

### Business Question

**What keeps disrupting the shipping network, where is it happening, and what should operations fix first?**

A shipment marked `Delayed` tells operations that something went wrong.

It does not explain whether the cause was weather, congestion, customs, or mechanical failure. It does not show whether the same route experiences the problem repeatedly or whether one destination is becoming a network bottleneck.

DelayWatch builds a disruption intelligence layer across:

* Current Delay Rate
* Historical Disruption Exposure
* Delay Causes
* Delay Frequency
* Delay Severity
* Destination Port Bottlenecks
* Recurring Route Disruption
* Congestion Exposure
* Weather Impact
* Financial Exposure

The project separates shipments currently delayed from shipments that experienced disruption historically, preventing delivered shipments with real delay events from disappearing from network reliability reporting.

### Business Outcome

The analysis moves operations from:

> **"Which shipments are late?"**

to:

> **"What is repeatedly breaking service reliability, and where should intervention happen first?"**

---

## 03. FlowPlan: Demand, Inventory & Capacity Intelligence

**[View Project](./demand-planning-inventory-optimization)**

### Business Question

**Are inventory and operating capacity positioned where network demand actually requires them?**

Too little inventory creates stockout and service risk.

Too much inventory ties up working capital.

Too little capacity creates operational pressure.

Too much capacity leaves resources underutilized.

FlowPlan connects shipment activity, customer demand, inventory position, and origin-level capacity signals to support:

* Monthly Demand Analysis
* Route Demand Analysis
* Customer Demand Analysis
* Net Inventory Position
* Stockout Risk
* Overstock Exposure
* Demand Volatility
* Capacity Planning Signals

The project also identifies an important limitation in the source data: there is no valid product-destination-warehouse relationship capable of supporting precise demand-to-inventory allocation.

Rather than creating an artificial relationship, the analysis separates what the available data can reliably answer from what would require a stronger operational data model.

### Business Outcome

The system helps planning teams answer:

> **Where is demand concentrating, where are resources becoming constrained or excessive, and what should we prepare for next?**

---

# One Network, Three Decision Layers

The projects are intentionally separate because they serve different business functions.

| Decision Area     | Core Question                                      | Primary Users                      |
| ----------------- | -------------------------------------------------- | ---------------------------------- |
| **Profitability** | Which freight creates economic value?              | Commercial, Finance, Operations    |
| **Reliability**   | What is disrupting service performance?            | Operations, Network Management     |
| **Planning**      | Where should inventory and capacity be positioned? | Supply Chain, Planning, Operations |

Together, they create a broader operating view:

```text
             DEMAND
                |
                ↓
        RESOURCE PLANNING
                |
                ↓
          SHIPMENT FLOW
                |
          --------------
          |            |
          ↓            ↓
      RELIABILITY   COST-TO-SERVE
          |            |
          ↓            ↓
      SERVICE        PROFIT
      QUALITY        QUALITY
```

A shipping operation needs all three.

Growing demand is valuable only if the network can support it.

Reliable service is valuable only if the economics remain sustainable.

Strong revenue is valuable only if enough of it survives the cost of delivering the service.

---

# Shared Data Environment

All three projects operate on the same simulated maritime logistics environment.

The shared `/data` directory contains data covering:

* Ports
* Routes
* Shipments
* Vessels
* Containers
* Customer Accounts
* Delay Events
* Fuel Prices
* Inventory

The network contains **3,000 shipment records moving across eight ports**, providing enough activity to analyze route behavior, customer demand, disruption patterns, profitability, and resource requirements across the same operating environment.

Each project uses only the datasets required for its specific business problem.

---

# Data Quality & Analytical Validation

The dataset is simulated, but the analytical problems addressed throughout the repository reflect issues that matter in real operational systems.

The projects do not assume that a SQL query is correct simply because it executes.

The analysis includes validation of:

* Join Cardinality
* Analytical Grain
* Duplicate Risk
* Customer Identity
* Route Uniqueness
* Metric Definitions
* Missing Business Relationships
* Data Quality Constraints

Several issues identified during review could have produced plausible-looking but incorrect management information.

These include:

* Shipment duplication caused by non-unique route joins
* Separate customer accounts being merged by company name
* Shipment and inventory data being combined without a valid business relationship
* Historical disruption being understated by relying only on current shipment status

The corrected projects document both the problem and its business consequence.

That is deliberate.

A query returning results is not enough.

The result has to represent the business process correctly.

---

# Analytical Approach

Across the repository, the projects follow a common workflow:

```text
Business Problem
      ↓
Understand Data Grain
      ↓
Validate Relationships
      ↓
Build Reporting Layer
      ↓
Calculate Business KPIs
      ↓
Test Analytical Logic
      ↓
Identify Patterns
      ↓
Translate Into Action
```

The focus is on moving from raw operational records to decisions that a commercial, logistics, or planning team could actually use.

---

# SQL Techniques Demonstrated

The portfolio uses SQL for more than extraction and aggregation.

Techniques include:

* Reusable Analytical Views
* Common Table Expressions
* Conditional Aggregation
* Window Functions
* `CASE`-Based Decision Logic
* Pre-Aggregation to Prevent Join Fan-Out
* `COUNT(DISTINCT ...)`
* Standard Deviation
* Financial Calculations
* Route-Level Aggregation
* Customer-Level Aggregation
* Analytical Bucketing
* Data Quality Checks
* Join Cardinality Validation
* Safe Division with `NULLIF()`

The technical work supports the business model rather than being the project itself.

---

# Business Capabilities Demonstrated

Across the three projects, the repository demonstrates work in:

* Maritime Logistics Analytics
* Supply Chain Analytics
* Commercial Analytics
* Cost-to-Serve Analysis
* Route Profitability
* Customer Profitability
* Margin Analysis
* Network Reliability
* Root Cause Analysis
* Delay & Disruption Analytics
* Demand Planning
* Inventory Analytics
* Capacity Planning
* Working Capital Analysis
* Data Modeling
* KPI Development
* SQL Debugging
* Decision Support

---

# Repository Structure

```text
maritime-supply-chain-sql/
│
├── README.md
│
├── data/
│   ├── ports.csv
│   ├── routes.csv
│   ├── shipments.csv
│   ├── vessels.csv
│   ├── containers.csv
│   ├── customers_maritime.csv
│   ├── delays_events.csv
│   ├── fuel_data.csv
│   └── inventory.csv
│
├── cost-to-serve-route-profitability/
│   ├── README.md
│   └── cost_to_serve_analysis.sql
│
├── supply-chain-visibility-delay-root-cause/
│   ├── README.md
│   └── supply_chain_delay_analysis.sql
│
└── demand-planning-inventory-optimization/
    ├── README.md
    └── demand_inventory_optimization.sql
```

---

# What This Portfolio Demonstrates

The three projects use the same operational environment, but they do not answer the same question.

**LaneProfit** asks whether network activity creates enough economic value.

**DelayWatch** asks where service reliability is breaking and what is driving the disruption.

**FlowPlan** asks whether inventory and capacity are aligned with demand.

Together, they demonstrate how the same operational data can support different levels of management decision-making across a logistics business.

The portfolio ultimately moves through three questions:

> **Are we profitable?**

> **Are we reliable?**

> **Are we prepared for demand?**

Those are the questions the SQL is built to answer.
