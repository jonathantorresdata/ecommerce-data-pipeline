-- Overview of the raw layer: which tables exist and how big they are
SELECT table_name, estimated_size AS approx_rows, column_count
FROM duckdb_tables()
WHERE schema_name = 'raw'
ORDER BY estimated_size DESC;

-- Columns and data types of the central table
DESCRIBE raw.orders;

-- A first look at the data
SELECT *
FROM raw.orders
LIMIT 5;
