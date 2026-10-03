-- May 1-20 baseline: daily orders, revenue and AOV

SELECT
    DATE(created_at) AS order_date,
    COUNT(DISTINCT order_id) AS orders,
    SUM(total) AS revenue,
    SUM(total) / COUNT(DISTINCT order_id) AS aov
FROM ecom.orders
WHERE created_at >= '2026-05-01'
  AND created_at < '2026-05-21'
GROUP BY DATE(created_at)
ORDER BY order_date;
