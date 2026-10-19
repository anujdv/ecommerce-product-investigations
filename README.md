# Ecommerce Product Investigations

Four completed investigations covering revenue reliability, product conversion, coupon use, and trial conversion. The verdicts below separate observed patterns from causes that remain unproven.

## Executive verdicts

- **[Scope 1 — Revenue cliff](01_revenue_cliff/INVESTIGATION.md):** May 13 paid revenue fell 62.9%; the incident coincided with a cross-gateway `GATEWAY_TIMEOUT` spike concentrated in UPI, while the underlying shared technical failure remains unconfirmed.
- **[Scope 2 — High views, low conversion](02_high_views_low_conversion/INVESTIGATION.md):** No category has the hypothesized 3–5× imbalance; selected high-view products underperform category peers, with the two Makeup SKUs at 4.6–5.2% cart-to-purchase versus 49.9% for peers. The cause remains unproven.
- **[Scope 3 — Coupon cannibalization](03_coupon_cannibalization/INVESTIGATION.md):** Correcting the join expanded matched orders from about 3.8k to 32,418; 76.94% of the audited first-time-code redemptions were repeat orders, but policy violations and incremental impact require confirmation.
- **[Scope 4 — Trial conversion bleed](04_trial_conversion_bleed/INVESTIGATION.md):** Mature-trial conversion is 45.2% (113/250), so 54.8% did not convert; channel and team-size patterns are descriptive; an activation or instrumentation gap is a working hypothesis, not a proven cause.

## KPI scorecard

| Scope | Anomaly | Cause | Impact | Action |
| --- | --- | --- | --- | --- |
| 1. Revenue cliff | Paid revenue down 62.9% on May 13; 141 paid orders | 134 orders were linked to `GATEWAY_TIMEOUT`; multiple UPI gateways were affected, but the shared technical cause is unknown | ₹8,66,262.50 in affected order value; not confirmed lost revenue | Alert on payment failure/error rates and surface payment-method fallback |
| 2. High views, low conversion | Makeup view-to-purchase ratio 1.70×; several high-traffic SKUs show much weaker funnel rates than peers | No single cause established; review comments suggest product-experience hypotheses | Specific product pages lose purchase share despite traffic; category-wide 3–5× paradox not present | Validate product-level review, return, and funnel evidence before changes |
| 3. Coupon cannibalization | 397/516 first-time-code redemptions (76.94%) were on repeat orders; WELCOME10 was 80.34% | Repeat use may conflict with offer eligibility, but repeat use alone is not a confirmed violation | Join correction increased matched-order coverage to 32,418; recorded discount/COGS limitations prevent profit claims | Confirm terms and flagged uses, then test incremental impact with a randomized holdout |
| 4. Trial conversion | 54.8% non-conversion among 250 mature trials | No causal driver established; `feature_use` and `invite_sent` are unvalidated/weak activation proxies | 137 trials did not convert; only 21 recorded `invite_sent` | Map feature IDs, validate a core-value event, and test a day-3 onboarding prompt |

## Scope links

1. [Revenue cliff](01_revenue_cliff/INVESTIGATION.md)
2. [High views, low conversion](02_high_views_low_conversion/INVESTIGATION.md)
3. [Coupon cannibalization](03_coupon_cannibalization/INVESTIGATION.md)
4. [Trial conversion bleed](04_trial_conversion_bleed/INVESTIGATION.md)
