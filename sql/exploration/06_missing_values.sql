-- Missing values in order dates: they grow along the order lifecycle (160 → 1,783 → 2,965)
-- because canceled or in-transit orders stop at an earlier stage.
-- The net difference (2,965 missing vs 2,963 not delivered) hides two issues: 8 'delivered' orders without delivery date and 6 'canceled' orders with one. See silver/orders flags.
SELECT
    count(*) AS total_orders,
    count(*) - count(order_approved_at) AS missing_approved,
    count(*) - count(order_delivered_carrier_date) AS missing_carrier,
    count(*) - count(order_delivered_customer_date) AS missing_delivered
FROM raw.orders;
