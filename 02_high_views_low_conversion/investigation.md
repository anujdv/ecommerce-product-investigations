

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

## 3. Category View-to-Purchase Analysis

```sql
WITH views AS (
    SELECT
        c.category_name,
        COUNT(*) AS view_count
    FROM ecom.session_events se
    JOIN ecom.product_variants pv
        ON se.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE se.event_type = 'product_view'
    GROUP BY c.category_name
),

orders AS (
    SELECT
        c.category_name,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM ecom.orders o
    JOIN ecom.order_items oi
        ON o.order_id = oi.order_id
    JOIN ecom.product_variants pv
        ON oi.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE o.created_at >= '2026-04-19'
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

    ROUND(
        100.0 * v.view_count / t.total_views,
        2
    ) AS view_share_pct,

    ROUND(
        100.0 * o.order_count / t.total_orders,
        2
    ) AS purchase_share_pct,

    ROUND(
        (1.0 * v.view_count / t.total_views)
        /
        NULLIF(
            1.0 * o.order_count / t.total_orders,
            0
        ),
        2
    ) AS view_to_purchase_ratio

FROM views v
LEFT JOIN orders o
    ON v.category_name = o.category_name
CROSS JOIN totals t
ORDER BY view_to_purchase_ratio DESC;
```
| category_name | view_count | order_count | view_share_pct | purchase_share_pct | view_to_purchase_ratio |
| --- | --- | --- | --- | --- | --- |
| Makeup | 18,046 | 2,309 | 11.39 | 6.72 | 1.7 |
| Jackets | 12,358 | 2,441 | 7.8 | 7.1 | 1.1 |
| Smartwatch | 11,878 | 2,356 | 7.5 | 6.85 | 1.09 |
| Bedding | 10,422 | 2,138 | 6.58 | 6.22 | 1.06 |
| Jeans | 11,315 | 2,447 | 7.14 | 7.12 | 1 |
| Speakers | 10,169 | 2,307 | 6.42 | 6.71 | 0.96 |
| Tops | 10,868 | 2,492 | 6.86 | 7.25 | 0.95 |
| Haircare | 11,207 | 2,619 | 7.07 | 7.62 | 0.93 |
| Kitchen | 10,299 | 2,421 | 6.5 | 7.04 | 0.92 |
| Skincare | 11,243 | 2,696 | 7.1 | 7.84 | 0.9 |
| Decor | 10,340 | 2,502 | 6.53 | 7.28 | 0.9 |
| Accessories | 10,309 | 2,529 | 6.51 | 7.36 | 0.88 |
| Headphones | 9,889 | 2,499 | 6.24 | 7.27 | 0.86 |
| Shoes | 10,098 | 2,627 | 6.37 | 7.64 | 0.83 |

Findings

No category exhibits the hypothesized 3–5× high-view, low-purchase paradox.

Makeup is the strongest outlier, accounting for 11.39% of views but only 6.72% of purchases, resulting in a 1.70× view-to-purchase ratio.

Jackets (1.10×), Smartwatch (1.09×), and Bedding (1.06×) show only modest view-share overrepresentation.

Jeans is approximately balanced at 1.00×.

All remaining categories have ratios below 1.0×, indicating that their purchase share is equal to or greater than their view share.

