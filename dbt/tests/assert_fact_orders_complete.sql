-- After the incremental merge, fact_orders must hold every visible order exactly once.
SELECT 1
FROM (SELECT count(*) AS n, count(DISTINCT order_id) AS d FROM {{ ref('fact_orders') }}) AS f
CROSS JOIN (SELECT count(*) AS n FROM {{ ref('orders') }}) AS s
WHERE f.n <> s.n OR f.d <> f.n
