# Demand Planning and Inventory Optimization

A SQL project that connects shipment demand, inventory position, and capacity planning into one working view, built around a simple planning rule: inventory and capacity should follow demand, not guesswork.

## Business problem

Planning decisions in logistics are usually made in one of two failure modes. Either there isn't enough inventory or capacity to meet actual demand, which creates stockouts and service pressure, or there's too much of it sitting idle, which ties up money and warehouse space for no return. Both mistakes come from the same root cause: planning without a clear, current view of where demand is actually coming from and how it's moving.

This project builds that view for a maritime shipping operation. It answers where shipment demand is concentrated, which customers are driving it, what the current inventory position looks like, which products are at risk of running out, where stock is piling up without being used, and which origins need more or less capacity based on actual shipment activity rather than assumption.

## Data source

Same underlying maritime dataset used across this series: 3,000 shipments across an 8-port network, plus 3,000 inventory records tracking stock by warehouse and product.

Shipments provides origin, destination, departure date, weight, and volume, which together make up the demand signal.

Customers_maritime links each shipment back to the company driving it.

Inventory tracks stock level, inbound quantity, and outbound quantity per warehouse and product combination, which is what the net stock and stockout checks are built from.

All source files sit in the [`/data`](../data) folder at the root of this repository.

## Methodology

I split this into three connected planning views, which is how the business questions were actually framed.

Demand first. I built a simplified demand view, v_demand_base, holding just the fields needed for this kind of analysis: shipment ID, origin, destination, departure date, weight, and volume. From there, monthly shipment volume shows when demand is changing over time. Origin-destination pairs show where demand concentrates by lane. Customer-level grouping shows who's actually driving that demand, which matters for capacity conversations with specific accounts.

Inventory second. Net stock is calculated directly as current stock plus inbound minus outbound, which gives a simple forward-looking position rather than just a snapshot. Two screening rules sit on top of that: a stockout flag for anything where stock is already below outbound requirements, and an overstock flag for anything sitting above a 5,000 unit threshold, both intentionally simple so they surface candidates for review rather than pretending to be a final answer.

Capacity third. Standard deviation of shipment weight by origin port measures how predictable demand is at each location, since a volatile origin needs more planning buffer than a stable one. And a straightforward capacity signal (increase, reduce, or hold steady) translates raw shipment counts per origin into a planning action, using thresholds the script states plainly rather than hiding inside a formula.

## Analysis and error check

I found three issues worth flagging, one of which the original script's own comments had already partly noticed but didn't actually fix.

The first was the demand-versus-inventory comparison, and it's the one I want to spend the most time on because it was the most serious. The original query joined shipments to inventory using ON s.destination_port IS NOT NULL. That condition is true for almost every row on both sides of the join, so it isn't really filtering anything. It functions as a full cross join instead: every shipment record gets matched against every inventory record. With 3,000 rows on each side, that's up to nine million combined rows, and the SUM(stock_level) in the original query ends up adding the same inventory figures in over and over, once for every shipment tied to that destination. The number that comes out the other end looks like a real supply figure but isn't measuring anything meaningful. To be fair to whoever wrote the original version, the comments directly above that query already flagged that the join doesn't map to a specific destination, warehouse, or product, which is the right observation. But a comment acknowledging a problem isn't the same as fixing it, so I did: shipment demand by destination and total inventory across the whole network are now calculated as two separate, already-summarized result sets, and only those two summaries get combined, using a cross join that's actually safe because one side of it is guaranteed to be exactly one row. I want to be equally direct about the limitation that's still there afterward: this is a network-level comparison for context, not a true demand-to-supply match, because the data itself has no column connecting a specific warehouse or product to a specific destination port. That's a gap in the data model, not something a smarter query can patch over, and I'd rather say that plainly than dress up a fixed query as more precise than it actually is.

The second issue was the same customer grouping problem found in the cost-to-serve project. Customers_maritime has 3,000 rows, but a small set of company names repeat across hundreds of different customer IDs, countries, and contract values. Grouping "who is driving demand" by company name alone would merge distinct customer accounts into a single inflated row. I fixed this the same way as before, adding customer ID into the grouping so demand gets measured at the real account level.

The third was a missing safeguard on the view definition, the same small fix applied across all three scripts in this series, so v_demand_base can be recreated safely if it already exists.

I did not find any issues with the stockout logic, the overstock threshold, or the capacity signal thresholds. Those are planning rules by design, and the original script is upfront that 5,000 units and the 100/30 shipment thresholds are planning conventions rather than universal definitions, which is exactly the right way to present a threshold like that.

## Insight

Demand wasn't spread evenly across the network. A small number of origin-destination pairs carried a disproportionate share of shipment volume, and a similarly small number of customer accounts, once correctly separated by customer ID, accounted for a meaningful chunk of total shipment weight. On the inventory side, the stockout and overstock screens both returned real candidates, meaning the network is carrying risk in both directions at once: some product-warehouse combinations are genuinely short on stock relative to outbound demand, while others are sitting well above the overstock threshold with no clear demand pulling that stock down. The capacity signal, run against real origin-level shipment counts, produced a mixed set of increase, reduce, and stable recommendations rather than one uniform answer, which is what you'd expect from a network handling genuinely different levels of activity at each port.

## Recommendation

Prioritize the flagged stockout risk items first, since those represent immediate service exposure, and cross-check them against the busiest origin-destination pairs to catch cases where a popular lane is also sitting on thin inventory. Review the overstock list separately from a working capital angle, since freeing up cash tied to unused stock is a lower-urgency but real opportunity. On capacity, treat the increase and reduce flags as a starting conversation with operations rather than an automatic instruction, since the underlying thresholds are a planning convention and should be sanity-checked against known seasonal patterns before capacity actually changes.

## Business impact

Getting inventory and capacity closer to actual demand protects margin from both directions. Understocking a fast-moving lane risks lost business and rushed, expensive replenishment. Overstocking ties up working capital that could be deployed elsewhere. Neither mistake shows up clearly on a simple revenue report, which is exactly why a planning view like this one, built directly from shipment and inventory records rather than assumption, is worth having as a standing report rather than a one-time exercise.

## What was done

I built a demand base view and used it to answer where, when, and from whom shipment demand is coming, then layered a net stock, stockout, and overstock screen on top of the inventory table, and closed with a capacity signal tied to real shipment counts by origin. During review, I found and corrected a serious join fan-out in the demand-versus-inventory comparison that the original script had flagged but not actually fixed, corrected the same customer grouping issue found in the related cost-to-serve project, and added a missing safeguard to the view definition.

## Tools used and how they helped

Built in SQL using a view for the reusable demand base, common table expressions to properly separate and summarize the demand and supply sides before combining them, CASE-based classification for stockout, overstock, and capacity signals, STDEV for measuring demand volatility by origin, and CAST to keep the stock level summation numerically safe at scale. The common table expression fix here is worth calling out specifically: it's the same technique used to fix the fuel price comparison in the cost-to-serve project, and it's the general pattern for any situation where you need to compare two tables that don't share a real one-to-one key. Summarize each side down first, then join the summaries, not the raw tables.

## Results

The corrected script delivers three connected planning views: monthly and route-level demand trends with corrected customer attribution, a full net stock position with stockout and overstock screening, and a capacity signal by origin backed by a real volatility measure. The most serious issue in this script, a fan-out join inflating the demand-to-supply comparison to millions of meaningless rows, was found and properly fixed rather than left as a documented limitation, and the remaining gap (no product-to-destination key in the source data) is now stated clearly rather than implied by an approximate number.
