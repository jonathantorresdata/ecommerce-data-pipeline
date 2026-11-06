-- The live store must never show an order that has not been placed yet.
SELECT order_id
FROM {{ ref('orders') }}
WHERE purchased_at > {{ as_of() }}
