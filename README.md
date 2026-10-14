# What makes grocery customers reorder?

Online grocery apps like Blinkit, Zepto and Instamart live or die on repeat orders, so I wanted to see what repeat buying looks like at scale. I loaded the Instacart dataset (3.4 million orders, 33.8 million order lines, 206k customers) into MySQL and answered a set of questions with SQL: when people order, how often they come back, what they reorder, and what they buy together.

Data: [Instacart Market Basket Analysis](https://www.kaggle.com/datasets/psparks/instacart-market-basket-analysis) on Kaggle. It has no prices or dates, only the order sequence for each customer and the number of days between orders.

## Findings

59% of everything people buy is something they've bought before. The average basket has 10 items.

Most customers are on a weekly or fortnightly routine. The most common gap between orders is exactly 7 days (10% of all repeat orders), with smaller bumps at 14, 21 and 28 days. 11.5% of orders sit at 30 days, but that's where the dataset caps the value, so it really means "30 or more".

A small group of customers drives a big share of orders.

| Shopper type | Customers | Share of orders | Reorder rate |
|---|---|---|---|
| Weekly | 12.4% | 29.6% | 58% |
| Fortnightly | 34.0% | 41.6% | 51% |
| Every 3 weeks | 30.8% | 19.9% | 40% |
| Monthly or less | 22.8% | 8.8% | 32% |

A tiny part of the catalogue does most of the volume. 790 products (1.6% of the 49,685 that sold) account for half of all items ordered, and 4,558 (9%) account for 80%.

Fresh food and dairy are the habit categories. Produce is 29% of all items and dairy and eggs another 17%. Both are reordered about two-thirds of the time. Pantry (35%) and personal care (32%) have the lowest reorder rates. People stock up on those rather than buying them every week.

| Department | Share of items | Reorder rate |
|---|---|---|
| Produce | 29.2% | 65% |
| Dairy & eggs | 16.7% | 67% |
| Snacks | 8.9% | 57% |
| Beverages | 8.3% | 65% |
| Frozen | 6.9% | 54% |
| Pantry | 5.8% | 35% |

Bananas are the top product, ordered 491k times with an 84.5% reorder rate. Among products with at least 5,000 orders, the highest reorder rates are almost all milk (83–86%).

What goes in the cart first is what people come back for. Items added first are reorders 68% of the time. By the 20th item and beyond it drops to 46%, which looks like people adding their staples first and then browsing.

Organic items get reordered more: 63.5% vs 56.9% for non-organic. Organic products make up 31.5% of all items.

Some products are clearly bought together. I worked out lift for pairs among the top 100 products. Lift is how much more often two products appear in the same order than you'd expect if they were unrelated.

| Product A | Product B | Orders together | Lift |
|---|---|---|---|
| Sparkling Lemon Water | Lime Sparkling Water | 8,874 | 17.9 |
| Lime Sparkling Water | Sparkling Water Grapefruit | 13,789 | 12.0 |
| Jalapeno Peppers | Bunched Cilantro | 6,034 | 9.6 |
| Orange Bell Pepper | Red Peppers | 5,529 | 7.7 |
| Organic Garlic | Organic Ginger Root | 11,236 | 6.1 |

People buy sparkling water as a mixed pack of flavours, and the salsa/guacamole ingredients (jalapeño, cilantro, limes, red onion) keep showing up together.

Timing: day 0 and day 1 are the busiest (17–18% of orders each, compared with about 13% on the other days). Instacart doesn't say which weekday 0 is, but it's usually read as Sunday. Most orders come in between 9am and 4pm.

## What I'd suggest to a grocery app

- Put the effort into the fortnightly and 3-week shoppers. They're 65% of customers. Moving some of them to a weekly routine (reminders timed to their usual gap, a "reorder your usual" button) is worth more than chasing the monthly group.
- Build the home screen around reorders. Six in ten items are repeats, and the first items in the cart are the most predictable.
- Bundle the obvious pairs: sparkling water variety packs, a salsa kit, a stir-fry kit (garlic + ginger + peppers).
- Keep stock tight on the ~800 products that make up half of all volume. Running out of those hurts the most.

## How it's built

- `schema.sql` creates the database and loads the CSVs. `products.csv` escapes quotes in an unusual way (`9\""x13\""`), which made MySQL silently drop 333 products on the first load. It loads with `ESCAPED BY ''` and a `REPLACE` to fix the names.
- `analysis.sql` has all the queries. Joining 33.8M order lines to products for every question was taking several minutes per query, so I aggregate the big table once into `product_stats` and `order_stats` and run most questions on those instead. The whole file now runs in about 13 minutes on a laptop, compared with around 30 minutes for just six queries before.
- I used CTEs, window functions (`ROW_NUMBER`, running `SUM() OVER` for the cumulative share, `SUM(COUNT(*)) OVER ()` for percentages), self-joins for product pairs, and `CASE` for customer segments.

There is also a short write-up in [`grocery_reorder_report.pdf`](grocery_reorder_report.pdf).

## Limitations

- Instacart only included customers with 4 to 100 orders, so one-time buyers aren't in the data. The real reorder rate across all customers would be lower.
- There are no prices, so I can't say anything about revenue, only volume.
- The dataset is from 2017 and US-based, so the patterns won't map exactly onto Indian quick commerce.

## Running it

1. Download the CSVs from Kaggle into a `data/` folder.
2. Run `schema.sql`, then `analysis.sql`, in MySQL 8 with `local_infile` turned on:
```
mysql -u root -p --local-infile=1 < schema.sql
mysql -u root -p < analysis.sql
```

Tools: MySQL 8.4
