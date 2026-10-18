-- Date range: when was the first order placed, and when the last one?
SELECT
    min(order_purchase_timestamp) AS first_order,
    max(order_purchase_timestamp) AS last_order
FROM raw.orders;
