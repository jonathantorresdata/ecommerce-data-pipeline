# 0001 — One cloud: Azure

**Context.** Junior data engineering roles in Spain that ask for a cloud mostly ask for Azure with Databricks and Data Factory, usually next to Power BI.

**Decision.** Build the whole platform on Azure: Data Lake Storage Gen2 for files, Azure Databricks with Unity Catalog for processing, Data Factory for scheduling. All resources live in one resource group in Sweden Central.

**Consequences.**
- One set of credentials and one bill.
- Sweden Central was chosen because West Europe did not accept new free-trial customers at the time; keeping storage and compute in the same region avoids cross-region transfer costs.
- The concepts map directly to other clouds (S3, IAM roles, EC2, Glue/Airflow).
