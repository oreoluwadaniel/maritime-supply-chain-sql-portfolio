# Maritime Supply Chain SQL Portfolio

Three standalone SQL case studies built on the same simulated maritime shipping dataset: 3,000 shipments moving across an 8-port network, along with routes, vessels, containers, customers, delay events, fuel prices, and inventory records.

Each project below is a separate, self-contained analysis with its own business problem, methodology, error check, insight, recommendation, and results. They share a data source, but they were not written as one combined report, and each one stands on its own.

## Projects

**[Cost-to-Serve and Route Profitability](./cost-to-serve-route-profitability)**
Moves the business from "how much revenue did we generate" to "how much profit did we actually keep," at the shipment, route, and customer level.

**[Supply Chain Visibility and Delay Root Cause Analysis](./supply-chain-visibility-delay-root-cause)**
Breaks down shipment delays by cause, port, route, and severity, so operations teams can trace disruption back to where it's actually happening.

**[Demand Planning and Inventory Optimization](./demand-planning-inventory-optimization)**
Connects shipment demand, inventory position, and capacity signals into one planning view, so inventory and capacity decisions follow real network activity instead of guesswork.

## Data

The `data` folder holds the shared source files used across all three projects: ports, routes, shipments, vessels, containers, customers, delay events, fuel prices, and inventory. This is simulated data, built to behave like a real maritime logistics operation, messy parts included. Each project's own README explains exactly which tables it uses and what it found.
