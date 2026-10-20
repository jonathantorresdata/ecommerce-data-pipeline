-- What is a "customer"? customer_id is one per ORDER (99,441 = number of orders).
-- The real person is customer_unique_id: 96,096 people → ~3,345 orders come from repeat customers.
-- Use customer_unique_id to count customers or repeat purchases.
SELECT
    count(*) AS total_rows,
    count(DISTINCT customer_id) AS customer_ids,
    count(DISTINCT customer_unique_id) AS unique_customers
FROM raw.customers;
