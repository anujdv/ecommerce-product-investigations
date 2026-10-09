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

**Hypothesis**  
- New Customer / Window Shopper → coupons should increase demand.  
- At Risk / Churned → coupons should re‑activate disengaged customers.  
- Active Buyer / Champion / Loyal / Premium / Big Spender → high risk of cannibalization.  
- Coupon Hunter → only buys with coupons, almost pure cannibalization.

---

## 2. Coupon Redemption Rate by Segment

Querying orders → customers → segment memberships → segments:

```sql
SELECT
	cs.segment_name,
	count(*) filter (WHERE o.applied_coupon_id IS NOT NULL) as orders_with_coupons,
	count(distinct o.order_id) as total_orders,
	round((100.0*(count(*) filter (WHERE o.applied_coupon_id IS NOT NULL)) / count(distinct o.order_id)),2) as coupon_redemption_rate
FROM
	ecom.orders o join ecom.customers c on o.customer_id = c.customer_id
	join ecom.segment_memberships sm on c.customer_id = sm.customer_id
	AND o.created_at >= sm.valid_from
    AND (sm.valid_to IS NULL OR o.created_at <= sm.valid_to)
	join ecom.customer_segments cs on sm.segment_id = cs.segment_id
group BY
	cs.segment_name
order by 
	coupon_redemption_rate;
```

| segment_name   | orders_with_coupons | total_orders | coupon_redemption_rate |
|----------------|----------------------|--------------|------------------------|
| New Customer   | 63                   | 309          | 20.39                  |
| Big Spender    | 105                  | 470          | 22.34                  |
| Champion       | 93                   | 409          | 22.74                  |
| Window Shopper | 81                   | 340          | 23.82                  |
| Active Buyer   | 81                   | 339          | 23.89                  |
| At Risk        | 100                  | 418          | 23.92                  |
| Churned        | 107                  | 436          | 24.54                  |
| Coupon Hunter  | 96                   | 384          | 25.00                  |
| Loyal          | 105                  | 417          | 25.18                  |
| Premium        | 91                   | 359          | 25.35                  |

**Observation**: Redemption rates are fairly uniform (~20–25%) across all segments.  
This suggests coupons are being used broadly, not strategically.

---

## 3. Rolling Up into Meta‑Groups

I collapsed the 10 segments into two meta‑groups:

- **Incremental** → New, Window Shopper, At Risk, Churned  
- **Cannibalization** → Active Buyer, Loyal, Champion, Big Spender, Premium, Coupon Hunter


```sql
SELECT
    CASE 
        WHEN cs.segment_name IN ('New Customer','Window Shopper','At Risk','Churned')
            THEN 'Incremental'
        WHEN cs.segment_name IN ('Active Buyer','Loyal','Champion','Big Spender','Premium','Coupon Hunter')
            THEN 'Cannibalization'
    END AS meta_group,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS orders_with_coupons,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) 
        / NULLIF(COUNT(DISTINCT o.order_id),0), 2
    ) AS coupon_redemption_rate
FROM ecom.orders o
JOIN ecom.customers c 
    ON o.customer_id = c.customer_id
JOIN ecom.segment_memberships sm 
    ON c.customer_id = sm.customer_id
    AND o.created_at >= sm.valid_from
    AND (sm.valid_to IS NULL OR o.created_at <= sm.valid_to)
JOIN ecom.customer_segments cs 
    ON sm.segment_id = cs.segment_id
GROUP BY meta_group;

```

| meta_group      | orders_with_coupons | total_orders | coupon_redemption_rate |
|-----------------|----------------------|--------------|------------------------|
| Cannibalization | 571                  | 2,348        | 24.32                  |
| Incremental     | 351                  | 1,485        | 23.64                  |

**Observation**: Redemption rates are nearly identical (~24%).  
Volume split: 62% cannibalization vs 38% incremental.

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

| meta_group      | avg_coupon_order_value | avg_non_coupon_order_value | coupon_orders | non_coupon_orders |
|-----------------|------------------------|----------------------------|---------------|-------------------|
| Cannibalization | 7,041.52               | 7,280.31                   | 571           | 1,807             |
| Incremental     | 6,853.54               | 7,855.72                   | 351           | 1,152             |

- **Cannibalization**: Coupon orders slightly lower than non‑coupon orders → margin erosion.  
- **Incremental-labeled segments**: Coupon orders have lower observed AOV, but this comparison does not establish that coupons caused additional orders. Segment membership is descriptive, not a randomized treatment or counterfactual.  

**Incrementality caveat and sensitivity**

The segment labels do not identify which coupon orders would not have happened without a discount. The earlier calculation of 351 × ₹6,853 (~₹2.4M) is gross coupon-order revenue, not incremental revenue or profit. Likewise, the cannibalization AOV gap is descriptive and cannot be called margin loss without cost and discount data.

Use scenario rates for the fraction of coupon orders that are truly incremental, and compare estimated incremental contribution against discount cost. Treat the result as a sensitivity range, not a point estimate. A causal estimate requires a holdout, randomized offer assignment, or a defensible matched/control design with pre-period covariates.

Illustrative revenue sensitivity for coupon orders in the Incremental-labeled segments (not a causal estimate or profit calculation):

```sql
WITH scenario_rates(incremental_share) AS (
    VALUES (0.00::numeric), (0.10), (0.25), (0.50), (0.75), (1.00)
),
incremental_labeled_coupon_orders AS (
    SELECT
        o.order_id,
        o.total
    FROM ecom.orders o
    JOIN ecom.customers c ON c.customer_id = o.customer_id
    JOIN ecom.segment_memberships sm
        ON sm.customer_id = c.customer_id
        AND o.created_at >= sm.valid_from
        AND (sm.valid_to IS NULL OR o.created_at <= sm.valid_to)
    JOIN ecom.customer_segments cs ON cs.segment_id = sm.segment_id
    WHERE o.applied_coupon_id IS NOT NULL
      AND cs.segment_name IN ('New Customer', 'Window Shopper', 'At Risk', 'Churned')
)
SELECT
    sr.incremental_share,
    COUNT(DISTINCT ic.order_id) AS coupon_orders,
    ROUND(SUM(ic.total), 2) AS observed_coupon_revenue,
    ROUND(sr.incremental_share * SUM(ic.total), 2) AS scenario_attributed_revenue
FROM incremental_labeled_coupon_orders ic
CROSS JOIN scenario_rates sr
GROUP BY sr.incremental_share
ORDER BY sr.incremental_share;
```

This applies an explicit share assumption to observed coupon revenue. It does not establish which orders were caused by the offer, does not subtract discount or product costs, and must not be labeled incremental profit.


---
## 5. Conclusion

Coupon redemptions are observed in both segment groups: 38% in segments labeled Incremental and 62% in those labeled Cannibalization. These labels describe the segmentation hypothesis; they do not prove causal lift or subsidy.

The available order-value summaries are insufficient to calculate incremental profit or margin impact. Treat business impact as unknown until a holdout or credible counterfactual is measured. Use the sensitivity analysis above to show how conclusions vary across plausible incrementality rates.

**Recommendation**: Tighten coupon targeting only after validating incremental contribution with a holdout or credible counterfactual, and account for discount cost and product margin.

---
## 6. Scope 2 Re-run: Coupon Performance at SKU Level

This extends Scope 2 from segment totals to item-level performance. It assumes the order-line table is `ecom.order_items` with `order_id`, `product_id`, `quantity`, and `unit_price`, and that `ecom.products` contains `product_id`, `sku`, and `product_name`. Confirm these names against the database schema before execution; adapt only the identifiers if the source uses different names.

```sql
WITH order_sku AS (
    SELECT
        oi.order_id,
        p.sku,
        p.product_name,
        SUM(oi.quantity) AS units,
        SUM(oi.quantity * oi.unit_price) AS sku_revenue
    FROM ecom.order_items oi
    JOIN ecom.products p ON p.product_id = oi.product_id
    GROUP BY oi.order_id, p.sku, p.product_name
)
SELECT
    os.sku,
    os.product_name,
    COUNT(DISTINCT os.order_id) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS coupon_orders,
    COUNT(DISTINCT os.order_id) FILTER (WHERE o.applied_coupon_id IS NULL) AS non_coupon_orders,
    SUM(os.units) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS coupon_units,
    SUM(os.units) FILTER (WHERE o.applied_coupon_id IS NULL) AS non_coupon_units,
    ROUND(AVG(os.sku_revenue) FILTER (WHERE o.applied_coupon_id IS NOT NULL), 2) AS avg_coupon_sku_revenue,
    ROUND(AVG(os.sku_revenue) FILTER (WHERE o.applied_coupon_id IS NULL), 2) AS avg_non_coupon_sku_revenue
FROM order_sku os
JOIN ecom.orders o ON o.order_id = os.order_id
GROUP BY os.sku, os.product_name
ORDER BY coupon_orders DESC, os.sku;
```

This compares item-level order incidence, units, and revenue descriptively. It does not estimate SKU-level causal lift; differences can reflect product mix, customer mix, or offer selection.

---

## 7. First-Time Coupon Leakage and Discount Type

The query below tests whether `WELCOME10`, `WELCOME15`, or `FIRSTBUY` were redeemed on a customer's first order. `ROW_NUMBER` ranks all customer orders chronologically before filtering to the target coupon codes, so later redemptions are correctly identified as repeat orders. Ties use `order_id` as a stable secondary key.

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
        ro.*,
        c.code AS coupon_code
    FROM ranked_orders ro
    JOIN ecom.coupons c ON c.coupon_id = ro.applied_coupon_id
    WHERE UPPER(c.code) IN ('WELCOME10', 'WELCOME15', 'FIRSTBUY')
)
SELECT
    coupon_code,
    COUNT(*) AS redemptions,
    COUNT(*) FILTER (WHERE customer_order_number = 1) AS first_order_redemptions,
    COUNT(*) FILTER (WHERE customer_order_number > 1) AS repeat_order_redemptions,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE customer_order_number > 1)
        / NULLIF(COUNT(*), 0), 2
    ) AS repeat_redemption_pct
FROM coupon_redemptions
GROUP BY coupon_code
ORDER BY coupon_code;
```

Discount-type performance uses order-level totals to avoid multiplying order revenue by the number of line items. This assumes `ecom.coupons.discount_type` and `ecom.coupons.code` exist, and that `orders.total` is the paid order total. Replace `orders.total` with the appropriate pre-discount subtotal if basket size should mean gross basket value.

```sql
SELECT
    c.discount_type,
    COUNT(*) AS coupon_orders,
    ROUND(AVG(o.total), 2) AS avg_paid_basket,
    ROUND(AVG(o.discount_amount), 2) AS avg_discount,
    ROUND(SUM(o.discount_amount), 2) AS total_discount
FROM ecom.orders o
JOIN ecom.coupons c ON c.coupon_id = o.applied_coupon_id
GROUP BY c.discount_type
ORDER BY total_discount DESC;
```

If `orders.discount_amount` is not present, remove those two discount expressions or join the recorded discount amount from its source table. Basket size and discount amount alone are not margin: estimating margin leakage requires item costs and the actual discount allocated to the order. Compare discount types within comparable customer, time, and product cohorts before treating differences as effects.
