-- Compare feature_use and invite_sent as candidate first-value milestones.
-- Events count only after trial start and before conversion (or trial end
-- for non-converters).

WITH mature_trials AS (
    SELECT
        t.trial_id,
        t.account_id,
        t.started_at,
        t.ends_at,
        t.converted_at,
        a.employee_count,
        COALESCE(a.acquisition_channel, 'Unknown') AS acquisition_channel
    FROM saas.trials AS t
    JOIN saas.accounts AS a
        ON a.account_id = t.account_id
    WHERE t.ends_at < CURRENT_TIMESTAMP
),
cutoffs AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY employee_count) AS q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY employee_count) AS q2,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY employee_count) AS q3
    FROM mature_trials
    WHERE employee_count IS NOT NULL
),
milestones AS (
    SELECT 'feature_use' AS milestone
    UNION ALL
    SELECT 'invite_sent'
),
trial_milestones AS (
    SELECT
        mt.trial_id,
        mt.started_at,
        mt.converted_at,
        mt.employee_count,
        mt.acquisition_channel,
        m.milestone,
        c.q1,
        c.q2,
        c.q3,
        MIN(e.occurred_at) AS first_milestone_at
    FROM mature_trials AS mt
    CROSS JOIN milestones AS m
    CROSS JOIN cutoffs AS c
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
        mt.started_at,
        mt.converted_at,
        mt.employee_count,
        mt.acquisition_channel,
        m.milestone,
        c.q1,
        c.q2,
        c.q3
),
timed AS (
    SELECT
        *,
        EXTRACT(EPOCH FROM (first_milestone_at - started_at)) / 3600.0
            AS hours_to_milestone
    FROM trial_milestones
),
bucketed AS (
    SELECT
        *,
        CASE
            WHEN employee_count IS NULL THEN 'Unknown'
            WHEN employee_count <= q1 THEN 'Q1 (smallest)'
            WHEN employee_count <= q2 THEN 'Q2'
            WHEN employee_count <= q3 THEN 'Q3'
            ELSE 'Q4 (largest)'
        END AS team_size_quartile,
        CASE
            WHEN first_milestone_at IS NULL THEN 'Milestone not reached'
            WHEN hours_to_milestone <= 24 THEN 'Within 1 day'
            WHEN hours_to_milestone <= 72 THEN '1-3 days'
            WHEN hours_to_milestone <= 168 THEN '3-7 days'
            ELSE 'Over 7 days'
        END AS time_to_milestone_bucket
    FROM timed
)
SELECT
    milestone,
    team_size_quartile,
    acquisition_channel,
    time_to_milestone_bucket,
    COUNT(*) AS ended_trials,
    SUM(CASE WHEN first_milestone_at IS NOT NULL THEN 1 ELSE 0 END)
        AS trials_reaching_milestone,
    SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END)
        AS converted_trials,
    ROUND(
        100.0 * SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_pct,
    ROUND(AVG(hours_to_milestone), 2) AS avg_hours_to_milestone
FROM bucketed
GROUP BY
    milestone,
    team_size_quartile,
    acquisition_channel,
    time_to_milestone_bucket
ORDER BY
    milestone,
    team_size_quartile,
    acquisition_channel,
    time_to_milestone_bucket;
