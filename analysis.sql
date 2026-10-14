USE instacart;

DROP TABLE IF EXISTS product_stats, order_stats, top_items;

CREATE TABLE product_stats (PRIMARY KEY (product_id))
SELECT product_id, COUNT(*) AS times_ordered, SUM(reordered) AS reorders, SUM(add_to_cart_order = 1) AS first_in_cart
FROM order_products
GROUP BY product_id;

CREATE TABLE order_stats (PRIMARY KEY (order_id))
SELECT order_id, COUNT(*) AS items, SUM(reordered) AS reorders
FROM order_products
GROUP BY order_id;


SELECT
    (SELECT COUNT(DISTINCT user_id) FROM orders) AS customers,
    COUNT(*) AS orders,
    SUM(items) AS items,
    ROUND(AVG(items), 1) AS avg_basket,
    ROUND(SUM(reorders) / SUM(items), 3) AS reorder_rate
FROM order_stats;


SELECT order_dow, COUNT(*) AS orders, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders
GROUP BY order_dow
ORDER BY order_dow;

SELECT order_hour, COUNT(*) AS orders, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders
GROUP BY order_hour
ORDER BY order_hour;


SELECT days_since_prior, COUNT(*) AS orders, ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders
WHERE days_since_prior IS NOT NULL
GROUP BY days_since_prior
ORDER BY days_since_prior;


SELECT
    d.department,
    SUM(s.times_ordered) AS items,
    ROUND(100 * SUM(s.times_ordered) / SUM(SUM(s.times_ordered)) OVER (), 1) AS pct_of_items,
    ROUND(SUM(s.reorders) / SUM(s.times_ordered), 3) AS reorder_rate
FROM product_stats s
JOIN products p USING (product_id)
JOIN departments d USING (department_id)
GROUP BY d.department
ORDER BY items DESC;


SELECT p.product_name, s.times_ordered, ROUND(s.reorders / s.times_ordered, 3) AS reorder_rate
FROM product_stats s
JOIN products p USING (product_id)
ORDER BY s.times_ordered DESC
LIMIT 10;

SELECT p.product_name, s.times_ordered, ROUND(s.reorders / s.times_ordered, 3) AS reorder_rate
FROM product_stats s
JOIN products p USING (product_id)
WHERE s.times_ordered >= 5000
ORDER BY reorder_rate DESC
LIMIT 10;

WITH ranked AS (
    SELECT d.department, p.product_name, s.times_ordered,
           ROW_NUMBER() OVER (PARTITION BY d.department ORDER BY s.times_ordered DESC) AS rn
    FROM product_stats s
    JOIN products p USING (product_id)
    JOIN departments d USING (department_id)
)
SELECT department, product_name, times_ordered
FROM ranked
WHERE rn = 1
ORDER BY times_ordered DESC;


WITH running AS (
    SELECT times_ordered,
           ROW_NUMBER() OVER (ORDER BY times_ordered DESC) AS product_rank,
           SUM(times_ordered) OVER (ORDER BY times_ordered DESC, product_id) / SUM(times_ordered) OVER () AS cum_share
    FROM product_stats
)
SELECT
    MIN(CASE WHEN cum_share >= 0.5 THEN product_rank END) AS products_for_50pct,
    MIN(CASE WHEN cum_share >= 0.8 THEN product_rank END) AS products_for_80pct,
    COUNT(*) AS products_sold
FROM running;


SELECT LEAST(add_to_cart_order, 20) AS cart_position, COUNT(*) AS items, ROUND(AVG(reordered), 3) AS reorder_rate
FROM order_products
GROUP BY cart_position
ORDER BY cart_position;


SELECT
    IF(p.product_name LIKE '%organic%', 'organic', 'non-organic') AS type,
    SUM(s.times_ordered) AS items,
    ROUND(SUM(s.reorders) / SUM(s.times_ordered), 3) AS reorder_rate
FROM product_stats s
JOIN products p USING (product_id)
GROUP BY type;


WITH customers AS (
    SELECT o.user_id,
           MAX(o.order_number) AS orders,
           AVG(o.days_since_prior) AS avg_gap,
           SUM(s.reorders) / SUM(s.items) AS reorder_rate
    FROM orders o
    JOIN order_stats s USING (order_id)
    GROUP BY o.user_id
)
SELECT
    CASE WHEN avg_gap <= 7 THEN 'weekly'
         WHEN avg_gap <= 14 THEN 'fortnightly'
         WHEN avg_gap <= 21 THEN 'every 3 weeks'
         ELSE 'monthly or less' END AS shopper_type,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
    ROUND(100 * SUM(orders) / SUM(SUM(orders)) OVER (), 1) AS pct_orders,
    ROUND(AVG(reorder_rate), 3) AS reorder_rate
FROM customers
GROUP BY shopper_type
ORDER BY MIN(avg_gap);


CREATE TABLE top_items (PRIMARY KEY (order_id, product_id))
SELECT op.order_id, op.product_id
FROM order_products op
JOIN (SELECT product_id FROM product_stats ORDER BY times_ordered DESC LIMIT 100) t USING (product_id);

SET @orders = (SELECT COUNT(*) FROM order_stats);

WITH pairs AS (
    SELECT a.product_id AS p1, b.product_id AS p2, COUNT(*) AS together
    FROM top_items a
    JOIN top_items b ON a.order_id = b.order_id AND a.product_id < b.product_id
    GROUP BY a.product_id, b.product_id
)
SELECT n1.product_name AS product_a, n2.product_name AS product_b, pairs.together,
       ROUND(pairs.together * @orders / (s1.times_ordered * s2.times_ordered), 1) AS lift
FROM pairs
JOIN product_stats s1 ON s1.product_id = pairs.p1
JOIN product_stats s2 ON s2.product_id = pairs.p2
JOIN products n1 ON n1.product_id = pairs.p1
JOIN products n2 ON n2.product_id = pairs.p2
WHERE pairs.together >= 1000
ORDER BY lift DESC
LIMIT 15;
