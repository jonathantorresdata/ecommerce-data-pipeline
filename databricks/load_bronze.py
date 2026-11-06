# Databricks notebook source
# Load the raw Olist CSV files from the data lake into the bronze schema of Unity
# Catalog, as-is plus two lineage columns (_source_file, _loaded_at).
#
# First task of the "live-store" job (see infra/main.tf); dbt builds silver and
# gold afterwards. Every table is created with CREATE OR REPLACE, so it is idempotent.

dbutils.widgets.text("catalog", "olist")
dbutils.widgets.text("bronze_url", "")

CATALOG = dbutils.widgets.get("catalog")
BRONZE_URL = dbutils.widgets.get("bronze_url")

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


spark.sql(f"USE CATALOG {CATALOG}")

for table, file_name in FILES.items():
    rows = load_bronze(table, file_name)
    if rows == 0:
        raise ValueError(f"Table bronze.{table} is empty")
    print(f"bronze.{table:<30} {rows:>10,} rows")
