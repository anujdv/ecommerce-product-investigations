## Number of Purchases per category

```sql
SELECT
	c.category_name,
	count(distinct o.order_id) as orders
from
	ecom.orders o join ecom.order_items oi on o.order_id = oi.order_id 
	JOIN ecom.product_variants pv on oi.variant_id = pv.variant_id
	join ecom.products p on p.product_id = pv.product_id
	JOIN ecom.categories c on p.category_id = c.category_id
group by 
	c.category_name
```

| category_name | orders |
| --- | --- |
| Accessories | 5,816 |
| Bedding | 4,815 |
| Decor | 5,680 |
| Haircare | 5,740 |
| Headphones | 5,642 |
| Jackets | 5,476 |
| Jeans | 5,440 |
| Kitchen | 5,485 |
| Makeup | 5,352 |
| Shoes | 5,869 |
| Skincare | 6,127 |
| Smartwatch | 5,310 |
| Speakers | 5,155 |
| Tops | 5,521 |

---

## Views per category

```sql
select
	c.category_name,
	count(*) as views
from
	ecom.orders o join ecom.sessions s on o.session_id = s.session_id 
	join ecom.session_events se on s.session_id = se.session_id
	join ecom.order_items oi on o.order_id = oi.order_id 
	JOIN ecom.product_variants pv on oi.variant_id = pv.variant_id
	join ecom.products p on p.product_id = pv.product_id
	JOIN ecom.categories c on p.category_id = c.category_id
	and se.event_type = 'product_view'
group BY
	c.category_name;
```

| category_name | views |
| --- | --- |
| Accessories | 14,214 |
| Bedding | 11,826 |
| Decor | 14,033 |
| Haircare | 14,769 |
| Headphones | 14,175 |
| Jackets | 13,771 |
| Jeans | 13,777 |
| Kitchen | 13,525 |
| Makeup | 12,930 |
| Shoes | 14,855 |
| Skincare | 15,075 |
| Smartwatch | 13,211 |
| Speakers | 12,856 |
| Tops | 14,069 |

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
