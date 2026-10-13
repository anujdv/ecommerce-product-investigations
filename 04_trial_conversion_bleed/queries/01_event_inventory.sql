-- Inventory recorded event types before defining the trial funnel.
-- Use this result to confirm the exact trial-start, activation, checkout,
-- and successful-payment event names in the source data.

SELECT
    event_type,
    DATE(occurred_at) AS event_date,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT session_id) AS sessions
FROM ecom.session_events
WHERE occurred_at >= DATE '2026-01-01'
GROUP BY
    event_type,
    DATE(occurred_at)
ORDER BY
    event_date,
    event_type;
