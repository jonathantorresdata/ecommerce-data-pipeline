-- One row per product within an order.
SELECT
    order_id,
    order_item_id AS item_number,
    product_id,
    seller_id,
    shipping_limit_date AS shipping_limit_at,
    price,
    freight_value
FROM raw.order_items;
