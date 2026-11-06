# 0006 — Serverless compute for the daily job and SQL

**Context.** The free-trial subscription allows 4 vCPUs per region, which is exactly one small cluster. A daily job cluster and an interactive cluster could not run at the same time, and the first cluster created right after the workspace got stuck while provisioning.

**Decision.** Run the daily job (bronze notebook + dbt task) on serverless jobs compute and serve dbt and Power BI from a 2X-Small serverless SQL warehouse that stops after 5 idle minutes. Keep one single-node cluster (15-minute auto-termination) for interactive work.

**Consequences.**
- No VM quota is used by the daily run, and compute starts in seconds.
- Cost is only the seconds of work; a budget with email alerts watches the total.
