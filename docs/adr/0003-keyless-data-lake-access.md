# 0003 — Keyless access from Databricks to the data lake

**Context.** Databricks needs to read the raw files and write Delta tables in the storage account. Storage account keys give full access and have to be stored and rotated.

**Decision.** Use an Access Connector for Azure Databricks (a managed identity) with the *Storage Blob Data Contributor* role scoped to the storage account only, registered in Unity Catalog as a storage credential with two external locations (`bronze` and `lakehouse`). Data Factory reaches Databricks with its own managed identity.

**Consequences.**
- No secrets inside Databricks or Data Factory.
- Least privilege: the identity cannot manage the account or touch other resources.
- The only key in use is the one the local upload script needs, kept in `.env`.
