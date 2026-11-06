#!/usr/bin/env bash
# Run dbt against the Databricks SQL warehouse from this machine.
# Credentials come from .env; host and warehouse path from the Terraform outputs.
#
# Usage:
#   scripts/run_dbt.sh build                    # build and test silver and gold
#   scripts/run_dbt.sh build --vars '{as_of: "2026-12-31 23:59:59"}'
#   scripts/run_dbt.sh docs generate

set -euo pipefail
cd "$(dirname "$0")/.."

set -a
source .env
set +a

export DATABRICKS_HOST="$(terraform -chdir=infra output -raw databricks_host)"
export DATABRICKS_HTTP_PATH="$(terraform -chdir=infra output -raw warehouse_http_path)"
export DBT_PROFILES_DIR="$PWD/dbt/profiles"

cd dbt
dbt "$@"
