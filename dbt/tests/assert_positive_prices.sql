SELECT order_id, item_number
FROM {{ ref('order_items') }}
WHERE price <= 0 OR freight_value < 0
