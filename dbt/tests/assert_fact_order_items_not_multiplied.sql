-- The joins in fact_order_items must not add or lose rows.
SELECT 1
FROM (SELECT count(*) AS n FROM {{ ref('fact_order_items') }}) AS f
CROSS JOIN (SELECT count(*) AS n FROM {{ ref('order_items') }}) AS s
WHERE f.n <> s.n
