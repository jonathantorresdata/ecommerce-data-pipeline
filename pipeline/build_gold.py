"""Build the gold layer (star schema): one table per SQL file in sql/gold/.

Each file contains a SELECT statement. The script runs it as
CREATE OR REPLACE TABLE gold.<file name> AS <select>, so the build is idempotent.

Usage:
    python pipeline/build_gold.py
"""

import logging
import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "data" / "olist.duckdb"
SQL_DIR = PROJECT_ROOT / "sql" / "gold"
SCHEMA = "gold"

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger(__name__)


def build_table(con: duckdb.DuckDBPyConnection, sql_file: Path) -> int:
    """Create or replace one gold table from its SQL file and return its row count."""
    table = sql_file.stem
    select = sql_file.read_text().strip().rstrip(";")
    con.execute(f"CREATE OR REPLACE TABLE {SCHEMA}.{table} AS\n{select}")
    return con.execute(f"SELECT count(*) FROM {SCHEMA}.{table}").fetchone()[0]


def main() -> int:
    if not DB_PATH.exists():
        logger.error("Database not found at %s. Run pipeline/build_silver.py first", DB_PATH)
        return 1
    sql_files = sorted(SQL_DIR.glob("*.sql"))
    if not sql_files:
        logger.error("No SQL files found in %s", SQL_DIR)
        return 1

    logger.info("Building %d gold tables", len(sql_files))
    try:
        with duckdb.connect(str(DB_PATH)) as con:
            con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
            for sql_file in sql_files:
                rows = build_table(con, sql_file)
                if rows == 0:
                    logger.error("Table %s.%s is empty", SCHEMA, sql_file.stem)
                    return 1
                logger.info("  %-35s %10s rows", f"{SCHEMA}.{sql_file.stem}", f"{rows:,}")
    except duckdb.Error as error:
        logger.error("Build failed: %s", error)
        return 1

    logger.info("Done: %d gold tables built", len(sql_files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
