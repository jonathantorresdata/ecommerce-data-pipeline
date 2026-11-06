-- One row per calendar day of the replayed store (full years, including future
-- estimated delivery dates).
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
FROM (SELECT explode(sequence(DATE '2025-01-01', DATE '2027-12-31', INTERVAL 1 DAY)) AS day)
