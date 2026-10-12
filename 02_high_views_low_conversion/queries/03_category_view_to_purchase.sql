-- Category view-to-purchase analysis
-- Source: 02_high_views_low_conversion/investigation.md

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
