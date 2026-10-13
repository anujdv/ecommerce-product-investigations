-- Baseline trial-to-paid conversion.
-- Use only trials whose planned trial end has passed so active trials are
-- not incorrectly counted as drop-offs. Validate whether ends_at is the
-- correct maturity boundary for the product's conversion policy.

SELECT
    COUNT(*) AS ended_trials,
    COUNT(*) FILTER (
        WHERE converted_at IS NOT NULL
    ) AS converted_trials,
    COUNT(*) FILTER (
        WHERE converted_at IS NULL
    ) AS not_converted_trials,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE converted_at IS NOT NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS trial_to_paid_conversion_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE converted_at IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS trial_dropoff_pct
FROM trials
WHERE ends_at < CURRENT_TIMESTAMP;
