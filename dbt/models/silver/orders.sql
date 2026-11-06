-- One row per order visible at the replay moment, with timestamps moved to the
-- replayed calendar. Events that have not happened yet are NULL and the status
-- follows them (an order delivered "next week" is still shipped today).
-- Quality flags are computed on the original data, so no order is removed.
WITH replayed AS (
    SELECT
        order_id,
        customer_id,
        order_status AS original_status,
        {{ replay('order_purchase_timestamp') }} AS purchased_at,
        {{ replay('order_approved_at') }} AS approved_at,
        {{ replay('order_delivered_carrier_date') }} AS delivered_to_carrier_at,
        {{ replay('order_delivered_customer_date') }} AS delivered_to_customer_at,
        {{ replay('order_estimated_delivery_date') }} AS estimated_delivery_at,
        (order_status = 'delivered' AND order_delivered_customer_date IS NULL) AS is_missing_delivery_date,
        (order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL) AS is_canceled_but_delivered
    FROM {{ source('bronze', 'orders') }}
),

order_with_items AS (
    SELECT DISTINCT order_id FROM {{ source('bronze', 'order_items') }}
)

SELECT
    r.order_id,
    r.customer_id,
    CASE
        WHEN r.original_status = 'delivered'
             AND NOT r.is_missing_delivery_date
             AND NOT coalesce(r.delivered_to_customer_at <= {{ as_of() }}, false)
            THEN CASE WHEN coalesce(r.delivered_to_carrier_at <= {{ as_of() }}, false)
                      THEN 'shipped' ELSE 'processing' END
        WHEN r.original_status = 'shipped'
             AND NOT coalesce(r.delivered_to_carrier_at <= {{ as_of() }}, false)
            THEN 'processing'
        ELSE r.original_status
    END AS order_status,
    r.purchased_at,
    {{ visible('r.approved_at') }} AS approved_at,
    {{ visible('r.delivered_to_carrier_at') }} AS delivered_to_carrier_at,
    {{ visible('r.delivered_to_customer_at') }} AS delivered_to_customer_at,
    r.estimated_delivery_at,
    greatest(
        r.purchased_at,
        {{ visible('r.approved_at') }},
        {{ visible('r.delivered_to_carrier_at') }},
        {{ visible('r.delivered_to_customer_at') }}
    ) AS updated_at,
    i.order_id IS NOT NULL AS has_items,
    r.is_missing_delivery_date,
    r.is_canceled_but_delivered
FROM replayed AS r
LEFT JOIN order_with_items AS i
    ON r.order_id = i.order_id
WHERE r.purchased_at <= {{ as_of() }}
