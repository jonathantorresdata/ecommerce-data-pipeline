-- One row per product in an order: what was sold, by whom, to whom and when.
SELECT
    i.order_id,
    i.item_number,
    i.product_id,
    i.seller_id,
    c.customer_unique_id,
    CAST(o.purchased_at AS DATE) AS purchase_date,
    o.order_status,
    i.price,
    i.freight_value
FROM silver.order_items AS i
LEFT JOIN silver.orders AS o
    ON i.order_id = o.order_id
LEFT JOIN silver.customers AS c
    ON o.customer_id = c.customer_id;
