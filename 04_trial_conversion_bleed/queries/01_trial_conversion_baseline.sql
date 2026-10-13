-- Overall conversion among mature trials.
-- A trial is considered mature once its planned end time has passed.

SELECT
    COUNT(*) AS ended_trials,
    COUNT(*) FILTER (WHERE converted_at IS NOT NULL) AS converted_trials,
    COUNT(*) FILTER (WHERE converted_at IS NULL) AS not_converted_trials,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE converted_at IS NOT NULL)
        / NULLIF(COUNT(*), 0),
        2
    ) AS trial_to_paid_conversion_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE converted_at IS NULL)
        / NULLIF(COUNT(*), 0),
        2
    ) AS trial_dropoff_pct
FROM saas.trials
WHERE ends_at < CURRENT_TIMESTAMP;
