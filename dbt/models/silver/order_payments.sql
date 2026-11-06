-- One row per payment of a visible order (an order can be paid in several payments).
SELECT
    p.order_id,
    p.payment_sequential AS payment_number,
    p.payment_type,
    p.payment_installments AS installments,
    p.payment_value
FROM {{ source('bronze', 'order_payments') }} AS p
WHERE p.order_id IN (SELECT order_id FROM {{ ref('orders') }})
