-- Mature trial conversion by acquisition channel and account size.
-- Accounts with missing channel or employee_count remain visible as Unknown.

WITH mature_trials AS (
    SELECT
        t.trial_id,
        t.converted_at,
        a.acquisition_channel,
        a.employee_count
    FROM trials t
    JOIN accounts a
        ON a.account_id = t.account_id
    WHERE t.ends_at < CURRENT_TIMESTAMP
),
segments AS (
    SELECT
        trial_id,
        converted_at,
        'acquisition_channel' AS segment_dimension,
        COALESCE(acquisition_channel, 'Unknown') AS segment
    FROM mature_trials

    UNION ALL

    SELECT
        trial_id,
        converted_at,
        'team_size' AS segment_dimension,
        CASE
            WHEN employee_count IS NULL THEN 'Unknown'
            WHEN employee_count = 1 THEN '1'
            WHEN employee_count BETWEEN 2 AND 10 THEN '2-10'
            WHEN employee_count BETWEEN 11 AND 50 THEN '11-50'
            WHEN employee_count BETWEEN 51 AND 200 THEN '51-200'
            ELSE '201+'
        END AS segment
    FROM mature_trials
)
SELECT
    segment_dimension,
    segment,
    COUNT(*) AS ended_trials,
    SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END) AS converted_trials,
    SUM(CASE WHEN converted_at IS NULL THEN 1 ELSE 0 END) AS not_converted_trials,
    ROUND(
        100.0 * SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS trial_to_paid_conversion_pct,
    ROUND(
        100.0 * SUM(CASE WHEN converted_at IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS trial_dropoff_pct
FROM segments
GROUP BY segment_dimension, segment
ORDER BY segment_dimension, segment;
