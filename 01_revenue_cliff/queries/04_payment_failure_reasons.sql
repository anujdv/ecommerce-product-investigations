-- May 13 payment failure reasons

SELECT
    gateway,
    error_code,
    error_message,
    COUNT(*) AS failed_transactions
FROM ecom.payment_transactions
WHERE txn_time >= '2026-05-13'
  AND txn_time < '2026-05-14'
  AND status = 'failed'
GROUP BY
    gateway,
    error_code,
    error_message
ORDER BY failed_transactions DESC;
