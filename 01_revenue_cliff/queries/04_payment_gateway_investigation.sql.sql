SELECT
    DATE(o.created_at) AS order_date,
    pt.gateway,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE
        WHEN o.payment_status = 'failed'
             AND pt.status = 'failed'
        THEN o.order_id
    END) AS failed_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.payment_status = 'failed'
                 AND pt.status = 'failed'
            THEN o.order_id
        END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS failure_rate
FROM ecom.orders o
JOIN ecom.payment_intents pi
    ON o.order_id = pi.order_id
JOIN ecom.payment_methods pm
    ON pi.payment_method_id = pm.payment_method_id
JOIN ecom.payment_transactions pt
    ON pi.payment_intent_id = pt.payment_intent_id
WHERE
    o.created_at >= '2026-05-10'
    AND o.created_at < '2026-05-20'
    AND pm.method_name = 'upi'
GROUP BY
    DATE(o.created_at),
    pt.gateway
ORDER BY
    order_date,
    pt.gateway;
