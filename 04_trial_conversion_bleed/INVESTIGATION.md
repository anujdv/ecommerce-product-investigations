# Trial Conversion Bleed Investigation

## Problem

The case asks: *Where are eligible trial users dropping out before becoming paying customers, and is the loss concentrated in a particular acquisition source, cohort, or point in the journey?*

A low trial-to-paid rate can reflect a real conversion problem, but it can also result from incomplete observation windows, duplicate events, or a mismatch between product events and billing records. This investigation starts by establishing what the event and order data can support before attributing the gap to a product or marketing cause.

---

## 1. Baseline Analysis

First inventory the event types and their coverage over time. This establishes which trial and conversion milestones are actually recorded in `ecom.session_events` before defining the funnel.

Run the starter query in [`queries/01_event_inventory.sql`](queries/01_event_inventory.sql).

### Questions to answer

- Which event names represent a trial start, activation, checkout, and successful paid conversion?
- Are event volumes complete and stable over the selected period?
- Do trial events carry a stable customer or account identifier, or only a session identifier?
- Can successful payment be joined to `ecom.orders` without counting failed or duplicate attempts?

Do not assume that an event named `purchase` means a trial converted. Confirm its semantics against paid orders.

---

## 2. Define the Eligible Trial Cohort

After validating event names and identifiers, define one trial start per customer (or account, if that is the product's billing unit). Keep the earliest valid start timestamp and retain the acquisition source and campaign captured at that time.

Set a cohort window long enough for the trial plus the normal billing delay to elapse. Exclude recent starts that have not had a full opportunity to convert, and report the excluded count separately.

### Checks

- Deduplicate retries or repeated trial-start events.
- Confirm whether cancelled and reactivated trials count as new starts.
- Check for existing paid customers entering a trial.
- Compare event-based trial starts with any trial/subscription records available in the schema.
- Keep unknown or missing acquisition attribution as an explicit group.

---

## 3. Measure Trial-to-Paid Conversion

For each mature start cohort, calculate conversion at defined elapsed intervals (for example, by the end of the trial and within 7 and 30 days after start). Count a customer/account at most once per interval.

Report both the numerator and denominator with the rate. Break results down by start week and acquisition source, but suppress or flag small cohorts. Use successful paid status rather than order creation alone; separate payment failures from users who never attempted payment.

The core metric is:

`trial-to-paid conversion = distinct eligible trial accounts with a successful paid conversion / distinct eligible trial accounts`

If the dataset does not expose a billing or subscription identifier, document the proxy used and the risk of misattribution.

---

## 4. Locate the Drop-Off

Once the cohort definition is stable, compare distinct accounts reaching each validated milestone:

1. trial started
2. product activated or first meaningful use
3. checkout or payment initiated
4. successful payment

For each transition, show the absolute count, step conversion rate, and elapsed time to the next milestone. Distinguish a missing event from a confirmed failure. If events are session-scoped, avoid joining a conversion to a trial solely because it happened in the same session when users can return in later sessions.

---

## 5. Segment and Diagnose

Compare mature cohorts by acquisition source, campaign, device, geography, and start week only where those fields are present and consistently populated. Check whether gaps persist after controlling for cohort age and source mix.

Potential explanations to test include activation friction, trial limits, pricing or plan fit, payment failures, and differences in the quality of acquired users. These are hypotheses; descriptive differences alone do not establish cause.

---

## 6. Limitations and Next Steps

- Event names and semantics must be verified before a funnel can be interpreted.
- Recent cohorts are right-censored and should not be compared with fully mature cohorts.
- A session event may not identify a person or subscription across sessions and devices.
- Orders may include non-subscription purchases; joining them without a product or billing key can overstate conversion.
- Observational segment comparisons identify where to investigate, not why conversion changed.

If a specific milestone shows a stable, material drop, inspect the underlying sessions and payment outcomes. To estimate the impact of a proposed onboarding, pricing, or trial change, use a randomized experiment with conversion and retention guardrails.
