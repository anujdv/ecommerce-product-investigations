-- Inventory event types used to identify first-value candidates.

SELECT
    event_type,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT account_id) AS accounts,
    MIN(occurred_at) AS first_seen_at,
    MAX(occurred_at) AS last_seen_at
FROM saas.events
GROUP BY event_type
ORDER BY event_rows DESC;
