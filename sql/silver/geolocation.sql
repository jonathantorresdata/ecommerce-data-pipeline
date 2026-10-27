-- One row per zip code prefix: average coordinates, most frequent city and state.
-- 42 raw coordinates fall outside Brazil; they are ignored in the average.
SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    avg(geolocation_lat) FILTER (WHERE geolocation_lat BETWEEN -34 AND 6
                                   AND geolocation_lng BETWEEN -74 AND -34) AS latitude,
    avg(geolocation_lng) FILTER (WHERE geolocation_lat BETWEEN -34 AND 6
                                   AND geolocation_lng BETWEEN -74 AND -34) AS longitude,
    mode(geolocation_city) AS city,
    mode(geolocation_state) AS state
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;
