"""Upload the raw Olist CSV files to the bronze container of Azure Data Lake Storage.

Each CSV in data/raw/ is copied as-is to bronze/olist/<file name>. Existing files
are overwritten on every run, so the upload is idempotent. Credentials are read
from the .env file (see .env.example).

Usage:
    python pipeline/upload_to_lake.py
"""

import logging
import os
import sys
from pathlib import Path

from azure.core.exceptions import AzureError
from azure.storage.filedatalake import DataLakeServiceClient, FileSystemClient
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"
CONTAINER = "bronze"
LAKE_DIR = "olist"

FILES = [
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger(__name__)
logging.getLogger("azure").setLevel(logging.WARNING)


def upload_file(container: FileSystemClient, file_name: str) -> int:
    """Upload one CSV to the lake, overwriting it, and return its size in bytes once checked."""
    local_path = RAW_DIR / file_name
    file_client = container.get_file_client(f"{LAKE_DIR}/{file_name}")
    with open(local_path, "rb") as data:
        file_client.upload_data(data, overwrite=True)

    local_size = local_path.stat().st_size
    lake_size = file_client.get_file_properties().size
    if lake_size != local_size:
        raise RuntimeError(f"{file_name}: {lake_size} bytes in the lake, {local_size} locally")
    return lake_size


def main() -> int:
    load_dotenv(PROJECT_ROOT / ".env")
    account_name = os.getenv("AZURE_STORAGE_ACCOUNT_NAME")
    account_key = os.getenv("AZURE_STORAGE_ACCOUNT_KEY")
    if not account_name or not account_key:
        logger.error("Missing Azure credentials: fill in .env (see .env.example)")
        return 1

    missing = [name for name in FILES if not (RAW_DIR / name).exists()]
    if missing:
        logger.error("Missing CSV files: %s. Run scripts/download_data.py first", ", ".join(missing))
        return 1

    logger.info("Uploading %d files to %s/%s/%s", len(FILES), account_name, CONTAINER, LAKE_DIR)
    try:
        service = DataLakeServiceClient(
            account_url=f"https://{account_name}.dfs.core.windows.net",
            credential=account_key,
        )
        container = service.get_file_system_client(CONTAINER)
        for file_name in FILES:
            size = upload_file(container, file_name)
            logger.info("  %-42s %6.1f MB", file_name, size / 1_000_000)
    except (AzureError, RuntimeError) as error:
        logger.error("Upload failed: %s", error)
        return 1

    logger.info("Done: %d files uploaded", len(FILES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
