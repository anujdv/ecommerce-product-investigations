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

The event inventory showed `login`, `feature_use`, `dashboard_view`, `api_call`, `export`, `settings_change`, `invite_sent`, and `report_view`. `feature_use` was used as a broad working proxy for product value; `invite_sent` was compared as a collaboration milestone. The milestone query counts an event only if it occurred after trial start and before both trial end and conversion.

### SQL: Event inventory

```sql
SELECT
    event_type,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT account_id) AS accounts,
    MIN(occurred_at) AS first_seen_at,
    MAX(occurred_at) AS last_seen_at
FROM saas.events
GROUP BY event_type
ORDER BY event_rows DESC;
```

### Output: Event inventory

| event_type | event_rows | accounts | first_seen_at | last_seen_at |
| --- | ---: | ---: | --- | --- |
| login | 17,898 | 1,245 | Jan 1, 2024 6:13 AM | Mar 28, 2027 1:05 PM |
| feature_use | 10,891 | 1,221 | Jan 1, 2024 7:28 AM | Feb 22, 2027 6:13 PM |
| dashboard_view | 9,187 | 1,193 | Jan 1, 2024 12:23 AM | Jan 26, 2027 6:10 AM |
| api_call | 5,428 | 1,157 | Jan 1, 2024 12:05 PM | Dec 22, 2026 7:24 PM |
| export | 3,740 | 1,084 | Jan 1, 2024 3:59 AM | Nov 28, 2026 9:45 AM |
| settings_change | 2,753 | 1,032 | Jan 1, 2024 6:47 PM | Nov 28, 2026 7:56 AM |
| invite_sent | 2,344 | 1,020 | Jan 1, 2024 12:44 PM | Oct 16, 2026 5:04 AM |
| report_view | 1,293 | 430 | Dec 23, 2024 3:27 AM | Sep 12, 2026 11:15 AM |

### SQL: Compare first-value milestones

The complete grouped query is maintained in [04_compare_candidate_milestones.sql](queries/04_compare_candidate_milestones.sql). It compares `feature_use` and `invite_sent`, buckets first-event time as Within 1 day, 1–3 days, 3–7 days, Over 7 days, or Milestone not reached, and segments by channel and team-size quartile. Events must occur during the trial and before conversion.

### Output: Milestone summary

| milestone | trials_with_milestone | converted_with_milestone | conversion_with_milestone_pct | trials_without_milestone | converted_without_milestone | conversion_without_milestone_pct |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| feature_use | 110 | 52 | 47.3 | 140 | 61 | 43.6 |
| invite_sent | 22 | 8 | 36.4 | 228 | 105 | 46.1 |

For `feature_use`, the quartile counts (trials with event / conversions with event; trials without / conversions without) were Q1 32/19 and 31/10; Q2 28/13 and 34/18; Q3 22/7 and 40/14; Q4 28/13 and 35/19.

The result does not show a consistent pattern: in Q3, conversion was 31.8% with recorded feature use (7/22) and 35.0% without one (14/40). Many trials convert without a recorded `feature_use`, so this event alone does not identify activation reliably. Invitations appear too uncommon to serve as the primary first-value definition; sending one may be optional. Time-bucket-by-channel cells are small.

### SQL: Inspect feature IDs

```sql
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
```

Output was not included in the analysis results available for this investigation. Map these IDs through `saas.features` and confirm which represent core value before selecting an activation event.

---

## 5. Caveats and Next Step

- These are descriptive comparisons, not causal estimates. Channel, team size, and time-to-value can be related.
- Channel-by-quartile and time-bucket cells are small, making individual rates unstable.
- `employee_count` quartiles are relative to this ended-trial cohort, not standard company-size categories.
- “No recorded event” may mean missing instrumentation or an incomplete proxy, not necessarily no product value.
- The event inventory included timestamps through March 2027, later than the analysis date of October 2026. Confirm the event time range and data clock before using broad time-trend comparisons.

Next, validate which `feature_id` or event represents meaningful first value with the product definition, then rerun the time-to-value analysis against that milestone.

## Query Files

- [Trial conversion baseline](queries/01_trial_conversion_baseline.sql)
- [Event type inventory](queries/01_event_inventory.sql)
- [Conversion by channel and team-size quartile](queries/02_conversion_by_channel_and_team_size.sql)
- [Feature-use IDs](queries/03_event_inventory_for_first_value.sql)
- [Compare candidate first-value milestones](queries/04_compare_candidate_milestones.sql)
