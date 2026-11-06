# Databricks notebook source
# Build the lakehouse in Unity Catalog: bronze tables from the raw CSV files in the
# data lake, then the silver and gold layers from the SQL files in sql/.
#
# Runs as the Databricks job "build-lakehouse" (see infra/main.tf). Every table is
# created with CREATE OR REPLACE, so the build is idempotent.

import re
from pathlib import Path

dbutils.widgets.text("catalog", "olist")
dbutils.widgets.text("bronze_url", "")
dbutils.widgets.text("sql_dir", "")

CATALOG = dbutils.widgets.get("catalog")
BRONZE_URL = dbutils.widgets.get("bronze_url")
SQL_DIR = Path(dbutils.widgets.get("sql_dir"))

FILES = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}


def load_bronze(table: str, file_name: str) -> int:
    """Replace one bronze table with the contents of its CSV file and return its row count."""
    spark.sql(f"""
        CREATE OR REPLACE TABLE bronze.{table} AS
        SELECT
            *,
            _metadata.file_name AS _source_file,
            current_timestamp() AS _loaded_at
        FROM read_files(
            '{BRONZE_URL}olist/{file_name}',
            format => 'csv', header => true, multiLine => true, escape => '"'
        )
    """)
    return spark.table(f"bronze.{table}").count()


def build_table(layer: str, sql_file: Path) -> int:
    """Create or replace one table from its SQL file and return its row count.

    A file in sql/databricks/<layer>/ replaces the shared one when the DuckDB SQL
    does not run on Spark, and the local raw schema is called bronze here.
    """
    override = SQL_DIR / "databricks" / layer / sql_file.name
    select = (override if override.exists() else sql_file).read_text()
    select = re.sub(r"\braw\.", "bronze.", select).strip().rstrip(";")
    spark.sql(f"CREATE OR REPLACE TABLE {layer}.{sql_file.stem} AS\n{select}")
    return spark.table(f"{layer}.{sql_file.stem}").count()


spark.sql(f"USE CATALOG {CATALOG}")

for table, file_name in FILES.items():
    rows = load_bronze(table, file_name)
    print(f"bronze.{table:<30} {rows:>10,} rows")

for layer in ("silver", "gold"):
    for sql_file in sorted((SQL_DIR / layer).glob("*.sql")):
        rows = build_table(layer, sql_file)
        if rows == 0:
            raise ValueError(f"Table {layer}.{sql_file.stem} is empty")
        print(f"{layer}.{sql_file.stem:<30} {rows:>10,} rows")
