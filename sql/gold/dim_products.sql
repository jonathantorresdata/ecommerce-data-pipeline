-- One row per product: what was sold.
SELECT
    product_id,
    category_name,
    category_name_english,
    product_photos,
    weight_g,
    length_cm,
    height_cm,
    width_cm
FROM silver.products;
