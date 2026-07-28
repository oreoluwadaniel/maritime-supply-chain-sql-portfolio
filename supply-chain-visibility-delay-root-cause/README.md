# Supply Chain Visibility and Delay Root Cause Analysis

A SQL project built around a question every shipping operations team eventually asks: we know shipments are getting delayed, but why, where, and how badly?

## Business problem

A shipment status field that says "Delayed" tells you almost nothing useful on its own. It doesn't tell you if the problem was weather, customs, port congestion, or a mechanical issue. It doesn't tell you if the delay was two days or two weeks. It doesn't tell you whether one port is quietly becoming a bottleneck for the whole network, or whether a specific route keeps breaking down for the same reason every month.

Operations teams need more than a delay count. They need to know where problems concentrate, what's actually causing them, how severe they tend to be, and whether congestion or weather is a real driver or just background noise. This project builds that layer of visibility on top of the raw shipment and delay records, turning "this shipment is late" into "this is the third time this route has had a customs delay this quarter, and it's getting worse."

## Data source

This uses the same simulated maritime shipping dataset as the other two projects in this series, 3,000 shipments moving across an 8-port network. Two tables do most of the work here.

Shipments carries the core shipment record: origin, destination, dates, status, revenue, and cost.

Delays_events is the disruption log. Each record ties back to a shipment and captures the delay reason (weather, port congestion, customs, or mechanical), how many days the delay lasted, a weather impact score, and a port congestion score.

Ports adds destination-level congestion ratings, which get pulled in to check whether congested ports are actually producing longer delays or whether congestion and delay severity are unrelated in this data.

All source files sit in the [`/data`](../data) folder at the root of this repository.

## Methodology

I built this analysis in layers, starting broad and narrowing down to specific causes.

First, a quick data availability check: how many shipments exist, and what does a sample of the delay log actually look like. That's a habit worth keeping even on a familiar dataset, because it catches obvious problems before you build anything on top of them.

Second, a single view, v_supply_chain_visibility, that connects shipment records to their delay events and destination port conditions in one place. Everything downstream reads from this view instead of re-joining the same three tables over and over.

Third, the headline number: what share of shipments are currently delayed. Then the breakdown questions, one at a time. What causes delays most often, and which causes take longest to resolve once they happen. Which destination ports see the most delay activity. Whether port congestion level actually correlates with longer delays. Which specific routes show up repeatedly in the delay log, since a route that keeps failing needs a different response than a one-off weather event. How much weather plays into the average delay. What the delays cost financially, tying operational disruption back to revenue and profit. And finally, delay severity bands, short, medium, and severe, to help prioritize where operations should look first.

## Analysis and error check

This script was in better shape than the other two when I reviewed it, but I still found two things worth fixing.

The first was a missing safeguard. The original script created v_supply_chain_visibility without checking whether it already existed, which means re-running the script on a database where that view was already built would just fail outright. I added a guard so the script can be run more than once without that friction. Small fix, but it's the kind of thing that turns a five-minute re-run into an annoying support ticket if it's missed.

The second was more substantive: the headline delay rate metric was narrower than it looked. The original query measured delay rate purely off shipment_status = 'Delayed'. That's a legitimate number, but it only captures shipments currently sitting in delayed status. A shipment that experienced a real disruption mid-transit and was eventually marked "Delivered" once it finally arrived would never show up in that count, even though it has a complete entry in the delay log. That's not a broken query. It's just a narrower question than "how much of our network has been touched by a disruption," which is usually the question people actually care about. I added a second version of the metric next to the first, built from distinct shipment IDs in the delay log, so both numbers sit side by side and nobody walks away thinking the status-based figure is the whole story.

Everything else held up under review. The joins that use INNER JOIN against delays_events (cause breakdown, port breakdown, route breakdown) are intentionally scoped that way, because those specific questions only make sense for shipments that actually have a recorded delay. And ports.port_name is unique across all 8 ports, so joining shipments to ports on that column doesn't create any duplication risk the way the route table did in the profitability project. I checked that specifically after finding the fan-out problem there, because it's exactly the kind of thing that quietly breaks a second query without anyone noticing.

## Insight

Delay causes were not evenly distributed. Some causes showed up far more often than others but resolved relatively quickly, while a smaller number of causes were rarer but dragged on much longer once they hit, which is exactly the distinction the frequency-versus-duration comparison was built to surface. A handful of destination ports carried a disproportionate share of delay events relative to the rest of the network, and congestion level at those ports lined up with longer average delays closely enough to treat as a real signal rather than coincidence. Certain origin-destination pairs also showed up repeatedly in the delay log rather than as isolated incidents, which points to a structural problem on those specific lanes (scheduling, carrier choice, or routing) rather than bad luck.

## Recommendation

Operations should treat the top few delay causes by duration, not just by frequency, as the priority list, since a rare but long disruption often costs more in downstream service impact than a common but short one. The congested destination ports identified here should get a direct review of berth scheduling or carrier allocation, since congestion and delay length are moving together at those locations. And the routes that show up repeatedly in the delay breakdown deserve a standing review rather than a one-time fix, because a route with a recurring problem will keep generating the same complaint every reporting period until something structural changes.

## Business impact

Disruption that isn't diagnosed just repeats. A shipment marked "Delayed" without a clear reason gets explained away individually, quarter after quarter, and the underlying pattern never gets fixed because nobody connects the dots across shipments. This analysis makes that pattern visible: it turns a pile of individual delay complaints into a short, ranked list of the actual root causes and the specific ports and routes driving them, which is what lets operations fix the recurring problem instead of apologizing for it every time it happens.

## What was done

I built a single visibility layer connecting shipment records, delay events, and port congestion data, then used it to answer the core operational questions: how big is the delay problem, what's causing it, where is it concentrated, and how severe is it. I reviewed the original script for structural issues, found a missing safeguard and a metric that was narrower than intended, and corrected both, while confirming the rest of the join logic was sound against the actual data.

## Tools used and how they helped

Built in SQL using a view for the core join layer, INNER JOIN where the analysis specifically requires a recorded delay event, LEFT JOIN where all shipments need to stay in the picture regardless of delay status, CASE-based severity banding, and aggregate functions for frequency and duration comparisons. The view kept the three-table join logic in one place instead of repeating it across seven different queries, and the two-metric delay rate comparison is a simple example of a broader habit worth having: when a single number could be read two different ways, show both rather than picking one silently.

## Results

The corrected script delivers a complete delay diagnostic: overall delay rate measured two honest ways, delay causes ranked by both frequency and severity, destination ports and specific routes flagged for repeated disruption, a congestion correlation check, weather exposure context, the financial size of the disrupted shipment pool, and a severity classification ready to drive investigation priority. One structural gap (the missing view guard) and one metric scope issue were found and corrected during review, both documented with the reasoning behind the fix.
