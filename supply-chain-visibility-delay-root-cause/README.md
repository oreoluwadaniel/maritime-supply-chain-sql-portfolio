# DelayWatch: Supply Chain Disruption & Root Cause Intelligence

**A SQL operations intelligence system for detecting recurring shipment disruptions, identifying their root causes, locating network bottlenecks, and prioritizing operational intervention across a maritime logistics network.**

---

## Project Overview

Knowing that a shipment is delayed is useful.

Knowing **why delays keep happening, where they concentrate, how severe they become, and which problems keep returning** is what gives operations something to fix.

A shipping network can report a reasonable overall delivery rate while specific ports, routes, or disruption types repeatedly create service failures underneath the average.

A weather delay may be unavoidable.

A route suffering the same disruption every month is different.

A congested destination repeatedly adding long delays is different.

And a shipment that was delayed but eventually delivered should not disappear from disruption reporting simply because its final status changed.

**DelayWatch** turns shipment, disruption, and port data into a network reliability system designed to answer:

> **How much of the network is being disrupted?**
> **What is causing those disruptions?**
> **Which causes create the longest delays?**
> **Where are bottlenecks concentrated?**
> **Which routes keep experiencing problems?**
> **How strongly are congestion and weather associated with delay severity?**
> **And where should operations intervene first?**

Built in SQL across **3,000 shipments moving through an eight-port maritime network**, the project moves delay reporting from a status field into a structured **root cause and operational prioritization framework**.

---

# Business Problem

A status field such as:

```text
Delayed
```

describes an outcome.

It does not diagnose the problem.

Two delayed shipments may represent completely different operational situations.

```text
Shipment A
Delay: 2 days
Cause: Weather
Route: No recurring issue

Shipment B
Delay: 11 days
Cause: Port Congestion
Route: Repeated disruption
Destination: High-congestion port
```

Both shipments are technically delayed.

They should not receive the same operational response.

The first may be an isolated external event.

The second may indicate a structural network problem.

That distinction matters because operations cannot eliminate every disruption. What it can do is identify **recurring, severe, and concentrated problems** and allocate attention where intervention is most likely to improve service reliability.

DelayWatch is built around that principle.

---

# Business Questions

The system answers a sequence of operational questions:

1. How many shipments are currently delayed?
2. How many shipments experienced a disruption at any point?
3. What causes delays most frequently?
4. Which causes create the longest disruptions?
5. Which destination ports experience the most delay activity?
6. Are congested ports associated with longer delays?
7. Which origin-destination lanes experience repeated disruption?
8. How much does weather feature in the disruption profile?
9. What is the financial size of shipments affected by delays?
10. Which disruption events should operations investigate first?

Together, these move the analysis from:

> **Delay Detection**

to:

> **Root Cause Diagnosis**

to:

> **Operational Prioritization**

---

# Data Sources

DelayWatch combines three connected datasets.

| Dataset         | Business Role                                                                              |
| --------------- | ------------------------------------------------------------------------------------------ |
| `shipments`     | Core shipment activity, origin, destination, dates, status, revenue, and cost              |
| `delays_events` | Shipment disruption history, reason, delay duration, weather impact, and congestion impact |
| `ports`         | Destination-level port information and congestion ratings                                  |

The network contains **3,000 shipments across eight ports**.

Delay events are classified into four operational causes:

* Weather
* Port Congestion
* Customs
* Mechanical

Each disruption also records:

* Delay Duration
* Weather Impact Score
* Port Congestion Score

This makes it possible to analyze both **what happened** and **how severe the disruption became**.

---

# Operations Intelligence Architecture

```text
                       SHIPPING NETWORK
                              |
                 ---------------------------
                 |                         |
                 ↓                         ↓
             SHIPMENTS                  PORTS
                 |
                 ↓
            DELAY EVENTS
                 |
                 ↓
        SUPPLY CHAIN VISIBILITY
                 |
      ---------------------------------
      |               |               |
      ↓               ↓               ↓
   Frequency        Severity        Location
      |               |               |
      ↓               ↓               ↓
 Delay Cause     Delay Duration    Ports / Routes
      |               |               |
      ---------------------------------
                      |
                      ↓
              ROOT CAUSE ANALYSIS
                      |
        --------------------------------
        |              |               |
        ↓              ↓               ↓
    Congestion       Weather       Recurrence
        |              |               |
        --------------------------------
                      |
                      ↓
              DISRUPTION PRIORITY
                      |
          ---------------------------
          |            |            |
          ↓            ↓            ↓
       Monitor       Review       Escalate
          |            |            |
          ---------------------------
                      |
                      ↓
              OPERATIONS ACTION
```

---

# Methodology

The analysis moves from network visibility to diagnosis and then prioritization.

## 1. Validate Data Availability

Before building the analytical layer, the script checks:

* Shipment availability
* Delay-event availability
* Sample disruption records

This establishes that the required operational data exists before downstream KPIs are calculated.

---

## 2. Build a Reusable Visibility Layer

A single view, `v_supply_chain_visibility`, connects:

```text
Shipment
   +
Delay Event
   +
Destination Port Conditions
```

This creates one reusable source for downstream disruption analysis instead of rebuilding the same three-table relationship across multiple queries.

The view supports analysis across:

* Shipment Status
* Delay Cause
* Delay Duration
* Origin
* Destination
* Weather Impact
* Port Congestion
* Revenue
* Cost

---

## 3. Measure Disruption Exposure

Delay exposure is measured in two different ways because the two metrics answer different business questions.

### Current Delay Rate

Uses shipment status to identify shipments currently classified as delayed.

This answers:

> **How much of the network is delayed right now?**

### Historical Disruption Exposure

Uses distinct shipment IDs appearing in the delay log.

This answers:

> **How much of the network has experienced a recorded disruption?**

Both metrics are retained because neither replaces the other.

---

# Critical Finding 1: "Currently Delayed" Is Not the Same as "Experienced a Delay"

The original headline metric used:

```text
shipment_status = 'Delayed'
```

That is a valid operational KPI.

But it has a narrower meaning than an overall disruption rate.

Consider:

```text
Shipment A
Experienced 6-day customs delay
Final Status: Delivered
```

and:

```text
Shipment B
Experienced 3-day congestion delay
Current Status: Delayed
```

A status-based calculation counts Shipment B.

It does not count Shipment A.

Yet both shipments experienced operational disruption.

This means relying on current shipment status alone can understate the network's historical disruption exposure.

---

# Correction: Two Delay Metrics

DelayWatch reports both measures separately.

```text
CURRENT DELAY RATE
        |
        ↓
Shipments currently marked Delayed
```

and:

```text
DISRUPTION EXPOSURE
        |
        ↓
Distinct shipments appearing in delay history
```

This prevents one metric from being interpreted as something it does not measure.

It also gives operations two useful views:

> **What is happening now?**

and:

> **What has been happening across the network?**

---

# Delay Frequency vs. Delay Severity

One of the most important distinctions in disruption analysis is:

> **How often does the problem happen?**

versus:

> **How much damage does it cause when it happens?**

These are not the same thing.

For example:

```text
Cause A
Events: 180
Average Delay: 1.5 days

Cause B
Events: 70
Average Delay: 9 days
```

Cause A occurs much more frequently.

Cause B may create greater service exposure per incident.

DelayWatch therefore evaluates disruption causes using both:

* Event Frequency
* Average Delay Duration

This prevents the operations team from automatically treating the most common problem as the most important one.

---

# Root Cause Intelligence

Delay causes are ranked according to their frequency and severity.

The analysis covers:

### Weather

External disruption associated with environmental conditions.

### Port Congestion

Network pressure at destination facilities.

### Customs

Clearance-related disruption.

### Mechanical

Equipment or operational reliability problems.

The objective is not simply to produce a pie chart of delay reasons.

It is to identify:

> **Which causes deserve management attention based on both recurrence and operational impact?**

---

# Port Bottleneck Intelligence

Delay events are aggregated by destination port.

This identifies ports carrying a disproportionate share of network disruption.

A high-delay destination may indicate issues involving:

* Berth Availability
* Port Congestion
* Scheduling
* Carrier Allocation
* Local Handling Capacity
* Customs Processes

The result is a ranked view of where network reliability is weakest geographically.

---

# Congestion Analysis

DelayWatch compares port congestion conditions with delay duration.

The purpose is to test whether:

> **More congested destinations are also experiencing more severe delays.**

That distinction matters.

A port may have a high congestion rating without materially affecting shipment performance.

Another may show both high congestion and prolonged disruption.

The second case deserves greater operational attention because the congestion signal is showing up in actual service outcomes.

---

# Route Recurrence Intelligence

A single disruption can be random.

Repeated disruption on the same origin-destination lane is harder to dismiss.

DelayWatch therefore aggregates delay events by:

```text
Origin Port
      ↓
Destination Port
```

to identify lanes repeatedly appearing in the disruption history.

Recurring lane problems may indicate:

* Weak Routing Decisions
* Carrier Performance Problems
* Scheduling Constraints
* Destination Bottlenecks
* Repeated Customs Friction
* Structural Capacity Problems

These routes should not be managed as isolated incidents.

They require **lane-level investigation**.

---

# Weather Exposure

Weather impact is analyzed separately from other operational causes.

This matters because weather is often treated as an explanation for poor service performance without checking how much of the disruption profile it actually explains.

DelayWatch uses the available weather-impact data to provide context around:

* Weather-Associated Disruption
* Average Delay Severity
* Relative Exposure

The purpose is to separate genuine weather-related disruption from problems that operations may actually be able to control.

---

# Financial Exposure

Delay analysis becomes more useful when disruption is connected to commercial value.

The visibility layer retains shipment:

* Revenue
* Cost

This allows delayed shipment activity to be evaluated not only by event count but also by the financial size of the affected shipment pool.

That helps distinguish between:

> **A large number of relatively small disrupted shipments**

and:

> **A smaller number of commercially significant shipments experiencing disruption**

The current data supports measuring financial exposure associated with delayed shipments.

It does **not** support claiming that all shipment revenue or profit associated with a delay was lost because of that delay.

That would require additional data on penalties, cancellations, demurrage, recovery cost, lost customers, or service credits.

---

# Delay Severity Classification

Raw delay days are converted into severity bands.

For example:

```text
SHORT DELAY
      ↓
Lower operational urgency

MEDIUM DELAY
      ↓
Requires investigation

SEVERE DELAY
      ↓
Priority operational review
```

This makes the output easier to operationalize.

A planner should not have to inspect thousands of raw delay-duration values to decide what requires attention first.

Severity classification converts those values into a manageable investigation queue.

---

# Critical Finding 2: The Core Join Was Structurally Sound

After the fan-out issue discovered in the related route-profitability project, the port join in this analysis required specific validation.

The visibility model connects shipment destinations to:

```text
ports.port_name
```

The eight port names are unique in the port dataset.

That means the port join does not introduce the same many-to-many duplication problem found elsewhere in the maritime portfolio.

This matters because reliable analytics is not only about finding broken logic.

It is also about confirming that critical relationships are safe before trusting downstream KPIs.

---

# Critical Finding 3: The Original View Was Not Safely Re-Runnable

The original script created `v_supply_chain_visibility` without handling the case where the view already existed.

That means rerunning the project could fail before the analysis even began.

The corrected version adds safe recreation logic so the analytical layer can be rebuilt without manual cleanup.

This is a small technical change, but it makes the project more usable as a repeatable operational workflow rather than a one-time SQL exercise.

---

# Operational Prioritization Framework

DelayWatch supports three levels of response.

## Monitor

Low-severity or isolated disruption.

These events should remain visible but may not justify immediate intervention.

## Review

Repeated or moderate disruption requiring investigation.

Examples include:

* Recurring lane problems
* Rising congestion exposure
* Causes with meaningful average delay duration

## Escalate

Severe or persistent disruption with material operational exposure.

These events should move to the front of the operations queue.

The objective is to move from:

> **"Here are all our delayed shipments."**

to:

> **"Here are the disruption patterns that deserve action first."**

---

# Business Recommendations

## 1. Prioritize Causes by Severity and Frequency Together

Operations should not rank disruption causes using event count alone.

High-frequency, short-duration problems and lower-frequency, long-duration problems require different responses.

The priority matrix should consider both:

```text
Frequency × Severity
```

before deciding where improvement effort goes.

---

## 2. Put Repeatedly Disrupted Lanes on Standing Review

Routes that repeatedly appear in the delay history should be reviewed as structural problems.

Investigate:

* Carrier Choice
* Sailing Schedule
* Routing
* Destination Constraints
* Customs Exposure
* Capacity

If the same lane produces the same problem every reporting cycle, incident-by-incident management is no longer enough.

---

## 3. Investigate High-Congestion Destinations

Ports showing both elevated congestion and longer delay duration deserve direct operational review.

Potential interventions may include:

* Schedule Adjustment
* Alternative Carrier Allocation
* Different Arrival Windows
* Alternative Routing
* Capacity Planning

The exact intervention depends on the cause identified in the underlying events.

---

## 4. Separate Current Delays From Historical Reliability

Management reporting should retain both:

* Current Delay Rate
* Historical Disruption Exposure

The first supports daily operations.

The second supports network improvement.

Combining them into one vague "delay rate" hides useful information.

---

## 5. Add Commercial Consequence Data

A strong next version of the system should connect disruption to actual business consequences such as:

* SLA Penalties
* Demurrage
* Customer Credits
* Expediting Costs
* Cancellation
* Lost Revenue
* Customer Complaints

That would allow the system to move from:

> **Delay Severity**

to:

> **Financial Impact of Delay**

and rank disruptions by actual business cost.

---

# Business Value

DelayWatch creates value across four operational areas.

## Service Reliability

Recurring disruption becomes visible at cause, port, and route level instead of remaining scattered across individual shipment records.

## Root Cause Management

Operations can distinguish between frequent problems, severe problems, external disruption, and potentially controllable network issues.

## Resource Prioritization

Severity classification and recurring-lane analysis help teams focus investigation on the disruptions most likely to matter.

## Management Visibility

Current delay exposure and historical disruption exposure are separated, giving leadership a clearer view of both today's operational pressure and the network's underlying reliability.

The shift is from:

> **"How many shipments are delayed?"**

to:

> **"What keeps disrupting the network, where does it happen, how severe is it, and what should operations fix first?"**

---

# Technical Review

The original analysis was structurally stronger than the other maritime projects, but two improvements were still required.

| Issue                                            | Business Consequence                                                                | Correction                                                              |
| ------------------------------------------------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Delay rate based only on current shipment status | Delivered shipments with historical disruption disappeared from the headline metric | Report current delay rate and historical disruption exposure separately |
| View could not be recreated safely               | Re-running the workflow could fail                                                  | Add safe view recreation logic                                          |

The core analytical joins were also validated.

In particular, `ports.port_name` is unique across the eight-port dataset, so the destination-port join does not create row fan-out.

---

# Tools & Techniques

### SQL

The full disruption analysis is implemented in SQL.

### Reusable Visibility View

`v_supply_chain_visibility` centralizes shipment, delay, and destination-port context.

### `INNER JOIN`

Used when analysis specifically requires a recorded disruption event, such as delay cause or recurring-route analysis.

### `LEFT JOIN`

Used where all shipments must remain visible regardless of whether a delay event exists.

### `CASE`

Converts raw delay duration into operational severity bands.

### `COUNT(DISTINCT ...)`

Separates disrupted shipments from raw delay-event counts and prevents multiple events from automatically becoming multiple affected shipments.

### Aggregation

Supports delay frequency, average duration, port concentration, route recurrence, and financial exposure analysis.

---

# Skills Demonstrated

This project demonstrates proficiency in:

* SQL
* Supply Chain Analytics
* Logistics Analytics
* Root Cause Analysis
* Operational Performance Analysis
* Delay & Disruption Analytics
* Network Reliability
* Port Operations Analysis
* Route Performance Analysis
* Data Modeling
* KPI Development
* Data Quality Validation
* SQL Join Validation
* Operational Prioritization
* Decision Support Systems

---

# Project Deliverables

The completed system provides:

* Current Shipment Delay Rate
* Historical Disruption Exposure
* Delay Cause Analysis
* Frequency vs. Severity Comparison
* Destination Port Bottleneck Analysis
* Congestion vs. Delay Analysis
* Recurring Route Identification
* Weather Exposure Analysis
* Delayed Shipment Financial Exposure
* Delay Severity Classification
* Reusable Supply Chain Visibility Layer
* Operational Prioritization Framework

---

# Results

DelayWatch transforms **3,000 maritime shipment records, disruption events, and port conditions** into a network reliability and root cause intelligence system.

The analysis moves beyond counting delayed shipments to identify:

* What is causing disruption
* Which causes persist longest
* Where delays concentrate
* Which lanes experience repeated problems
* Whether congestion aligns with delay severity
* How weather features in the disruption profile
* Which disrupted shipments carry meaningful commercial exposure
* Which incidents deserve investigation first

The project also corrects an important KPI interpretation problem:

> **A shipment that experienced a real disruption but was eventually delivered should not disappear from historical reliability reporting simply because its current status is no longer "Delayed."**

DelayWatch therefore separates **current operational delay** from **historical disruption exposure**, giving operations a more complete view of network reliability.

The final system helps answer:

> **What is disrupting the network?**

> **Where are the bottlenecks?**

> **Which problems are recurring rather than isolated?**

> **Which causes create the greatest delay severity?**

> **Which ports and lanes deserve operational intervention?**

> **And where should the team focus first if the goal is to improve service reliability?**

The result is not a delay report.

It is a **disruption diagnosis and operational prioritization system** built to help a logistics team find recurring failure patterns before they become normal operating conditions.

---

# Repository Structure

```text
supply-chain-delay-intelligence/
├── README.md
├── supply_chain_delay_analysis.sql
└── data/
    ├── shipments.csv
    ├── delays_events.csv
    └── ports.csv
```
