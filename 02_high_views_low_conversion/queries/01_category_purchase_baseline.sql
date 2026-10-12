-- Category purchase baseline
-- Source: 02_high_views_low_conversion/investigation.md

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
