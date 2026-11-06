SELECT order_id
FROM {{ ref('orders') }}
WHERE delivered_to_customer_at < purchased_at
