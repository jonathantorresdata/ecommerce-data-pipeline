-- One row per product within a visible order.
SELECT
    i.order_id,
    i.order_item_id AS item_number,
    i.product_id,
    i.seller_id,
    {{ replay('i.shipping_limit_date') }} AS shipping_limit_at,
    i.price,
    i.freight_value
FROM {{ source('bronze', 'order_items') }} AS i
WHERE i.order_id IN (SELECT order_id FROM {{ ref('orders') }})
