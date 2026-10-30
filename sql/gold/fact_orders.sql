-- One row per order: totals, delivery times and review score.
-- Items, payments and reviews have several rows per order, so each one is
-- aggregated to one row per order BEFORE joining (to avoid multiplying rows).
WITH items AS (
    SELECT
        order_id,
        count(*) AS item_count,
        sum(price) AS items_value,
        sum(freight_value) AS freight_value
    FROM silver.order_items
    GROUP BY order_id
),
payments AS (
    SELECT
        order_id,
        sum(payment_value) AS payment_value
    FROM silver.order_payments
    GROUP BY order_id
),
reviews AS (
    SELECT
        order_id,
        avg(review_score) AS review_score
    FROM silver.order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    CAST(o.purchased_at AS DATE) AS purchase_date,
    o.order_status,
    coalesce(i.item_count, 0) AS item_count,
    i.items_value,
    i.freight_value,
    p.payment_value,
    date_diff('day', o.purchased_at, o.delivered_to_customer_at) AS delivery_days,
    date_diff('day', o.estimated_delivery_at, o.delivered_to_customer_at) AS delay_days,
    o.delivered_to_customer_at > o.estimated_delivery_at AS is_late,
    r.review_score,
    o.is_missing_delivery_date,
    o.is_canceled_but_delivered
FROM silver.orders AS o
LEFT JOIN silver.customers AS c ON o.customer_id = c.customer_id
LEFT JOIN items AS i ON o.order_id = i.order_id
LEFT JOIN payments AS p ON o.order_id = p.order_id
LEFT JOIN reviews AS r ON o.order_id = r.order_id;
