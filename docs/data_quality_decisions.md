# Data quality decisions

Each issue found while profiling the raw data, and what the `silver` layer does about it.

**Rule:** never delete data silently. Fix it when the fix is safe; otherwise flag it with a column so every report can decide.

| # | Issue | Decision | Why |
|---|---|---|---|
| 1 | `geolocation` has ~52 rows per zip code prefix | **Fix:** one row per zip code (average coordinates) | Joining on zip code would multiply rows |
| 2 | `review_id` repeats (99,224 rows, 98,410 ids) | **Keep** | Not duplicates: the same review applies to several orders. `review_id` + `order_id` is unique |
| 3 | 775 orders have no items | **Flag** (`has_items`) | The orders existed (most likely canceled); deleting them would hide them |
| 4 | 8 orders are `delivered` but have no delivery date | **Flag** (`is_missing_delivery_date`) | The date cannot be invented, but it can be reported |
| 4b | 6 orders are `canceled` but have a delivery date | **Flag** (`is_canceled_but_delivered`) | Contradictory status: kept and reported |
| 5 | 610 products have no category | **Fix:** category `unknown` | They would disappear when grouping by category |
| 6 | 2 categories have no English translation | **Fix:** keep the Portuguese name | A name is better than a blank |
| 7 | First and last months are almost empty | **Keep** | Not an error: it is the coverage of the dataset. Handled in the live-store replay |
| 8 | `customer_id` is one per order | **Keep** | It is how the source works. Real customers are `customer_unique_id` |
| 9 | 42 `geolocation` coordinates fall outside Brazil | **Fix:** ignored when averaging coordinates | They would place zip codes outside the country |


Checked and correct: no delivery dates before the purchase date, no negative prices or freight values. Automated quality checks will keep watching them.
