-- Orders per month: how are orders distributed over time?
-- First (2016-09) and last months (2018-09, 2018-10) are almost empty and 2016-11 has no orders.
-- Peak in 2017-11 (Black Friday). Complete months: 2017-01 to 2018-08.
SELECT
    date_trunc('month', order_purchase_timestamp) AS month,
    count(*) AS orders
FROM raw.orders
GROUP BY month
ORDER BY month;
