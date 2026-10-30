"""Run data quality checks on the silver and gold layers.

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
    "gold dim_customers: one row per person":
        "SELECT count(*) - count(DISTINCT customer_unique_id) FROM gold.dim_customers",
    "gold fact_orders: one row per order":
        "SELECT count(*) - count(DISTINCT order_id) FROM gold.fact_orders",
    "gold fact_order_items: same rows as silver (join did not multiply)":
        "SELECT (SELECT count(*) FROM gold.fact_order_items) - (SELECT count(*) FROM silver.order_items)",
    "gold fact_order_items: every product exists in dim_products":
        "SELECT count(*) FROM gold.fact_order_items WHERE product_id NOT IN (SELECT product_id FROM gold.dim_products)",
    "gold fact_order_items: every seller exists in dim_sellers":
        "SELECT count(*) FROM gold.fact_order_items WHERE seller_id NOT IN (SELECT seller_id FROM gold.dim_sellers)",
    "gold fact_order_items: every customer exists in dim_customers":
        "SELECT count(*) FROM gold.fact_order_items WHERE customer_unique_id NOT IN (SELECT customer_unique_id FROM gold.dim_customers)",
    "gold fact_orders: every purchase date exists in dim_date":
        "SELECT count(*) FROM gold.fact_orders WHERE purchase_date NOT IN (SELECT date_day FROM gold.dim_date)",
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
