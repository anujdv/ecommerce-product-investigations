SELECT
    DATE_TRUNC('hour', pt.txn_time) AS hour,
    COUNT(*) AS failed_transactions,
    COUNT(*) FILTER (
        WHERE pt.error_code = 'GATEWAY_TIMEOUT'
    ) AS gateway_timeouts
FROM ecom.payment_transactions pt
WHERE pt.txn_time >= '2026-05-13'
  AND pt.txn_time < '2026-05-14'
  AND pt.status = 'failed'
GROUP BY DATE_TRUNC('hour', pt.txn_time)
ORDER BY hour;
