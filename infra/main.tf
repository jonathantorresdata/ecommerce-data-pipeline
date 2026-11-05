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
  name    = "cred_ecommerce_lake"
  comment = "Managed identity with access to the data lake"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.lake.id
  }

  depends_on = [azurerm_role_assignment.connector_lake]
}

resource "databricks_external_location" "bronze" {
  name            = "ext_bronze"
  url             = format(local.lake_url, azurerm_storage_container.bronze.name)
  credential_name = databricks_storage_credential.lake.name
  comment         = "Raw Olist CSV files (bronze layer)"
}

resource "databricks_external_location" "lakehouse" {
  name            = "ext_lakehouse"
  url             = format(local.lake_url, azurerm_storage_container.lakehouse.name)
  credential_name = databricks_storage_credential.lake.name
  comment         = "Delta tables for the silver and gold layers"
}

resource "databricks_catalog" "olist" {
  name         = "olist"
  storage_root = databricks_external_location.lakehouse.url
  comment      = "E-commerce data pipeline (Olist dataset)"
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

# --- Values needed after apply ---

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.main.workspace_url}"
}

output "storage_account_key" {
  value     = azurerm_storage_account.lake.primary_access_key
  sensitive = true
}
