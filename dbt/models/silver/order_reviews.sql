-- One row per review and order, only once the review has been written.
-- The same review_id can apply to several orders.
WITH replayed AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title AS comment_title,
        review_comment_message AS comment_message,
        {{ replay('review_creation_date') }} AS created_at,
        {{ replay('review_answer_timestamp') }} AS answered_at
    FROM {{ source('bronze', 'order_reviews') }}
)

SELECT
    review_id,
    order_id,
    review_score,
    comment_title,
    comment_message,
    created_at,
    {{ visible('answered_at') }} AS answered_at
FROM replayed
WHERE created_at <= {{ as_of() }}
  AND order_id IN (SELECT order_id FROM {{ ref('orders') }})
