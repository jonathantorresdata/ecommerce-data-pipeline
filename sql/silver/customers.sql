-- One row per customer record. customer_id is one per order; the real person is customer_unique_id.
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_code_prefix,
    customer_city AS city,
    customer_state AS state
FROM raw.customers;
