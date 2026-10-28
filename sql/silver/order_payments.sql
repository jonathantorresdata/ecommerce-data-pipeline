-- One row per payment of an order (an order can be paid in several payments).
SELECT
    order_id,
    payment_sequential AS payment_number,
    payment_type,
    payment_installments AS installments,
    payment_value
FROM raw.order_payments;
