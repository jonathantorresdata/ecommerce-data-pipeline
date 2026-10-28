-- One row per order, with clearer column names and quality flags (no order is removed).
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp AS purchased_at,
    order_approved_at AS approved_at,
    order_delivered_carrier_date AS delivered_to_carrier_at,
    order_delivered_customer_date AS delivered_to_customer_at,
    order_estimated_delivery_date AS estimated_delivery_at,
    order_id IN (SELECT order_id FROM raw.order_items) AS has_items,
    (order_status = 'delivered' AND order_delivered_customer_date IS NULL) AS is_missing_delivery_date,
    (order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL) AS is_canceled_but_delivered
FROM raw.orders;
