-- One row per product. Category 'unknown' when missing; English name from the
-- translation table, falling back to the Portuguese name when there is no translation.
SELECT
    p.product_id,
    coalesce(p.product_category_name, 'unknown') AS category_name,
    coalesce(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name_english,
    p.product_name_lenght AS product_name_length,
    p.product_description_lenght AS product_description_length,
    p.product_photos_qty AS product_photos,
    p.product_weight_g AS weight_g,
    p.product_length_cm AS length_cm,
    p.product_height_cm AS height_cm,
    p.product_width_cm AS width_cm
FROM raw.products AS p
LEFT JOIN raw.category_translation AS t
    ON p.product_category_name = t.product_category_name;
