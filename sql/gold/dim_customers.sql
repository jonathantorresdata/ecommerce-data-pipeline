-- One row per real person (customer_unique_id), with the address of their latest order.
WITH ranked AS (
    SELECT
        c.customer_unique_id,
        c.zip_code_prefix,
        c.city,
        c.state,
        row_number() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.purchased_at DESC, c.customer_id
        ) AS order_rank
    FROM silver.customers AS c
    LEFT JOIN silver.orders AS o
        ON c.customer_id = o.customer_id
)
SELECT
    customer_unique_id,
    zip_code_prefix,
    city,
    state
FROM ranked
WHERE order_rank = 1;
