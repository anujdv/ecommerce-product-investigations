-- Orders linked to GATEWAY_TIMEOUT failures on May 13

WITH timeout_orders AS (
    SELECT DISTINCT
        pi.order_id
    FROM ecom.payment_transactions pt
    JOIN ecom.payment_intents pi
        ON pt.payment_intent_id = pi.payment_intent_id
    WHERE pt.txn_time >= '2026-05-13'
      AND pt.txn_time < '2026-05-14'
      AND pt.status = 'failed'
      AND pt.error_code = 'GATEWAY_TIMEOUT'
)
SELECT
    o.payment_status,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total) AS order_value
FROM ecom.orders o
JOIN timeout_orders t
    ON o.order_id = t.order_id
GROUP BY o.payment_status
ORDER BY orders DESC;
