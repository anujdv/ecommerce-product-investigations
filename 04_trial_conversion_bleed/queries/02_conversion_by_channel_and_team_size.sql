-- Trial conversion by acquisition channel within data-derived
-- employee-count quartiles. Quartiles are calculated over mature trials.

WITH mature_trials AS (
    SELECT
        t.trial_id,
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
bucketed AS (
    SELECT
        mt.trial_id,
        mt.converted_at,
        mt.employee_count,
        mt.acquisition_channel,
        c.q1,
        c.q2,
        c.q3,
        CASE
            WHEN mt.employee_count IS NULL THEN 'Unknown'
            WHEN mt.employee_count <= c.q1 THEN 'Q1 (smallest)'
            WHEN mt.employee_count <= c.q2 THEN 'Q2'
            WHEN mt.employee_count <= c.q3 THEN 'Q3'
            ELSE 'Q4 (largest)'
        END AS team_size_quartile
    FROM mature_trials AS mt
    CROSS JOIN cutoffs AS c
)
SELECT
    team_size_quartile,
    acquisition_channel,
    MIN(employee_count) AS min_employee_count,
    MAX(employee_count) AS max_employee_count,
    MAX(q1) AS q1_cutoff,
    MAX(q2) AS q2_cutoff,
    MAX(q3) AS q3_cutoff,
    COUNT(*) AS ended_trials,
    SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END) AS converted_trials,
    SUM(CASE WHEN converted_at IS NULL THEN 1 ELSE 0 END) AS not_converted_trials,
    ROUND(
        100.0 * SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_pct
FROM bucketed
GROUP BY team_size_quartile, acquisition_channel
ORDER BY team_size_quartile, acquisition_channel;
