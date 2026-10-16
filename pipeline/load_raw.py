"""Load the raw Olist CSV files into a local DuckDB database.

Each CSV becomes one table in the `raw` schema of data/olist.duckdb, loaded as-is
plus two metadata columns (_source_file, _loaded_at). Tables are replaced on every
run, so the load is idempotent.

Usage:
    python pipeline/load_raw.py
"""

import logging
import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"
DB_PATH = PROJECT_ROOT / "data" / "olist.duckdb"
SCHEMA = "raw"

TABLES = {
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

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger(__name__)


def load_table(con: duckdb.DuckDBPyConnection, table: str, file_name: str) -> int:
    """Replace one raw table with the contents of its CSV file and return its row count."""
    csv_path = RAW_DIR / file_name
    con.execute(
        f"""
        CREATE OR REPLACE TABLE {SCHEMA}.{table} AS
        SELECT
            *,
            '{file_name}' AS _source_file,
            current_timestamp AS _loaded_at
        FROM read_csv('{csv_path}', header = true)
        """
    )
    return con.execute(f"SELECT count(*) FROM {SCHEMA}.{table}").fetchone()[0]


def main() -> int:
    missing = [name for name in TABLES.values() if not (RAW_DIR / name).exists()]
    if missing:
        logger.error("Missing CSV files: %s. Run scripts/download_data.py first", ", ".join(missing))
        return 1

    logger.info("Loading %d tables into %s", len(TABLES), DB_PATH)
    try:
        with duckdb.connect(str(DB_PATH)) as con:
            con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
            for table, file_name in TABLES.items():
                rows = load_table(con, table, file_name)
                if rows == 0:
                    logger.error("Table %s.%s is empty", SCHEMA, table)
                    return 1
                logger.info("  %-35s %10s rows", f"{SCHEMA}.{table}", f"{rows:,}")
    except duckdb.Error as error:
        logger.error("Load failed: %s", error)
        return 1

    logger.info("Done: %d tables loaded", len(TABLES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
