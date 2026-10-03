-- Check payment status around May 13

SELECT
    DATE(created_at) AS order_date,
    payment_status,
    COUNT(DISTINCT order_id) AS orders,
    SUM(total) AS order_value
FROM ecom.orders
WHERE created_at >= '2026-05-10'
  AND created_at < '2026-05-20'
GROUP BY
    DATE(created_at),
    payment_status
ORDER BY
    order_date,
    payment_status;
