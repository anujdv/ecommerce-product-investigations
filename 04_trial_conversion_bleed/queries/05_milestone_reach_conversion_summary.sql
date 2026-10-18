-- Compare conversion for mature trials with and without each candidate milestone.
-- A milestone counts only if it occurs after trial start and before conversion
-- (or trial end for a non-converter).

WITH mature_trials AS (
    SELECT
        t.trial_id,
        t.account_id,
        t.started_at,
        t.ends_at,
        t.converted_at
    FROM saas.trials AS t
    JOIN saas.accounts AS a
        ON a.account_id = t.account_id
    WHERE t.ends_at < CURRENT_TIMESTAMP
),
milestones AS (
    SELECT 'feature_use' AS milestone
    UNION ALL
    SELECT 'invite_sent'
),
trial_milestones AS (
    SELECT
        mt.trial_id,
        mt.converted_at,
        m.milestone,
        MIN(e.occurred_at) AS first_milestone_at
    FROM mature_trials AS mt
    CROSS JOIN milestones AS m
    LEFT JOIN saas.events AS e
        ON e.account_id = mt.account_id
       AND e.event_type = m.milestone
       AND e.occurred_at >= mt.started_at
       AND e.occurred_at < mt.ends_at
       AND (
            mt.converted_at IS NULL
            OR e.occurred_at < mt.converted_at
       )
    GROUP BY
        mt.trial_id,
        mt.converted_at,
        m.milestone
)
SELECT
    milestone,
    COUNT(*) FILTER (
        WHERE first_milestone_at IS NOT NULL
    ) AS trials_with_milestone,
    COUNT(*) FILTER (
        WHERE first_milestone_at IS NOT NULL
          AND converted_at IS NOT NULL
    ) AS converted_with_milestone,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE first_milestone_at IS NOT NULL
              AND converted_at IS NOT NULL
        )
        / NULLIF(COUNT(*) FILTER (
            WHERE first_milestone_at IS NOT NULL
        ), 0),
        1
    ) AS conversion_with_milestone_pct,
    COUNT(*) FILTER (
        WHERE first_milestone_at IS NULL
    ) AS trials_without_milestone,
    COUNT(*) FILTER (
        WHERE first_milestone_at IS NULL
          AND converted_at IS NOT NULL
    ) AS converted_without_milestone,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE first_milestone_at IS NULL
              AND converted_at IS NOT NULL
        )
        / NULLIF(COUNT(*) FILTER (
            WHERE first_milestone_at IS NULL
        ), 0),
        1
    ) AS conversion_without_milestone_pct
FROM trial_milestones
GROUP BY milestone
ORDER BY milestone;
