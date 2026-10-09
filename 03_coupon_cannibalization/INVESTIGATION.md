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
meta_group	orders_with_coupons	total_orders	coupon_redemption_rate
Cannibalization	4,423	17,008	26.01
Incremental	2,883	11,820	24.39
<img width="353" height="70" alt="image" src="https://github.com/user-attachments/assets/ae2498a6-a946-4444-8851-a681616d4ae7" />


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
