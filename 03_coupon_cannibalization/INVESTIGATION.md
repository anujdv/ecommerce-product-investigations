# Coupon Cannibalization Investigation

## Problem

The case asks: *Are discounts driving net‑new demand or subsidizing existing orders?*  
We need to settle the marketing vs finance debate by analyzing coupon redemption across customer segments.

---

## 1. Baseline Analysis


I started by mapping the relationships:

**Customers → Segment Memberships → Customer Segments**

```sql
SELECT
	*
FROM
	ecom.customer_segments ;
```

The `customer_segments` table defines 10 segments:

| segment_id | segment_name   |
|------------|----------------|
| 1          | New Customer   |
| 2          | Active Buyer   |
| 3          | At Risk        |
| 4          | Churned        |
| 5          | Champion       |
| 6          | Loyal          |
| 7          | Big Spender    |
| 8          | Window Shopper |
| 9          | Coupon Hunter  |
| 10         | Premium        |

**Working hypotheses to test**  
- New Customer / Window Shopper → coupons should increase demand.  
- At Risk / Churned → coupons should re‑activate disengaged customers.  
- Active Buyer / Champion / Loyal / Premium / Big Spender → high risk of cannibalization.  
- Coupon Hunter → may be more promotion-responsive; redemption patterns alone cannot show whether coupons create or subsidize orders.

---

## 2. Coupon Redemption Rate by Segment

Querying orders → customers → segment memberships → segments:

```sql
SELECT
  cs.segment_name,
  count(*) FILTER (
    WHERE
      o.applied_coupon_id IS NOT NULL
  ) AS orders_with_coupons,
  count(DISTINCT o.order_id) AS total_orders,
  round(
    (
      100.0 * (
        count(*) FILTER (
          WHERE
            o.applied_coupon_id IS NOT NULL
        )
      ) / count(DISTINCT o.order_id)
    ),
    2
  ) AS coupon_redemption_rate
FROM
  ecom.orders o
  JOIN ecom.customers c ON o.customer_id = c.customer_id
  JOIN ecom.segment_memberships sm ON c.customer_id = sm.customer_id
  AND o.created_at >= sm.valid_from
  AND (
    sm.valid_to IS NULL
    OR o.created_at <= sm.valid_to
  )
  JOIN ecom.customer_segments cs ON sm.segment_id = cs.segment_id
GROUP BY
  cs.segment_name
ORDER BY
  coupon_redemption_rate;
```

| segment_name | orders_with_coupons | total_orders | coupon_redemption_rate |
| --- | --- | --- | --- |
| New Customer | 689 | 3,211 | 21.46 |
| Loyal | 748 | 3,433 | 21.79 |
| Big Spender | 646 | 2,936 | 22 |
| Coupon Hunter | 821 | 3,686 | 22.27 |
| At Risk | 678 | 3,041 | 22.3 |
| Active Buyer | 675 | 3,002 | 22.49 |
| Churned | 761 | 3,326 | 22.88 |
| Champion | 843 | 3,667 | 22.99 |
| Window Shopper | 755 | 3,278 | 23.03 |
| Premium | 690 | 2,838 | 24.31 |

**Observation**: Coupon redemption rates range from 21.46% to 24.31%, a spread of 2.85 percentage points. Premium is highest (24.31%) and New Customer is lowest (21.46%); most segments cluster around 22–23%. This indicates broad use with modest segment variation, not evidence that coupons create incremental demand.

---

## 3. Rolling Up into Meta‑Groups

I collapsed the 10 segments into two meta‑groups:

- **Incremental** → New, Window Shopper, At Risk, Churned  
- **Cannibalization** → Active Buyer, Loyal, Champion, Big Spender, Premium, Coupon Hunter


```sql
SELECT
    CASE
        WHEN cs.segment_name IN ('New Customer', 'Window Shopper', 'At Risk', 'Churned')
            THEN 'Incremental'
        WHEN cs.segment_name IN ('Active Buyer', 'Loyal', 'Champion', 'Big Spender', 'Premium', 'Coupon Hunter')
            THEN 'Cannibalization'
    END AS meta_group,
    COUNT(*) FILTER (
        WHERE o.applied_coupon_id IS NOT NULL
    ) AS orders_with_coupons,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE o.applied_coupon_id IS NOT NULL
        ) / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS coupon_redemption_rate
FROM ecom.orders o
JOIN ecom.customers c
    ON c.customer_id = o.customer_id
JOIN ecom.segment_memberships sm
    ON sm.customer_id = c.customer_id
    AND o.created_at >= sm.valid_from
    AND (sm.valid_to IS NULL OR o.created_at <= sm.valid_to)
JOIN ecom.customer_segments cs
    ON cs.segment_id = sm.segment_id
GROUP BY meta_group
ORDER BY meta_group;
```

| meta_group | orders_with_coupons | total_orders | coupon_redemption_rate |
| --- | --- | --- | --- |
| Cannibalization | 4,423 | 17,008 | 26.01 |
| Incremental | 2,883 | 11,820 | 24.39 |

**Observation**: The Cannibalization-labeled group redeems at 26.01%, versus 24.39% for the Incremental-labeled group, a 1.62 percentage-point difference. The groups account for 4,423 of 7,306 coupon orders (60.6%) and 2,883 (39.4%), respectively. These figures describe where redemptions occur; the group labels do not establish causal cannibalization or incrementality.



---

## 4. Net Impact Analysis

```sql
SELECT
    CASE 
        WHEN cs.segment_name IN ('New Customer','Window Shopper','At Risk','Churned')
            THEN 'Incremental'
        ELSE 'Cannibalization'
    END AS meta_group,
    AVG(o.total) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS avg_coupon_order_value,
    AVG(o.total) FILTER (WHERE o.applied_coupon_id IS NULL) AS avg_non_coupon_order_value,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS coupon_orders,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NULL) AS non_coupon_orders
FROM ecom.orders o
JOIN ecom.customers c ON o.customer_id = c.customer_id
JOIN ecom.segment_memberships sm ON c.customer_id = sm.customer_id
    AND o.created_at >= sm.valid_from
    AND (sm.valid_to IS NULL OR o.created_at <= sm.valid_to)
JOIN ecom.customer_segments cs ON sm.segment_id = cs.segment_id
GROUP BY meta_group;

```

Comparing coupon vs non‑coupon orders:

| meta_group | avg_coupon_order_value | avg_non_coupon_order_value | coupon_orders | non_coupon_orders |
| --- | --- | --- | --- | --- |
| Cannibalization | 7,266.73 | 7,503.58 | 4,423 | 15,139 |
| Incremental | 7,642.48 | 7,500.83 | 2,883 | 9,973 |

**Observation**: In the Cannibalization-labeled group, coupon orders average ₹7,266.73 versus ₹7,503.58 without coupons, a ₹236.85 (3.2%) lower observed order value. In the Incremental-labeled group, coupon orders average ₹7,642.48 versus ₹7,500.83 without coupons, a ₹141.65 (1.9%) higher observed order value. The query covers 4,423 coupon and 15,139 non-coupon orders in the Cannibalization-labeled group, and 2,883 coupon and 9,973 non-coupon orders in the Incremental-labeled group.

These are descriptive differences in paid order value. The higher average in Incremental-labeled segments is consistent with larger coupon baskets in this result, but it does not show that coupons caused additional orders. The lower average in Cannibalization-labeled segments does not establish margin erosion: order value is not profit, and the comparison does not control for customer, product, or offer selection.


---

## 5. First-Time Coupon Repeat Redemptions

This query ranks each customer's full order history before filtering to the first-time coupon codes, so an earlier non-coupon order is counted when deciding whether a redemption was on a repeat purchase.

```sql
WITH ranked_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.created_at,
        o.applied_coupon_id,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.created_at, o.order_id
        ) AS customer_order_number
    FROM ecom.orders o
),
target_redemptions AS (
    SELECT
        ro.order_id,
        ro.customer_id,
        ro.customer_order_number,
        c.code AS coupon_code
    FROM ranked_orders ro
    JOIN ecom.coupons c
        ON c.coupon_id = ro.applied_coupon_id
    WHERE UPPER(c.code) IN ('WELCOME10', 'WELCOME15', 'FIRSTBUY')
)
SELECT
    coupon_code,
    COUNT(*) AS redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number = 1
    ) AS first_order_redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number > 1
    ) AS repeat_order_redemptions,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE customer_order_number > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_redemption_pct
FROM target_redemptions
GROUP BY coupon_code
ORDER BY coupon_code;
```

| coupon_code | redemptions | first_order_redemptions | repeat_order_redemptions | repeat_redemption_pct |
| --- | ---: | ---: | ---: | ---: |
| FIRSTBUY | 171 | 43 | 128 | 74.85 |
| WELCOME10 | 178 | 35 | 143 | 80.34 |
| WELCOME15 | 167 | 41 | 126 | 75.45 |
| **Total** | **516** | **119** | **397** | **76.94** |

**Observation**: 397 of 516 redemptions (76.94%) occurred on repeat orders. WELCOME10 had the highest repeat-order rate (80.34%), followed by WELCOME15 (75.45%) and FIRSTBUY (74.85%). Repeat use is a signal to check eligibility, but it is not automatically a violation. Section 6 compares these redemptions with configured usage caps and validity dates.
---

## 6. Coupon Eligibility and Usage-Limit Check

This query checks the three first-time codes for repeat-order use, redemptions outside the configured validity dates, and redemptions beyond the overall or per-customer usage limits. It treats `ends_at` as inclusive; confirm that matches the promotion rules. Historical validity is evaluated from the order timestamp rather than the coupon's current `is_active` value.

```sql
WITH ranked_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.created_at,
        o.applied_coupon_id,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.created_at, o.order_id
        ) AS customer_order_number
    FROM ecom.orders o
),
coupon_redemptions AS (
    SELECT
        ro.order_id,
        ro.customer_id,
        ro.created_at,
        ro.customer_order_number,
        c.coupon_id,
        UPPER(c.code) AS coupon_code,
        c.max_uses,
        c.max_uses_per_customer,
        CASE
            WHEN c.starts_at IS NOT NULL
                 AND ro.created_at < c.starts_at THEN TRUE
            WHEN c.ends_at IS NOT NULL
                 AND ro.created_at > c.ends_at THEN TRUE
            ELSE FALSE
        END AS outside_valid_dates,
        ROW_NUMBER() OVER (
            PARTITION BY c.coupon_id
            ORDER BY ro.created_at, ro.order_id
        ) AS coupon_use_number,
        ROW_NUMBER() OVER (
            PARTITION BY c.coupon_id, ro.customer_id
            ORDER BY ro.created_at, ro.order_id
        ) AS customer_coupon_use_number
    FROM ranked_orders ro
    JOIN ecom.coupons c
        ON c.coupon_id = ro.applied_coupon_id
    WHERE UPPER(c.code) IN ('WELCOME10', 'WELCOME15', 'FIRSTBUY')
)
SELECT
    coupon_code,
    COUNT(*) AS redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number > 1
    ) AS repeat_order_redemptions,
    COUNT(*) FILTER (
        WHERE outside_valid_dates
    ) AS redemptions_outside_valid_dates,
    COUNT(*) FILTER (
        WHERE max_uses_per_customer IS NOT NULL
          AND customer_coupon_use_number > max_uses_per_customer
    ) AS redemptions_over_customer_limit,
    COUNT(DISTINCT customer_id) FILTER (
        WHERE max_uses_per_customer IS NOT NULL
          AND customer_coupon_use_number > max_uses_per_customer
    ) AS customers_over_customer_limit,
    COUNT(*) FILTER (
        WHERE max_uses IS NOT NULL
          AND coupon_use_number > max_uses
    ) AS redemptions_over_coupon_limit
FROM coupon_redemptions
GROUP BY coupon_code
ORDER BY coupon_code;
```

| coupon_code | redemptions | repeat_order_redemptions | redemptions_outside_valid_dates | redemptions_over_customer_limit | customers_over_customer_limit | redemptions_over_coupon_limit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| FIRSTBUY | 171 | 128 | 1 | 2 | 2 | 0 |
| WELCOME10 | 178 | 143 | 3 | 7 | 7 | 0 |
| WELCOME15 | 167 | 126 | 1 | 7 | 6 | 0 |

**Observation**: Across the three codes, 5 of 516 redemptions (0.97%) fell outside the configured validity dates, and 16 (3.10%) exceeded the per-customer cap. No redemptions exceeded the overall coupon-use caps. The per-code customer counts sum to 15 coupon-customer combinations; the same person may appear under more than one code. Repeat-order use remains high (397 of 516, 76.94%), but repeat use is only a violation if the offer terms require a customer's first-ever order. Confirm those terms and inspect the flagged orders before calling all repeat use leakage.

---

## 7. Coupon Type: Basket Size and Configured Discount

The coupon table contains `discount_type` and `discount_value`. The latter is the configured value, not necessarily the amount actually applied to an order. Its units can differ by discount type, so it should not be summed as discount cost.

```sql
SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(AVG(o.total), 2) AS avg_paid_basket,
    ROUND(AVG(c.discount_value), 2) AS avg_configured_discount_value
FROM ecom.orders AS o
JOIN ecom.coupons AS c
    ON c.coupon_id = o.applied_coupon_id
GROUP BY c.discount_type
ORDER BY coupon_orders DESC;
```

| discount_type | coupon_orders | avg_paid_basket | avg_configured_discount_value |
| --- | ---: | ---: | ---: |
| percent | 5,225 | ₹7,531.73 | 16.96 |
| fixed | 1,436 | ₹7,377.94 | 14.47 |
| free_shipping | 1,367 | ₹7,327.84 | 17.19 |
| BOGO | 913 | ₹7,665.64 | 16.21 |

**Observation**: Percent coupons account for the most coupon orders (5,225 of 8,941; 58.44%). BOGO orders have the highest average paid basket (₹7,665.64), while free-shipping orders have the lowest (₹7,327.84), a difference of ₹337.80 (about 4.61%). This is descriptive: it does not show that BOGO caused larger baskets, since customer and product mix may differ. The configured discount values are not realized discount amounts and may use different units, so these results cannot establish which type has the best margin impact.

**Next check**: The schema exposes realized order discounts in `orders.discount` and line-level discounts in `order_items.line_discount`. Use the first query to summarize recorded discount spend by coupon type, and the second to check whether the order and line totals reconcile. The percentage calculation assumes `orders.total` is the amount paid after discounts. Confirm that definition in the database.

```sql
SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(AVG(o.total), 2) AS avg_paid_basket,
    ROUND(AVG(o.discount), 2) AS avg_recorded_discount,
    ROUND(SUM(o.discount), 2) AS total_recorded_discount,
    COUNT(*) FILTER (WHERE o.discount IS NULL) AS orders_missing_discount,
    ROUND(
        100.0 * SUM(o.discount)
        / NULLIF(SUM(o.total + o.discount), 0),
        2
    ) AS recorded_discount_pct_of_pre_discount_value
FROM ecom.orders o
JOIN ecom.coupons c
    ON c.coupon_id = o.applied_coupon_id
GROUP BY c.discount_type
ORDER BY total_recorded_discount DESC;
```

Reconcile the recorded order discount to the sum of line discounts:

```sql
WITH line_discounts AS (
    SELECT
        oi.order_id,
        SUM(COALESCE(oi.line_discount, 0)) AS summed_line_discount
    FROM ecom.order_items oi
    GROUP BY oi.order_id
)
SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(SUM(COALESCE(o.discount, 0)), 2) AS order_discount_total,
    ROUND(SUM(COALESCE(ld.summed_line_discount, 0)), 2) AS line_discount_total,
    ROUND(
        SUM(COALESCE(o.discount, 0))
        - SUM(COALESCE(ld.summed_line_discount, 0)),
        2
    ) AS order_vs_line_difference,
    COUNT(*) FILTER (
        WHERE ABS(
            COALESCE(o.discount, 0)
            - COALESCE(ld.summed_line_discount, 0)
        ) > 0.01
    ) AS orders_with_difference
FROM ecom.orders o
JOIN ecom.coupons c
    ON c.coupon_id = o.applied_coupon_id
LEFT JOIN line_discounts ld
    ON ld.order_id = o.order_id
GROUP BY c.discount_type
ORDER BY c.discount_type;
```

The schema lookup did not find product unit cost or COGS fields. These queries can quantify and validate discount spend, but they cannot calculate margin without product costs. The available `prices.list_price` and `prices.sale_price` fields are selling prices, not product costs. A randomized holdout is still required to estimate whether discounts cause additional orders.
---

## 8. Conclusion

**Answer to the question:** The current analysis does not establish whether discounts are driving net-new demand or subsidizing orders that would have happened anyway. Coupon redemption is widespread. Coupon orders have a higher observed average order value in the Incremental-labeled segments (+1.9%) and a lower one in the Cannibalization-labeled segments (−3.2%), but these are uncontrolled comparisons of paid order value, not causal lift or profit.

The strongest operational signal is repeat use of the three first-time codes: 397 of 516 redemptions (76.94%) were on repeat orders. The eligibility check found 16 redemptions over per-customer limits, 5 outside configured validity dates, and none over overall use caps. Confirm whether the offers required a customer's first-ever order, and review the flagged redemptions; do not treat all repeat use as a confirmed violation.

Basket values also vary by coupon type, with BOGO orders highest and free-shipping orders lowest in this sample. These differences do not show which offer type is more profitable. The schema exposes recorded order and line discounts, but their totals still need to be summarized and reconciled; product costs were not found.

**Recommendation:** Do not claim that coupons are net-positive or that the full repeat-redemption share is leakage based on these results. First confirm offer eligibility and resolve the flagged exceptions. Then run a randomized coupon holdout and compare order rate and contribution per assigned customer after actual discounts and product costs, once product costs are available. That is the evidence needed to decide whether coupons create enough incremental demand to pay for the subsidy.
