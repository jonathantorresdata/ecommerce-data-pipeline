-- One row per calendar day, covering every date in the data (full years).
SELECT
    CAST(day AS DATE) AS date_day,
    year(day) AS year,
    quarter(day) AS quarter,
    month(day) AS month,
    monthname(day) AS month_name,
    day(day) AS day_of_month,
    isodow(day) AS day_of_week,
    dayname(day) AS day_name,
    isodow(day) IN (6, 7) AS is_weekend
FROM range(DATE '2016-01-01', DATE '2019-01-01', INTERVAL 1 DAY) AS calendar(day);
