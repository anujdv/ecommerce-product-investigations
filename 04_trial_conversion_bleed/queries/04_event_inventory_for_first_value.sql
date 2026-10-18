-- Show which feature IDs generate feature_use events.
-- Map these IDs through saas.features and confirm which represent core value.

SELECT
    feature_id,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT account_id) AS accounts,
    MIN(occurred_at) AS first_seen_at,
    MAX(occurred_at) AS last_seen_at
FROM saas.events
WHERE event_type = 'feature_use'
GROUP BY feature_id
ORDER BY event_rows DESC;
