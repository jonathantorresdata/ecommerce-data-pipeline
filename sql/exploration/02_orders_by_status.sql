-- How many orders are in each status?
-- ~97% are delivered; canceled + unavailable orders (~1,200) never reach the customer.
SELECT
    order_status,
    count(*) AS orders
FROM raw.orders
GROUP BY order_status
ORDER BY orders DESC;
