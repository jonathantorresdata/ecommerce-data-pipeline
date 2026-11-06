# Architecture decision records

Short records of the decisions that shaped this project: the context, the decision and its consequences.

| # | Decision |
|---|---|
| [0001](0001-single-cloud-azure.md) | One cloud: Azure (Data Lake Storage, Databricks, Data Factory) |
| [0002](0002-infrastructure-as-code.md) | All infrastructure in Terraform, authenticated with a service principal |
| [0003](0003-keyless-data-lake-access.md) | Databricks reaches the lake through a managed identity, not keys |
| [0004](0004-dbt-for-transformations.md) | dbt for silver and gold; plain SQL files kept for the local DuckDB pipeline |
| [0005](0005-live-store-replay.md) | Replay the historical orders as a live store with incremental loads |
| [0006](0006-serverless-compute.md) | Serverless compute for the daily job and the SQL warehouse |
