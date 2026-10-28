-- One row per review and order: the same review_id can apply to several orders.
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title AS comment_title,
    review_comment_message AS comment_message,
    review_creation_date AS created_at,
    review_answer_timestamp AS answered_at
FROM raw.order_reviews;
