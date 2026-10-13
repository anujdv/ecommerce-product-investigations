# Trial→Paid Conversion Bleed (SaaS)

## Central Question

Why do about 60% of SaaS trials end without converting to a paid subscription?

Segment trial-to-paid conversion by acquisition channel, account team size, and time to first value.

---

## 1. Baseline

A trial is counted as mature when `ends_at < CURRENT_TIMESTAMP`. A mature trial is converted when `converted_at` is populated.

| ended_trials | converted_trials | not_converted_trials | conversion_pct | dropoff_pct |
| ---: | ---: | ---: | ---: | ---: |
| 250 | 113 | 137 | 45.20 | 54.80 |

The observed drop-off is 54.8%, 5.2 percentage points below the approximate 60% in the central question. This is close, but the exact rate depends on the trial maturity and conversion definitions.

---

## 2. Conversion by Acquisition Channel

Channel is taken from `saas.accounts.acquisition_channel`.

| acquisition_channel | ended_trials | converted_trials | not_converted_trials | conversion_pct |
| --- | ---: | ---: | ---: | ---: |
| organic | 51 | 26 | 25 | 50.98 |
| referral | 50 | 25 | 25 | 50.00 |
| linkedin | 39 | 17 | 22 | 43.59 |
| outbound | 49 | 20 | 29 | 40.82 |
| g2 | 61 | 25 | 36 | 40.98 |

Organic and referral show the highest observed conversion rates; outbound and G2 are lowest. Channel cohorts contain 39–61 trials each, so differences are directional rather than conclusive.

---

## 3. Conversion by Team Size

Team size uses `saas.accounts.employee_count`. To avoid inventing fixed company-size bands, ended trials were divided into four employee-count quartiles. The interpolated cutoffs were Q1 = 97, Q2 = 291.5, and Q3 = 790.75 employees. Tied values stay in the same quartile, so group counts can differ slightly.

| team_size_quartile | employee_count_range | ended_trials | converted_trials | not_converted_trials | conversion_pct |
| --- | ---: | ---: | ---: | ---: | ---: |
| Q1 (smallest) | 6–96 | 63 | 29 | 34 | 46.03 |
| Q2 | 100–290 | 62 | 31 | 31 | 50.00 |
| Q3 | 293–775 | 62 | 21 | 41 | 33.87 |
| Q4 (largest) | 796–4,985 | 63 | 32 | 31 | 50.79 |

Q3 is the low-conversion quartile at 33.9%, while the largest-account quartile converts at 50.8%. The pattern is not a steady increase or decrease with team size, so it does not support a simple “larger teams convert less” conclusion.

### Channel mix within quartiles

| team_size_quartile | channel | ended_trials | converted_trials | conversion_pct |
| --- | --- | ---: | ---: | ---: |
| Q1 (smallest) | g2 | 15 | 7 | 46.67 |
| Q1 (smallest) | linkedin | 9 | 4 | 44.44 |
| Q1 (smallest) | organic | 12 | 4 | 33.33 |
| Q1 (smallest) | outbound | 15 | 10 | 66.67 |
| Q1 (smallest) | referral | 12 | 4 | 33.33 |
| Q2 | g2 | 17 | 7 | 41.18 |
| Q2 | linkedin | 9 | 4 | 44.44 |
| Q2 | organic | 12 | 10 | 83.33 |
| Q2 | outbound | 9 | 2 | 22.22 |
| Q2 | referral | 15 | 8 | 53.33 |
| Q3 | g2 | 11 | 4 | 36.36 |
| Q3 | linkedin | 11 | 4 | 36.36 |
| Q3 | organic | 18 | 7 | 38.89 |
| Q3 | outbound | 12 | 2 | 16.67 |
| Q3 | referral | 10 | 4 | 40.00 |
| Q4 (largest) | g2 | 18 | 7 | 38.89 |
| Q4 (largest) | linkedin | 10 | 5 | 50.00 |
| Q4 (largest) | organic | 9 | 5 | 55.56 |
| Q4 (largest) | outbound | 13 | 6 | 46.15 |
| Q4 (largest) | referral | 13 | 9 | 69.23 |

Q3 has a low rate across all channels, especially outbound (2/12, 16.7%). Its largest channel by trial count is organic (18/62); organic conversion there is 38.9%. This suggests channel mix alone does not account for Q3's lower rate. Individual cells are small (9–18 trials), so these are leads for follow-up.

---

## 4. Time to First Value

The event inventory showed `login`, `feature_use`, `dashboard_view`, `api_call`, `export`, `settings_change`, `invite_sent`, and `report_view`. `feature_use` was used as a broad working proxy for product value; `invite_sent` was compared as a collaboration milestone. The SQL counts an event only if it occurred after trial start and before both the trial end and conversion.

### Feature use

Across the 250 ended trials, 110 (44%) had a recorded pre-conversion `feature_use`; 52 converted (47.3%). Of the 140 without a recorded event, 61 converted (43.6%). The overall difference is small and is not consistent across team-size quartiles:

| team_size_quartile | trials_with_feature_use | converted_with_feature_use | trials_without_feature_use | converted_without_feature_use |
| --- | ---: | ---: | ---: | ---: |
| Q1 (smallest) | 32 | 19 | 31 | 10 |
| Q2 | 28 | 13 | 34 | 18 |
| Q3 | 22 | 7 | 40 | 14 |
| Q4 (largest) | 28 | 13 | 35 | 19 |

In Q3, conversion is 31.8% with a recorded feature use (7/22) and 35.0% without one (14/40). Many trials convert without a recorded `feature_use`, so this event alone does not identify activation reliably. Time-bucket-by-channel cells are small and do not show a consistent pattern.

### Invite sent

Only 22 of 250 trials (8.8%) had a pre-conversion `invite_sent`. Eight converted (36.4%), compared with 105 of the 228 trials without a recorded invite (46.1%). Invitations appear too uncommon to serve as the primary first-value definition; sending one may be optional.

### Interpretation

The current event fields do not establish a reliable “aha moment.” Conversion does not consistently rise with earlier or recorded `feature_use`, and most trials have no `invite_sent`. Inspect `feature_id` and event properties with product context to identify a specific core action, then remeasure time from `trials.started_at` to that action.

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
