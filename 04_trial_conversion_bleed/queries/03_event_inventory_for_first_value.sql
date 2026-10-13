-- Inventory event types to identify the product's first-value milestone.
-- Confirm the semantic meaning of candidate event types before using one
-- to calculate time to first value.

SELECT
    event_type,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT account_id) AS accounts,
    MIN(occurred_at) AS first_seen_at,
    MAX(occurred_at) AS last_seen_at
FROM events
GROUP BY event_type
ORDER BY event_rows DESC;
