"""Run data quality checks on the silver layer.

Each check is a SQL query that counts the rows breaking a rule. A check passes when
the count is 0. If any check fails, the script exits with code 1 so the pipeline stops.

Usage:
    python pipeline/check_quality.py
"""

import logging
import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "data" / "olist.duckdb"

CHECKS = {
    "orders: order_id is unique":
        "SELECT count(*) - count(DISTINCT order_id) FROM silver.orders",
    "products: product_id is unique":
        "SELECT count(*) - count(DISTINCT product_id) FROM silver.products",
    "customers: customer_id is unique":
        "SELECT count(*) - count(DISTINCT customer_id) FROM silver.customers",
    "sellers: seller_id is unique":
        "SELECT count(*) - count(DISTINCT seller_id) FROM silver.sellers",
    "geolocation: one row per zip code":
        "SELECT count(*) - count(DISTINCT zip_code_prefix) FROM silver.geolocation",
    "order_reviews: review_id + order_id is unique":
        "SELECT count(*) - count(DISTINCT (review_id, order_id)) FROM silver.order_reviews",
    "order_items: every order exists":
        "SELECT count(*) FROM silver.order_items WHERE order_id NOT IN (SELECT order_id FROM silver.orders)",
    "order_items: every product exists":
        "SELECT count(*) FROM silver.order_items WHERE product_id NOT IN (SELECT product_id FROM silver.products)",
    "orders: every customer exists":
        "SELECT count(*) FROM silver.orders WHERE customer_id NOT IN (SELECT customer_id FROM silver.customers)",
    "products: category is never empty":
        "SELECT count(*) FROM silver.products WHERE category_name IS NULL",
    "orders: no delivery before purchase":
        "SELECT count(*) FROM silver.orders WHERE delivered_to_customer_at < purchased_at",
    "order_items: no zero or negative prices":
        "SELECT count(*) FROM silver.order_items WHERE price <= 0 OR freight_value < 0",
    "order_reviews: score between 1 and 5":
        "SELECT count(*) FROM silver.order_reviews WHERE review_score NOT BETWEEN 1 AND 5",
}

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger(__name__)


def main() -> int:
    if not DB_PATH.exists():
        logger.error("Database not found at %s. Run the pipeline first", DB_PATH)
        return 1

    failed = 0
    try:
        with duckdb.connect(str(DB_PATH), read_only=True) as con:
            for name, query in CHECKS.items():
                bad_rows = con.execute(query).fetchone()[0]
                if bad_rows == 0:
                    logger.info("  PASS  %s", name)
                else:
                    logger.error("  FAIL  %s (%s rows)", name, f"{bad_rows:,}")
                    failed += 1
    except duckdb.Error as error:
        logger.error("Quality checks could not run: %s", error)
        return 1

    if failed:
        logger.error("%d of %d checks failed", failed, len(CHECKS))
        return 1
    logger.info("All %d checks passed", len(CHECKS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
