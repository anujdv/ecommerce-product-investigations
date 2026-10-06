

Product views
session_events
    ↓
variant → product → category

Purchases
orders
    ↓
order_items
    ↓
variant → product → category



## 1. Category Purchase Baseline
I counted distinct orders containing at least one product from each category.
```sql
SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id) AS orders
FROM ecom.orders o
JOIN ecom.order_items oi
    ON o.order_id = oi.order_id
JOIN ecom.product_variants pv
    ON oi.variant_id = pv.variant_id
JOIN ecom.products p
    ON p.product_id = pv.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
WHERE o.created_at >= '2026-04-19'
GROUP BY
    c.category_name
ORDER BY
    orders DESC;
```
| category_name | orders |
| --- | --- |
| Skincare | 2,696 |
| Shoes | 2,627 |
| Haircare | 2,619 |
| Accessories | 2,529 |
| Decor | 2,502 |
| Headphones | 2,499 |
| Tops | 2,492 |
| Jeans | 2,447 |
| Jackets | 2,441 |
| Kitchen | 2,421 |
| Smartwatch | 2,356 |
| Makeup | 2,309 |
| Speakers | 2,307 |
| Bedding | 2,138 |

Date Alignment

The session_events table was instrumented starting April 19, 2026, while the orders table contains orders from an earlier period. Therefore, orders were restricted to:

created_at >= '2026-04-19'

This ensures that the purchase population is aligned with the period for which product-view events are available, allowing category view-share and purchase-share to be compared on a consistent time basis.

---

## 2. Category View Baseline

```sql
SELECT
    c.category_name,
    COUNT(*) AS views
FROM ecom.session_events se
JOIN ecom.product_variants pv
    ON se.variant_id = pv.variant_id
JOIN ecom.products p
    ON pv.product_id = p.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
WHERE se.event_type = 'product_view'
GROUP BY
    c.category_name
ORDER BY
    views DESC;
```

| category_name | views |
| --- | --- |
| Makeup | 18,046 |
| Jackets | 12,358 |
| Smartwatch | 11,878 |
| Jeans | 11,315 |
| Skincare | 11,243 |
| Haircare | 11,207 |
| Tops | 10,868 |
| Bedding | 10,422 |
| Decor | 10,340 |
| Accessories | 10,309 |
| Kitchen | 10,299 |
| Speakers | 10,169 |
| Shoes | 10,098 |
| Headphones | 9,889 |

## Views to purchase ratio

```sql
WITH views AS (
  SELECT 
    c.category_name,
    COUNT(*) AS view_count
  FROM ecom.session_events se
  JOIN ecom.sessions s ON se.session_id = s.session_id
  JOIN ecom.product_variants pv ON se.variant_id = pv.variant_id
  JOIN ecom.products p ON pv.product_id = p.product_id
  JOIN ecom.categories c ON p.category_id = c.category_id
  WHERE se.event_type = 'product_view'
  GROUP BY c.category_name
),
orders AS (
  SELECT 
    c.category_name,
    COUNT(DISTINCT o.order_id) AS order_count
  FROM ecom.orders o
  JOIN ecom.order_items oi ON o.order_id = oi.order_id
  JOIN ecom.product_variants pv ON oi.variant_id = pv.variant_id
  JOIN ecom.products p ON pv.product_id = p.product_id
  JOIN ecom.categories c ON p.category_id = c.category_id
  GROUP BY c.category_name
),
totals AS (
  SELECT 
    (SELECT SUM(view_count) FROM views) AS total_views,
    (SELECT SUM(order_count) FROM orders) AS total_orders
)

SELECT 
  v.category_name,
  v.view_count,
  o.order_count,
  ROUND(100.0 * v.view_count / t.total_views, 2) AS view_share_pct,
  ROUND(100.0 * o.order_count / t.total_orders, 2) AS purchase_share_pct,
  ROUND(
    (1.0 * v.view_count / t.total_views) / NULLIF(1.0 * o.order_count / t.total_orders,0),
    2
  ) AS view_to_purchase_ratio
FROM views v
LEFT JOIN orders o ON v.category_name = o.category_name
CROSS JOIN totals t
ORDER BY view_to_purchase_ratio DESC;
```

| category_name | view_count | order_count | view_share_pct | purchase_share_pct | view_to_purchase_ratio |
| --- | --- | --- | --- | --- | --- |
| Makeup | 18,041 | 5,352 | 11.39 | 6.91 | 1.65 |
| Jackets | 12,350 | 5,476 | 7.8 | 7.07 | 1.1 |
| Smartwatch | 11,874 | 5,310 | 7.5 | 6.86 | 1.09 |
| Bedding | 10,419 | 4,815 | 6.58 | 6.22 | 1.06 |
| Jeans | 11,311 | 5,440 | 7.14 | 7.03 | 1.02 |
| Speakers | 10,166 | 5,155 | 6.42 | 6.66 | 0.96 |
| Tops | 10,862 | 5,521 | 6.86 | 7.13 | 0.96 |
| Haircare | 11,206 | 5,740 | 7.08 | 7.41 | 0.95 |
| Kitchen | 10,296 | 5,485 | 6.5 | 7.08 | 0.92 |
| Skincare | 11,234 | 6,127 | 7.09 | 7.91 | 0.9 |
| Decor | 10,336 | 5,680 | 6.53 | 7.34 | 0.89 |
| Accessories | 10,306 | 5,816 | 6.51 | 7.51 | 0.87 |
| Headphones | 9,885 | 5,642 | 6.24 | 7.29 | 0.86 |
| Shoes | 10,095 | 5,869 | 6.37 | 7.58 | 0.84 |

## Observations

- **No category exhibits the 3–5x paradox** at the **category level**.
- Ratios are clustered around **0.8–1.6**, suggesting **balanced funnel performance**.
- Makeup shows the highest gap (1.65x), but still below the paradox threshold.
