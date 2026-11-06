-- One row per seller, with the coordinates of their zip code (for maps).
SELECT
    s.seller_id,
    s.zip_code_prefix,
    s.city,
    s.state,
    g.latitude,
    g.longitude
FROM {{ ref('sellers') }} AS s
LEFT JOIN {{ ref('geolocation') }} AS g
    ON s.zip_code_prefix = g.zip_code_prefix
