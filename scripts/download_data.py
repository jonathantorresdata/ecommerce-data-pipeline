"""Download the Olist e-commerce dataset from Kaggle into data/raw/.

Usage:
    python scripts/download_data.py           # skip if the files already exist
    python scripts/download_data.py --force   # download again and overwrite
"""

import argparse
import logging
import sys
import urllib.request
import zipfile
from pathlib import Path

DATASET_URL = "https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"
ZIP_PATH = PROJECT_ROOT / "data" / "olist.zip"

EXPECTED_FILES = [
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


def missing_files() -> list[str]:
    """Return the expected CSV files that are not yet in data/raw/."""
    return [name for name in EXPECTED_FILES if not (RAW_DIR / name).exists()]


def download_zip() -> None:
    """Download the dataset archive from Kaggle."""
    logger.info("Downloading dataset from Kaggle...")
    ZIP_PATH.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(DATASET_URL, ZIP_PATH)
    except Exception as error:
        raise RuntimeError(
            f"Download failed ({error}). Kaggle may now require authentication "
            "for this dataset: download it manually from "
            "https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce "
            f"and unzip it into {RAW_DIR}"
        ) from error
    size_mb = ZIP_PATH.stat().st_size / 1_000_000
    logger.info("Downloaded %.1f MB", size_mb)


def extract_zip() -> None:
    """Extract only the expected CSV files into data/raw/."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ZIP_PATH) as archive:
        for member in archive.namelist():
            name = Path(member).name
            if name in EXPECTED_FILES:
                (RAW_DIR / name).write_bytes(archive.read(member))
    ZIP_PATH.unlink()
    logger.info("Extracted files into %s", RAW_DIR)


def main() -> int:
    parser = argparse.ArgumentParser(description="Download the Olist dataset.")
    parser.add_argument("--force", action="store_true", help="download even if files exist")
    args = parser.parse_args()

    if not args.force and not missing_files():
        logger.info("All %d files already in %s, nothing to do", len(EXPECTED_FILES), RAW_DIR)
        return 0

    try:
        download_zip()
        extract_zip()
    except (RuntimeError, zipfile.BadZipFile) as error:
        logger.error(error)
        return 1

    missing = missing_files()
    if missing:
        logger.error("Missing files after extraction: %s", ", ".join(missing))
        return 1

    for name in EXPECTED_FILES:
        size_mb = (RAW_DIR / name).stat().st_size / 1_000_000
        logger.info("  %-42s %6.1f MB", name, size_mb)
    logger.info("Done: %d files ready", len(EXPECTED_FILES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
