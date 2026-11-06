# 0005 — Replay the history as a live store

**Context.** Olist covers 2016–2018. A static snapshot does not show incremental loading, late-arriving data or a dashboard that changes every day.

**Decision.** Shift every timestamp by a fixed number of days so that the original 2018-03-01 lands on the store opening day (2026-11-06, dbt vars `replay_original_start` and `replay_store_opening`). At each run, dbt shows only what has already happened at that moment:
- Orders placed before now are visible; earlier orders form the historical backfill.
- Events in the future (approval, shipping, delivery, review answers) are NULL, and the status follows them: an order delivered next week is `shipped` today.
- `fact_orders` is incremental (merge on `order_id`) and only processes orders whose `updated_at` changed, so a delivery or review for an older order updates its existing row.
- The `as_of` var rebuilds the store as it was on any day.

**Consequences.**
- Every daily run adds roughly one day of real orders until mid-2027.
- It is a replay of real data, not live data; the README says so.
