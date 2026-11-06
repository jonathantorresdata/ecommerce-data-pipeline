-- One row per customer record of a visible order. customer_id is one per order;
-- the real person is customer_unique_id.
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix AS zip_code_prefix,
    c.customer_city AS city,
    c.customer_state AS state
FROM {{ source('bronze', 'customers') }} AS c
WHERE c.customer_id IN (SELECT customer_id FROM {{ ref('orders') }})
