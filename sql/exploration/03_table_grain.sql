-- Grain check: what does one row represent in each table?

-- orders: total rows = unique order_id → one row per order
SELECT
    count(*) AS total_rows,
    count(DISTINCT order_id) AS unique_orders
FROM raw.orders;

-- order_items: more rows than unique orders → one row per product within an order
SELECT
    count(*) AS total_rows,
    count(DISTINCT order_id) AS unique_orders
FROM raw.order_items;

-- Orders with the most items
SELECT
    order_id,
    count(*) AS items
FROM raw.order_items
GROUP BY order_id
ORDER BY items DESC
LIMIT 3;
