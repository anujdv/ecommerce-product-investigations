# Trial→Paid Conversion Bleed (SaaS)

## Central Question

Why do about 60% of SaaS trials end without converting to a paid subscription?

Segment trial-to-paid conversion by acquisition channel, account team size, and time to first value.

---

## 1. Baseline

A trial is counted as mature when `ends_at < CURRENT_TIMESTAMP`. A mature trial is converted when `converted_at` is populated.

### SQL

```sql
SELECT
    COUNT(*) AS ended_trials,
    COUNT(*) FILTER (WHERE converted_at IS NOT NULL) AS converted_trials,
    COUNT(*) FILTER (WHERE converted_at IS NULL) AS not_converted_trials,
    ROUND(100.0 * COUNT(*) FILTER (WHERE converted_at IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS trial_to_paid_conversion_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE converted_at IS NULL)
        / NULLIF(COUNT(*), 0), 2) AS trial_dropoff_pct
FROM saas.trials
WHERE ends_at < CURRENT_TIMESTAMP;
```

### Output

| ended_trials | converted_trials | not_converted_trials | conversion_pct | dropoff_pct |
| ---: | ---: | ---: | ---: | ---: |
| 250 | 113 | 137 | 45.20 | 54.80 |

The observed drop-off is 54.8%, 5.2 percentage points below the approximate 60% in the central question. This is close, but the exact rate depends on the trial maturity and conversion definitions.

---

## 2. Conversion by Acquisition Channel

Channel is taken from `saas.accounts.acquisition_channel`.

### SQL

```sql
WITH mature_trials AS (
    SELECT t.trial_id, t.converted_at,
           COALESCE(a.acquisition_channel, 'Unknown') AS acquisition_channel
    FROM saas.trials AS t
    JOIN saas.accounts AS a ON a.account_id = t.account_id
    WHERE t.ends_at < CURRENT_TIMESTAMP
)
SELECT
    acquisition_channel,
    COUNT(*) AS ended_trials,
    COUNT(*) FILTER (WHERE converted_at IS NOT NULL) AS converted_trials,
    COUNT(*) FILTER (WHERE converted_at IS NULL) AS not_converted_trials,
    ROUND(100.0 * COUNT(*) FILTER (WHERE converted_at IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS conversion_pct
FROM mature_trials
GROUP BY acquisition_channel
ORDER BY ended_trials DESC;
```

### Output

| acquisition_channel | ended_trials | converted_trials | not_converted_trials | conversion_pct |
| --- | ---: | ---: | ---: | ---: |
| organic | 51 | 26 | 25 | 50.98 |
| referral | 50 | 25 | 25 | 50.00 |
| linkedin | 39 | 17 | 22 | 43.59 |
| outbound | 49 | 20 | 29 | 40.82 |
| g2 | 61 | 25 | 36 | 40.98 |

Organic and referral show the highest observed conversion rates; outbound and G2 are lowest. Channel cohorts contain 39–61 trials each, so differences are directional rather than conclusive.

---

## 3. Conversion by Team Size and Channel

Team size uses `saas.accounts.employee_count`. To avoid inventing fixed company-size bands, ended trials were divided into four employee-count quartiles. The cutoffs (Q1 = 97, Q2 = 291.5, Q3 = 790.75 employees) are calculated once across all mature trials with a non-null employee count, regardless of acquisition channel. They are interpolated percentile cutoffs, and tied employee counts can make quartile sizes differ; in this cohort, the overall quartiles contain 62–63 trials.

### SQL

```sql
WITH mature_trials AS (
    SELECT t.trial_id, t.converted_at, a.employee_count,
           COALESCE(a.acquisition_channel, 'Unknown') AS acquisition_channel
    FROM saas.trials AS t
    JOIN saas.accounts AS a ON a.account_id = t.account_id
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
    SELECT mt.*, c.q1, c.q2, c.q3,
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
    ROUND(100.0 * SUM(CASE WHEN converted_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2) AS conversion_pct
FROM bucketed
GROUP BY team_size_quartile, acquisition_channel
ORDER BY team_size_quartile, acquisition_channel;
```

### Overall conversion by team-size quartile

These are pooled trial conversion rates: converted trials divided by ended trials in each quartile. They summarize the channel rows below; they are not an unweighted average of channel percentages.

| team_size_quartile | employee_count_range | ended_trials | converted_trials | not_converted_trials | conversion_pct |
| --- | --- | ---: | ---: | ---: | ---: |
| Q1 (smallest) | 6–96 | 63 | 29 | 34 | 46.03 |
| Q2 | 100–290 | 62 | 31 | 31 | 50.00 |
| Q3 | 293–775 | 62 | 21 | 41 | 33.87 |
| Q4 (largest) | 796–4,985 | 63 | 32 | 31 | 50.79 |

### Output: Channel within global employee-count quartiles

The cutoff columns repeat the shared global thresholds used to assign quartiles. `min_employee_count` and `max_employee_count` show the observed range for each channel within that quartile.

| team_size_quartile | acquisition_channel | min_employee_count | max_employee_count | q1_cutoff | q2_cutoff | q3_cutoff | ended_trials | converted_trials | not_converted_trials | conversion_pct |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Q1 (smallest) | g2 | 14 | 88 | 97 | 291.5 | 790.75 | 15 | 7 | 8 | 46.67 |
| Q1 (smallest) | linkedin | 7 | 60 | 97 | 291.5 | 790.75 | 9 | 4 | 5 | 44.44 |
| Q1 (smallest) | organic | 7 | 77 | 97 | 291.5 | 790.75 | 12 | 4 | 8 | 33.33 |
| Q1 (smallest) | outbound | 6 | 96 | 97 | 291.5 | 790.75 | 15 | 10 | 5 | 66.67 |
| Q1 (smallest) | referral | 9 | 86 | 97 | 291.5 | 790.75 | 12 | 4 | 8 | 33.33 |
| Q2 | g2 | 100 | 289 | 97 | 291.5 | 790.75 | 17 | 7 | 10 | 41.18 |
| Q2 | linkedin | 121 | 250 | 97 | 291.5 | 790.75 | 9 | 4 | 5 | 44.44 |
| Q2 | organic | 115 | 253 | 97 | 291.5 | 790.75 | 12 | 10 | 2 | 83.33 |
| Q2 | outbound | 135 | 262 | 97 | 291.5 | 790.75 | 9 | 2 | 7 | 22.22 |
| Q2 | referral | 100 | 290 | 97 | 291.5 | 790.75 | 15 | 8 | 7 | 53.33 |
| Q3 | g2 | 306 | 772 | 97 | 291.5 | 790.75 | 11 | 4 | 7 | 36.36 |
| Q3 | linkedin | 317 | 743 | 97 | 291.5 | 790.75 | 11 | 4 | 7 | 36.36 |
| Q3 | organic | 304 | 775 | 97 | 291.5 | 790.75 | 18 | 7 | 11 | 38.89 |
| Q3 | outbound | 306 | 772 | 97 | 291.5 | 790.75 | 12 | 2 | 10 | 16.67 |
| Q3 | referral | 293 | 760 | 97 | 291.5 | 790.75 | 10 | 4 | 6 | 40.00 |
| Q4 (largest) | g2 | 796 | 4,052 | 97 | 291.5 | 790.75 | 18 | 7 | 11 | 38.89 |
| Q4 (largest) | linkedin | 830 | 4,368 | 97 | 291.5 | 790.75 | 10 | 5 | 5 | 50.00 |
| Q4 (largest) | organic | 840 | 4,896 | 97 | 291.5 | 790.75 | 9 | 5 | 4 | 55.56 |
| Q4 (largest) | outbound | 851 | 4,310 | 97 | 291.5 | 790.75 | 13 | 6 | 7 | 46.15 |
| Q4 (largest) | referral | 920 | 4,985 | 97 | 291.5 | 790.75 | 13 | 9 | 4 | 69.23 |

Q3 has the lowest overall conversion rate (21/62, 33.9%). Within Q3, observed channel rates range from 16.7% for outbound (2/12) to 40.0% for referral (4/10). Individual channel-by-quartile cells contain only 9–18 trials, so treat these rates as exploratory leads for follow-up.

---

## 4. Time to First Value

This is the third segmentation dimension in the original task, after acquisition channel and team size. It is exploratory; it does not mean a reason for the trial drop-off has been established.

Two candidate milestones were compared: `feature_use` and `invite_sent`. Events counted only when they occurred after trial start and before both conversion and trial end.

### SQL: Milestone reach and conversion

```sql
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
```

Query file: [`05_milestone_reach_conversion_summary.sql`](queries/05_milestone_reach_conversion_summary.sql).

| milestone | trials with milestone | converted with milestone | conversion with milestone | trials without milestone | converted without milestone | conversion without milestone |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `feature_use` | 110 | 52 | 47.3% | 140 | 61 | 43.6% |
| `invite_sent` | 21 | 8 | 38.1% | 229 | 105 | 45.9% |

The observed conversion difference is modest for `feature_use` (+3.7 percentage points) and negative for `invite_sent` (−7.8 points). These are descriptive comparisons, not evidence that either event causes conversion. `invite_sent` is uncommon and may be optional. The event is also required to occur before conversion to count as “with milestone,” so a trial that converts before recording the event appears in the “without” group.

The detailed channel-by-quartile timing table is in Appendix A. Its many cells contain only a few trials, so individual rates are unstable and do not form a consistent pattern. The “Milestone not reached” group includes converted trials; it means no qualifying event was recorded before conversion or trial end, not that the account received no value.

### Conclusion

**Cause status: not established.** The baseline is 54.8% non-conversion (137 of 250 mature trials), close to the task's approximate 60%, but this investigation has not identified why those trials did not convert. A possible lead is an activation or instrumentation gap: 140 trials had no recorded `feature_use` before conversion or trial end. Yet 61 of those trials converted, and the rate difference is only 3.7 percentage points (47.3% vs. 43.6%), so the current event is weak evidence and not a demonstrated cause. `invite_sent` is less common (21 trials) and also does not explain the drop-off: 38.1% converted with a recorded invite versus 45.9% without. These are descriptive associations, not proof that missing activation causes non-conversion.

### Provisional early-warning rubric

Use this only after validating and instrumenting a core-value event:

- **Days 0–2:** allow normal setup time; do not flag an account solely for having no event yet.
- **By day 3:** if no validated core-value event is recorded, mark the account for a low-friction check-in or onboarding prompt.
- **By day 7:** if the event is still absent, prioritize a human onboarding review. Treat this as a support cue, not a prediction that the trial will fail.

The current `feature_use` event should not drive alerts until its feature IDs are mapped and the event is confirmed to represent meaningful product value.

### Recommendation

Map the `feature_id` values with the product team and confirm which event represents a customer completing a core workflow. If no event captures that action, instrument it. Then run a controlled test: offer a day-3 onboarding prompt to trials that have not reached the validated milestone, keep a holdout group, and compare activation and paid conversion. This tests the activation-gap hypothesis instead of assuming it is the cause. Do not use `invite_sent` as the trigger unless inviting teammates is confirmed as core product value.

The detailed channel-by-quartile timing query is maintained in [`06_time_to_first_value_by_segment.sql`](queries/06_time_to_first_value_by_segment.sql).

---

## Appendix A: Detailed time-to-first-value breakdown

The following query and output show the thin channel-by-quartile timing cells for `feature_use`. The “3–7 days” label is rendered with an en dash.

### SQL: Time to first `feature_use`

```sql
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
trial_first_value AS (
    SELECT
        mt.*,
        c.q1,
        c.q2,
        c.q3,
        MIN(e.occurred_at) AS first_value_at
    FROM mature_trials AS mt
    CROSS JOIN cutoffs AS c
    LEFT JOIN saas.events AS e
        ON e.account_id = mt.account_id
       AND e.event_type = 'feature_use'
       AND e.occurred_at >= mt.started_at
       AND e.occurred_at < mt.ends_at
       AND (
            mt.converted_at IS NULL
            OR e.occurred_at < mt.converted_at
       )
    GROUP BY
        mt.trial_id,
        mt.account_id,
        mt.started_at,
        mt.ends_at,
        mt.converted_at,
        mt.employee_count,
        mt.acquisition_channel,
        c.q1,
        c.q2,
        c.q3
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
            WHEN first_value_at IS NULL THEN 'Milestone not reached'
            WHEN first_value_at - started_at <= INTERVAL '1 day'
                THEN 'Within 1 day'
            WHEN first_value_at - started_at <= INTERVAL '3 days'
                THEN '1–3 days'
            WHEN first_value_at - started_at <= INTERVAL '7 days'
                THEN '3–7 days'
            ELSE 'Over 7 days'
        END AS time_to_first_value
    FROM trial_first_value
)
SELECT
    team_size_quartile,
    acquisition_channel,
    time_to_first_value,
    COUNT(*) AS ended_trials,
    COUNT(*) FILTER (WHERE first_value_at IS NOT NULL)
        AS trials_reaching_milestone,
    COUNT(*) FILTER (WHERE converted_at IS NOT NULL)
        AS converted_trials,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE converted_at IS NOT NULL)
        / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_pct,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (first_value_at - started_at)) / 86400.0),
        2
    ) AS avg_days_to_first_value
FROM bucketed
GROUP BY
    team_size_quartile,
    acquisition_channel,
    time_to_first_value
ORDER BY
    team_size_quartile,
    acquisition_channel,
    time_to_first_value;
```

### Output: Time to first `feature_use`

The “Milestone not reached” group has no qualifying `feature_use` event before conversion or trial end. Blank average-time values are NULL because no milestone time was observed.

| team_size_quartile | acquisition_channel | time_to_first_value | ended_trials | trials_reaching_milestone | converted_trials | conversion_pct | avg_days_to_first_value |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Q1 (smallest) | g2 | 3–7 days | 3 | 3 | 2 | 66.67 | 4.39 |
| Q1 (smallest) | g2 | Milestone not reached | 6 | 0 | 0 | 0 |  |
| Q1 (smallest) | g2 | Over 7 days | 3 | 3 | 2 | 66.67 | 10.66 |
| Q1 (smallest) | g2 | Within 1 day | 3 | 3 | 3 | 100 | 0.58 |
| Q1 (smallest) | linkedin | 1–3 days | 1 | 1 | 1 | 100 | 1.51 |
| Q1 (smallest) | linkedin | 3–7 days | 2 | 2 | 1 | 50 | 6.59 |
| Q1 (smallest) | linkedin | Milestone not reached | 4 | 0 | 2 | 50 |  |
| Q1 (smallest) | linkedin | Over 7 days | 1 | 1 | 0 | 0 | 7.22 |
| Q1 (smallest) | linkedin | Within 1 day | 1 | 1 | 0 | 0 | 0.33 |
| Q1 (smallest) | organic | 1–3 days | 4 | 4 | 2 | 50 | 2.32 |
| Q1 (smallest) | organic | 3–7 days | 3 | 3 | 2 | 66.67 | 4.41 |
| Q1 (smallest) | organic | Milestone not reached | 5 | 0 | 0 | 0 |  |
| Q1 (smallest) | outbound | 3–7 days | 3 | 3 | 2 | 66.67 | 4.9 |
| Q1 (smallest) | outbound | Milestone not reached | 11 | 0 | 7 | 63.64 |  |
| Q1 (smallest) | outbound | Within 1 day | 1 | 1 | 1 | 100 | 0.53 |
| Q1 (smallest) | referral | 1–3 days | 1 | 1 | 0 | 0 | 2.31 |
| Q1 (smallest) | referral | 3–7 days | 2 | 2 | 2 | 100 | 3.64 |
| Q1 (smallest) | referral | Milestone not reached | 5 | 0 | 1 | 20 |  |
| Q1 (smallest) | referral | Over 7 days | 3 | 3 | 0 | 0 | 11.12 |
| Q1 (smallest) | referral | Within 1 day | 1 | 1 | 1 | 100 | 0.37 |
| Q2 | g2 | 1–3 days | 5 | 5 | 3 | 60 | 2.32 |
| Q2 | g2 | 3–7 days | 3 | 3 | 2 | 66.67 | 5.44 |
| Q2 | g2 | Milestone not reached | 6 | 0 | 2 | 33.33 |  |
| Q2 | g2 | Over 7 days | 1 | 1 | 0 | 0 | 8.24 |
| Q2 | g2 | Within 1 day | 2 | 2 | 0 | 0 | 0.47 |
| Q2 | linkedin | 3–7 days | 2 | 2 | 1 | 50 | 5.54 |
| Q2 | linkedin | Milestone not reached | 6 | 0 | 3 | 50 |  |
| Q2 | linkedin | Over 7 days | 1 | 1 | 0 | 0 | 13.84 |
| Q2 | organic | 1–3 days | 2 | 2 | 2 | 100 | 2.38 |
| Q2 | organic | Milestone not reached | 9 | 0 | 7 | 77.78 |  |
| Q2 | organic | Over 7 days | 1 | 1 | 1 | 100 | 7.89 |
| Q2 | outbound | Milestone not reached | 4 | 0 | 2 | 50 |  |
| Q2 | outbound | Over 7 days | 4 | 4 | 0 | 0 | 11.26 |
| Q2 | outbound | Within 1 day | 1 | 1 | 0 | 0 | 0.38 |
| Q2 | referral | 3–7 days | 3 | 3 | 2 | 66.67 | 4.5 |
| Q2 | referral | Milestone not reached | 9 | 0 | 4 | 44.44 |  |
| Q2 | referral | Over 7 days | 2 | 2 | 1 | 50 | 9.15 |
| Q2 | referral | Within 1 day | 1 | 1 | 1 | 100 | 0.55 |
| Q3 | g2 | 1–3 days | 1 | 1 | 0 | 0 | 1.87 |
| Q3 | g2 | 3–7 days | 1 | 1 | 0 | 0 | 6.56 |
| Q3 | g2 | Milestone not reached | 7 | 0 | 3 | 42.86 |  |
| Q3 | g2 | Over 7 days | 2 | 2 | 1 | 50 | 8.83 |
| Q3 | linkedin | 1–3 days | 1 | 1 | 1 | 100 | 2.54 |
| Q3 | linkedin | 3–7 days | 1 | 1 | 0 | 0 | 4.34 |
| Q3 | linkedin | Milestone not reached | 5 | 0 | 2 | 40 |  |
| Q3 | linkedin | Over 7 days | 2 | 2 | 1 | 50 | 8.6 |
| Q3 | linkedin | Within 1 day | 2 | 2 | 0 | 0 | 0.53 |
| Q3 | organic | 1–3 days | 1 | 1 | 0 | 0 | 1.7 |
| Q3 | organic | Milestone not reached | 15 | 0 | 6 | 40 |  |
| Q3 | organic | Over 7 days | 1 | 1 | 0 | 0 | 9.5 |
| Q3 | organic | Within 1 day | 1 | 1 | 1 | 100 | 0.57 |
| Q3 | outbound | 1–3 days | 1 | 1 | 1 | 100 | 1.25 |
| Q3 | outbound | 3–7 days | 1 | 1 | 1 | 100 | 6.59 |
| Q3 | outbound | Milestone not reached | 7 | 0 | 0 | 0 |  |
| Q3 | outbound | Over 7 days | 3 | 3 | 0 | 0 | 10.95 |
| Q3 | referral | 1–3 days | 1 | 1 | 0 | 0 | 1.69 |
| Q3 | referral | 3–7 days | 1 | 1 | 0 | 0 | 4.71 |
| Q3 | referral | Milestone not reached | 6 | 0 | 3 | 50 |  |
| Q3 | referral | Over 7 days | 2 | 2 | 1 | 50 | 10.06 |
| Q4 (largest) | g2 | 3–7 days | 2 | 2 | 0 | 0 | 3.97 |
| Q4 (largest) | g2 | Milestone not reached | 11 | 0 | 4 | 36.36 |  |
| Q4 (largest) | g2 | Over 7 days | 5 | 5 | 3 | 60 | 9.52 |
| Q4 (largest) | linkedin | 1–3 days | 1 | 1 | 1 | 100 | 1.06 |
| Q4 (largest) | linkedin | 3–7 days | 3 | 3 | 0 | 0 | 3.73 |
| Q4 (largest) | linkedin | Milestone not reached | 5 | 0 | 3 | 60 |  |
| Q4 (largest) | linkedin | Within 1 day | 1 | 1 | 1 | 100 | 0.64 |
| Q4 (largest) | organic | 1–3 days | 1 | 1 | 0 | 0 | 2.54 |
| Q4 (largest) | organic | 3–7 days | 1 | 1 | 1 | 100 | 5.24 |
| Q4 (largest) | organic | Milestone not reached | 5 | 0 | 3 | 60 |  |
| Q4 (largest) | organic | Over 7 days | 1 | 1 | 0 | 0 | 9.54 |
| Q4 (largest) | organic | Within 1 day | 1 | 1 | 1 | 100 | 0.69 |
| Q4 (largest) | outbound | 1–3 days | 1 | 1 | 0 | 0 | 2.39 |
| Q4 (largest) | outbound | 3–7 days | 3 | 3 | 2 | 66.67 | 5.8 |
| Q4 (largest) | outbound | Milestone not reached | 5 | 0 | 2 | 40 |  |
| Q4 (largest) | outbound | Over 7 days | 3 | 3 | 1 | 33.33 | 10.71 |
| Q4 (largest) | outbound | Within 1 day | 1 | 1 | 1 | 100 | 0.46 |
| Q4 (largest) | referral | Milestone not reached | 9 | 0 | 7 | 77.78 |  |
| Q4 (largest) | referral | Over 7 days | 3 | 3 | 2 | 66.67 | 9.08 |
| Q4 (largest) | referral | Within 1 day | 1 | 1 | 0 | 0 | 1 |