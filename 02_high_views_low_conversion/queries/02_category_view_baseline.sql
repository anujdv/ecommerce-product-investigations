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
