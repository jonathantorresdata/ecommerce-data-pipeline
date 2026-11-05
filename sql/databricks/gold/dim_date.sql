-- Databricks version of sql/gold/dim_date.sql (DuckDB's range() and isodow() do not exist in Spark SQL).
-- One row per calendar day, covering every date in the data (full years).
SELECT
    day AS date_day,
    year(day) AS year,
    quarter(day) AS quarter,
    month(day) AS month,
    date_format(day, 'MMMM') AS month_name,
    day(day) AS day_of_month,
    weekday(day) + 1 AS day_of_week,
    date_format(day, 'EEEE') AS day_name,
    weekday(day) >= 5 AS is_weekend
FROM (SELECT explode(sequence(DATE '2016-01-01', DATE '2018-12-31', INTERVAL 1 DAY)) AS day);
