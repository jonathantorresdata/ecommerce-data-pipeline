-- review_id + order_id identifies a review (the same review can cover several orders).
SELECT review_id, order_id
FROM {{ ref('order_reviews') }}
GROUP BY review_id, order_id
HAVING count(*) > 1
