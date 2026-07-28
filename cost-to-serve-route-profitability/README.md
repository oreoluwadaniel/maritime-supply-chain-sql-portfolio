# Cost-to-Serve and Route Profitability Analysis

A SQL project that looks at a maritime shipping network and asks a simple question with a complicated answer: are we actually making money on the business we're doing, or just moving a lot of cargo around?

## Business problem

Most shipping companies track revenue closely. Fewer of them track profit at the same level of detail, and that gap causes real damage. A route can look busy and important on a dashboard while quietly losing money on every container that moves through it. A customer can be one of your biggest accounts by revenue and still be a net drag on the business once you subtract what it actually costs to serve them.

This project was built to close that gap for a maritime logistics operation. The company needed to know, at the shipment level, the route level, and the customer level, where money was being made and where it was being given away. Revenue tells you how much business moved through the network. It does not tell you whether that business was worth doing. This analysis is built to answer the second question.

## Data source

The dataset is a simulated maritime shipping operation covering 3,000 shipments across an 8-port network (Shanghai, Rotterdam, Lagos, Los Angeles, Singapore, Dubai, Hamburg, and Durban). It includes several connected tables:

Shipments hold the transactional core: origin, destination, dates, cargo type, weight, volume, revenue, and cost per shipment.

Routes describe the lanes themselves: distance in kilometers, average transit time in days, and fuel cost.

Customers hold company name, industry, country, and contract value for each account.

Fuel data tracks regional fuel prices over time, which matters because fuel is one of the biggest swing costs in ocean freight.

This is realistic, generated data rather than a live company's books, but it's structured the way real shipping data is structured, and it behaves the way real data behaves, including the messy parts. That turned out to matter a lot once I actually started querying it, which I'll get to in the next section.

All source files sit in the [`/data`](../data) folder at the root of this repository.

## Methodology

I approached this in three passes, moving from the whole business down to individual decisions.

First, the baseline. Before splitting anything apart, I pulled total revenue, total cost, and total profit across the entire shipment portfolio. You need that number before any of the more granular breakdowns mean anything.

Second, the three lenses the business actually asked for: routes, customers, and shipments. For routes, I grouped shipments by origin and destination pair and ranked them from least to most profitable, so the worst-performing lanes surface immediately instead of getting buried in a long list. For customers, I did the same thing at the account level. For shipments, I built a simple rules engine that labels each shipment as needing a price increase, needing cost optimization, or being fine as is, based on where its profit lands relative to a $2,000 threshold.

Third, the context layers: cost per kilometer to normalize for route length, transit time against profit to see if slower routes are worth the wait, shipment weight against profit to check for a size-to-margin relationship, and regional fuel price against average shipment cost to see how much of the cost story is coming from something outside the company's control.

I built one reusable view, v_profitability, that joins shipment financials to route characteristics, so most of the later queries could pull from a single clean source instead of repeating the same join logic five times.

## Analysis and error check

This is the part I want to be upfront about, because I didn't just write the queries and call it done. I went back through the script against the actual row counts and key structure in the data, and found four real problems. Two of them were serious enough that they would have changed the numbers a client actually sees.

The first was a join fan-out in the route view. The routes table only covers an 8-port network, which caps the number of possible origin-destination pairs at 64. But the table actually holds 3,000 route records, meaning each pair shows up roughly 47 times on average, each with a slightly different distance, transit time, and fuel cost. The original view joined shipments to routes using just the origin and destination port names. Since that combination isn't unique in the routes table, every shipment matched dozens of route rows at once, and got duplicated in the result set that many times over. Anything built on top of that view, cost per kilometer, transit time versus profit, was quietly inflated. I fixed this by pre-aggregating the routes table down to one averaged row per origin-destination pair before the join ever happens, so each shipment now matches exactly one route record.

The second was in the fuel price comparison. The original query joined fuel price records to shipments by matching on year alone, with no real shared key between a specific fuel record and a specific shipment. That turns the join into something close to a cross join: every fuel price entry for a given year gets matched against every shipment from that same year, regardless of region. Because shipment volume differs from year to year, the resulting "average" ends up weighted toward whichever year happened to contribute more matched rows, not toward a genuine regional average. I fixed this by summarizing fuel prices to one row per region per year, summarizing shipment cost to one row per year, and only then joining those two already-summarized tables together. That keeps the comparison honest.

The third was a grouping mistake in the weight-versus-profit query. Shipment weight is recorded to two decimal places, so grouping directly on weight_tons produced almost one row per shipment. It looked like an aggregation on paper but wasn't actually pooling anything together. I fixed this by bucketing weight into ranges (under 50 tons, 50 to 99, and so on), which is what that kind of analysis is supposed to look like.

The fourth was in how customers were grouped. The customer table has 3,000 rows, but the same company name shows up under many different customer IDs, countries, and contract values. "Toyota Logistics," for example, appears well over 300 times across distinct accounts. Grouping profitability by company name alone would have merged hundreds of separate customer relationships into a single row. I fixed this by grouping on customer ID alongside company name, so the profitability figures reflect actual individual accounts, with the company name kept only as a label.

I also want to flag something I noticed but did not change, because it's a data quality issue rather than a query bug: some shipment records show an arrival date earlier than the departure date, which isn't physically possible. None of the queries in this script calculate duration directly from those two columns, so it doesn't affect anything here, but I'm calling it out because anyone extending this analysis to measure transit time from the raw dates should clean those records first.

## Insight

Once the fixes were in place, the picture that came out was consistent with what I'd expect from a real freight network under commercial pressure, not a uniformly healthy one. A meaningful share of routes were operating at negative or thin margins even while carrying decent shipment volume, which is the exact blind spot revenue-only reporting creates. On the customer side, once accounts were correctly separated by customer ID instead of collapsed by brand name, a similar pattern showed up: some of the largest accounts by shipment count were not the most profitable ones, and a few mid-volume accounts were quietly carrying strong margins without getting much management attention.

The shipment-level action engine also did what it was built to do. Instead of a wall of numbers, it produces a short, ranked list of shipments that need a pricing conversation, a cost review, or nothing at all, which is the kind of output a commercial team can actually act on Monday morning.

## Recommendation

Three things follow directly from this. First, put the loss-making route list in front of whoever owns pricing and carrier contracts, not just operations, because the fix for a losing lane is sometimes commercial and sometimes operational, and you need both sides looking at the same list. Second, run a formal account review on the customer relationships sitting at the bottom of the profit ranking, especially the high-volume ones, before renewal conversations happen rather than after. Third, treat the shipment-level action labels as a weekly operating report, not a one-time analysis, so shipments sliding toward "Increase Price or Cut Cost" get caught early instead of after a quarter of accumulated losses.

## Business impact

This shifts the conversation from "how much did we ship" to "how much did we keep," which is the conversation that actually protects margin. A route or account that looks fine on a revenue report but is losing money on a cost basis is a liability that compounds quietly, and it usually takes a proper cost-to-serve view like this one to catch it before it shows up as a bigger problem in the quarterly numbers. Catching even a handful of consistently loss-making lanes or accounts early, and either repricing or restructuring them, protects real margin that would otherwise leak out unnoticed.

## What was done

I built a single profitability view joining shipment financials to properly aggregated route data, then used it to answer three connected questions: which routes make money, which customers are worth serving, and which individual shipments need attention right now. Along the way, I reviewed every query against the real structure of the data, found four issues ranging from join fan-out to a meaningless grouping key, corrected all four, and documented exactly what was wrong and why, rather than quietly fixing them and moving on.

## Tools used and how they helped

This was built entirely in SQL, using views, common table expressions, CASE-based classification logic, aggregate functions, and NULLIF to guard against division by zero in the cost-per-kilometer calculation. Views did the heavy lifting of keeping the logic reusable: instead of re-writing the shipment-to-route join five separate times, v_profitability holds it once, correctly aggregated, and every downstream query pulls from that single source of truth. Common table expressions were the fix for the fuel price problem specifically, because they let me summarize each side of a comparison independently before combining them, which is the only way to join two tables on a shared time period without one side multiplying the other.

## Results

The corrected script produces a complete profitability picture across three levels of granularity: the whole shipment portfolio, every route lane ranked from worst to best, and every customer account ranked the same way, plus a shipment-level action list ready for a commercial or operations team to work from directly. Four real logic issues were found during review and corrected before delivery, each one documented with the reasoning behind the fix, so the numbers in this version can be trusted rather than just trusted because they came out of a script.
