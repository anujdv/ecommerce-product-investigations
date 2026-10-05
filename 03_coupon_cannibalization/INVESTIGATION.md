Here’s your investigation rewritten in the same **style and structure** as the uploaded file, so it looks consistent:

---

# Coupon Cannibalization Investigation

## Problem

The case asks: *Are discounts driving net‑new demand or subsidizing existing orders?*  
We need to settle the marketing vs finance debate by analyzing coupon redemption across customer segments.

---

## 1. Baseline Analysis

I started by mapping the relationships:

**Customers → Segment Memberships → Customer Segments**

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

| meta_group      | orders_with_coupons | total_orders | coupon_redemption_rate |
|-----------------|----------------------|--------------|------------------------|
| Cannibalization | 571                  | 2,348        | 24.32                  |
| Incremental     | 351                  | 1,485        | 23.64                  |

**Observation**: Redemption rates are nearly identical (~24%).  
Volume split: 62% cannibalization vs 38% incremental.

---

## 4. Net Impact Analysis

Comparing coupon vs non‑coupon orders:

| meta_group      | avg_coupon_order_value | avg_non_coupon_order_value | coupon_orders | non_coupon_orders |
|-----------------|------------------------|----------------------------|---------------|-------------------|
| Cannibalization | 7,041.52               | 7,280.31                   | 571           | 1,807             |
| Incremental     | 6,853.54               | 7,855.72                   | 351           | 1,152             |

- **Cannibalization**: Coupon orders slightly lower than non‑coupon orders → margin erosion.  
- **Incremental**: Coupon orders ~₹1,000 lower, but represent ~351 extra conversions → genuine growth.  

**Net Impact Calculation**  
\[
\text{Net Impact} = (\text{Incremental Orders Lift} \times \text{Avg Coupon Order Value}) - (\text{Cannibalization Orders} \times \text{AOV Difference})
\]

- Incremental lift = 351 × 6,853 ≈ **₹2.4M incremental revenue**  
- Cannibalization erosion = 571 × (7,280 – 7,041) ≈ **₹136K margin loss**  
- **Net positive impact ≈ ₹2.3M**

---

## 5. Conclusion

Coupon redemptions split into **Incremental demand (38%)** and **Cannibalization (62%)**.  
Coupons clearly drive net‑new orders in New, Window Shopper, At Risk, and Churned segments, but most redemptions occur in loyal or high‑value segments where they subsidize existing purchases.  

Overall, coupons deliver a **net positive impact** (~₹2.3M), but they are inefficiently targeted.  
To settle the marketing vs finance debate: *discounts do create new demand, yet they also erode margins in existing orders*.  

**Recommendation**: Tighten coupon targeting toward Incremental segments and reduce exposure in Cannibalization segments to maximize growth without unnecessary subsidy.

---

This version mirrors the **investigation style** of your uploaded file: structured sections (Problem → Baseline → Analysis → Roll‑up → Net Impact → Conclusion), clean tables, and concise interpretation. Would you like me to also add a **“Next Steps” section** (like in investigations) with actionable recommendations for marketing and finance?
