"""Run SQL against the local DuckDB database and print the results.

Usage:
    python scripts/sql.py "SELECT count(*) FROM raw.orders"
    python scripts/sql.py sql/exploration/01_tables_overview.sql
"""

import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "data" / "olist.duckdb"
MAX_ROWS = 50


def read_query(argument: str) -> str:
    """Return the SQL text: the content of a .sql file, or the argument itself."""
    if argument.endswith(".sql"):
        return Path(argument).read_text()
    return argument


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    if not DB_PATH.exists():
        print(f"Database not found at {DB_PATH}. Run pipeline/load_raw.py first", file=sys.stderr)
        return 1

    statements = [s.strip() for s in read_query(sys.argv[1]).split(";") if s.strip()]
    try:
        with duckdb.connect(str(DB_PATH), read_only=True) as con:
            for statement in statements:
                print(f"\n{statement}\n")
                result = con.sql(statement)
                if result is not None:
                    result.show(max_rows=MAX_ROWS)
    except (duckdb.Error, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
