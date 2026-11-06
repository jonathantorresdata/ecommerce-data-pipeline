# Azure infrastructure for the e-commerce data pipeline:
# data lake (bronze + lakehouse), Databricks workspace, keyless access via a managed
# identity, Unity Catalog objects and a small auto-terminating cluster.
#
# Usage (from the repo root):
#   set -a; source .env; set +a
#   terraform -chdir=infra init
#   terraform -chdir=infra apply
#   terraform -chdir=infra destroy

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.140.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "databricks" {
  host                        = "https://${azurerm_databricks_workspace.main.workspace_url}"
  azure_workspace_resource_id = azurerm_databricks_workspace.main.id
}

locals {
  location     = "swedencentral"
  storage_name = "stecommercepipelinejt"
  lake_url     = "abfss://%s@${local.storage_name}.dfs.core.windows.net/"
}

# --- Resource group: everything lives here, so one delete removes it all ---

resource "azurerm_resource_group" "main" {
  name     = "rg-ecommerce-pipeline"
  location = local.location
}

# --- Data lake (ADLS Gen2) ---

resource "azurerm_storage_account" "lake" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "lakehouse" {
  name                  = "lakehouse"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

# --- Managed identity that Databricks uses to reach the lake (no keys) ---

resource "azurerm_databricks_access_connector" "lake" {
  name                = "ac-ecommerce-pipeline"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "connector_lake" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.lake.identity[0].principal_id
}

# --- Databricks workspace ---

resource "azurerm_databricks_workspace" "main" {
  name                        = "dbw-ecommerce-pipeline"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  sku                         = "premium"
  managed_resource_group_name = "databricks-rg-ecommerce-pipeline"

  custom_parameters {
    no_public_ip = false # avoids a NAT gateway that is billed even when idle
  }
}

# --- Unity Catalog: credential, external locations, catalog and schemas ---

resource "databricks_storage_credential" "lake" {
  name          = "cred_ecommerce_lake"
  force_destroy = true
  comment       = "Managed identity with access to the data lake"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.lake.id
  }

  depends_on = [azurerm_role_assignment.connector_lake]
}

resource "databricks_external_location" "bronze" {
  name            = "ext_bronze"
  force_destroy   = true
  url             = format(local.lake_url, azurerm_storage_container.bronze.name)
  credential_name = databricks_storage_credential.lake.name
  comment         = "Raw Olist CSV files (bronze layer)"
}

resource "databricks_external_location" "lakehouse" {
  name            = "ext_lakehouse"
  force_destroy   = true
  url             = format(local.lake_url, azurerm_storage_container.lakehouse.name)
  credential_name = databricks_storage_credential.lake.name
  comment         = "Delta tables for the silver and gold layers"
}

resource "databricks_catalog" "olist" {
  name          = "olist"
  storage_root  = databricks_external_location.lakehouse.url
  comment       = "E-commerce data pipeline (Olist dataset)"
  force_destroy = true # terraform destroy also drops its schemas and tables
}

resource "databricks_schema" "layers" {
  for_each     = toset(["bronze", "silver", "gold"])
  catalog_name = databricks_catalog.olist.name
  name         = each.key
}

# --- Compute: one small node that shuts itself down after 15 idle minutes ---

data "databricks_spark_version" "lts" {
  long_term_support = true
  depends_on        = [azurerm_databricks_workspace.main]
}

resource "databricks_cluster" "main" {
  cluster_name            = "cluster-ecommerce"
  spark_version           = data.databricks_spark_version.lts.id
  node_type_id            = "Standard_D4ds_v5"
  num_workers             = 0
  autotermination_minutes = 15
  data_security_mode      = "USER_ISOLATION"
  no_wait                 = true

  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

# Serverless SQL warehouse for dbt and Power BI: starts in seconds, uses no VM quota
# and stops after 5 idle minutes.
resource "databricks_sql_endpoint" "main" {
  name                      = "wh-ecommerce"
  cluster_size              = "2X-Small"
  min_num_clusters          = 1
  max_num_clusters          = 1
  auto_stop_mins            = 5
  enable_serverless_compute = true
  warehouse_type            = "PRO"
}

# Every workspace user (including Power BI connections) can read the catalog.
resource "databricks_grants" "olist" {
  catalog = databricks_catalog.olist.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

# --- Values needed after apply ---

output "databricks_host" {
  value = azurerm_databricks_workspace.main.workspace_url
}

output "warehouse_http_path" {
  value = databricks_sql_endpoint.main.odbc_params[0].path
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.main.workspace_url}"
}

output "storage_account_key" {
  value     = azurerm_storage_account.lake.primary_access_key
  sensitive = true
}

# --- Code: bronze loader notebook and dbt project, uploaded to the workspace ---

locals {
  code_root = "/Shared/ecommerce-pipeline"
  dbt_files = setunion(
    fileset("${path.module}/../dbt", "dbt_project.yml"),
    fileset("${path.module}/../dbt", "macros/**"),
    fileset("${path.module}/../dbt", "models/**"),
    fileset("${path.module}/../dbt", "tests/**"),
  )
}

resource "databricks_directory" "code" {
  for_each = toset(concat([local.code_root, "${local.code_root}/dbt"], [for f in local.dbt_files : "${local.code_root}/dbt/${dirname(f)}" if dirname(f) != "."]))
  path     = each.key
}

resource "databricks_notebook" "load_bronze" {
  depends_on = [databricks_directory.code]
  source     = "${path.module}/../databricks/load_bronze.py"
  path       = "${local.code_root}/load_bronze"
}

resource "databricks_workspace_file" "dbt" {
  for_each   = local.dbt_files
  depends_on = [databricks_directory.code]
  source     = "${path.module}/../dbt/${each.value}"
  path       = "${local.code_root}/dbt/${each.value}"
}

# --- Job: load bronze, then dbt builds and tests silver and gold (serverless) ---

resource "databricks_job" "live_store" {
  name = "live-store"

  environment {
    environment_key = "dbt"
    spec {
      client       = "2"
      dependencies = ["dbt-databricks==1.13.0"]
    }
  }

  # Tasks are listed in alphabetical order, as the Jobs API returns them.
  task {
    task_key        = "dbt_build"
    environment_key = "dbt"

    depends_on {
      task_key = "load_bronze"
    }

    dbt_task {
      source            = "WORKSPACE"
      project_directory = "/Workspace${local.code_root}/dbt"
      commands          = ["dbt build"]
      warehouse_id      = databricks_sql_endpoint.main.id
      catalog           = databricks_catalog.olist.name
      schema            = "silver"
    }
  }

  task {
    task_key = "load_bronze"

    notebook_task {
      notebook_path = databricks_notebook.load_bronze.path
      base_parameters = {
        catalog    = databricks_catalog.olist.name
        bronze_url = databricks_external_location.bronze.url
      }
    }
  }

  depends_on = [databricks_workspace_file.dbt, databricks_schema.layers]
}

# --- Orchestration: Azure Data Factory runs the job every morning ---

resource "azurerm_data_factory" "main" {
  name                = "adf-ecommerce-pipeline-jt"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }
}

# Data Factory signs in to Databricks with its managed identity (no tokens).
resource "azurerm_role_assignment" "adf_databricks" {
  scope                = azurerm_databricks_workspace.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}

resource "azurerm_data_factory_linked_service_azure_databricks" "main" {
  name                       = "ls_databricks"
  data_factory_id            = azurerm_data_factory.main.id
  adb_domain                 = "https://${azurerm_databricks_workspace.main.workspace_url}"
  msi_work_space_resource_id = azurerm_databricks_workspace.main.id
  existing_cluster_id        = databricks_cluster.main.id
}

resource "azurerm_data_factory_pipeline" "daily" {
  name            = "pl_daily_live_store"
  data_factory_id = azurerm_data_factory.main.id
  description     = "Daily load of the live store: bronze, then dbt build and tests."

  activities_json = jsonencode([
    {
      name = "run_live_store_job"
      type = "DatabricksJob"
      linkedServiceName = {
        referenceName = azurerm_data_factory_linked_service_azure_databricks.main.name
        type          = "LinkedServiceReference"
      }
      policy = {
        timeout                = "0.01:00:00"
        retry                  = 1
        retryIntervalInSeconds = 300
      }
      typeProperties = {
        jobId = tostring(databricks_job.live_store.id)
      }
    }
  ])
}

resource "azurerm_data_factory_trigger_schedule" "daily" {
  name            = "tr_daily_0600"
  data_factory_id = azurerm_data_factory.main.id
  pipeline_name   = azurerm_data_factory_pipeline.daily.name
  frequency       = "Day"
  interval        = 1
  start_time      = "2026-11-07T05:00:00Z" # 06:00 in Spain
  activated       = true
}

output "job_url" {
  value = "https://${azurerm_databricks_workspace.main.workspace_url}/jobs/${databricks_job.live_store.id}"
}
