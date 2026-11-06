# 0004 — dbt for silver and gold

**Context.** Phases 2–3 built silver and gold with plain SQL files run by small Python scripts on DuckDB. In the cloud, the same logic needs dependencies between models, tests and documentation.

**Decision.** Rebuild silver and gold as dbt models on Databricks (`dbt/`), with `source()` and `ref()` for lineage, schema tests (unique, not null, relationships, accepted values) and singular tests that port the Phase 2–3 quality checks. Bronze stays a Python notebook because it only copies files. The plain SQL files remain the local DuckDB version of the model, checked by CI on every push.

**Consequences.**
- One `dbt build` creates and tests every table in dependency order; a failing test stops the run.
- Two dialects are maintained (DuckDB locally, Spark SQL in dbt); they were checked to produce the same row counts and results.
