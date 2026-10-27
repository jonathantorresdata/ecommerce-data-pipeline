-- Evidence for each decision in docs/data_quality_decisions.md

-- 1. geolocation: ~52 rows per zip code → deduplicate before joining
SELECT
    count(*) AS total_rows,
    count(DISTINCT geolocation_zip_code_prefix) AS zip_codes,
    count(*) / count(DISTINCT geolocation_zip_code_prefix) AS rows_per_zip
FROM raw.geolocation;

-- 2. order_reviews: review_id repeats, but review_id + order_id is unique → not duplicates
SELECT
    count(*) AS total_rows,
    count(DISTINCT review_id) AS review_ids,
    count(DISTINCT (review_id, order_id)) AS review_order_pairs
FROM raw.order_reviews;

-- 5. products without category (610)
SELECT
    count(*) AS total_products,
    count(*) - count(product_category_name) AS products_without_category
FROM raw.products;

-- 6. categories without English translation (2)
SELECT DISTINCT product_category_name
FROM raw.products
WHERE product_category_name IS NOT NULL
  AND product_category_name NOT IN (
      SELECT product_category_name FROM raw.category_translation
  );

-- Sanity checks: impossible dates and prices (expected 0)
SELECT count(*) AS delivered_before_purchase
FROM raw.orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

SELECT count(*) AS bad_prices
FROM raw.order_items
WHERE price <= 0 OR freight_value < 0;
