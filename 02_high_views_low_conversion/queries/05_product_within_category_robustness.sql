-- Within-category robustness check
-- Source: 02_high_views_low_conversion/investigation.md

WITH views AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
        COUNT(*) AS view_count
    FROM ecom.session_events se
    JOIN ecom.product_variants pv
        ON se.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE se.event_type = 'product_view'
    GROUP BY c.category_name, p.product_id, p.product_name
),
orders AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
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
    GROUP BY c.category_name, p.product_id, p.product_name
),
product_data AS (
    SELECT
        v.category_name,
        v.product_id,
        v.product_name,
        v.view_count,
        COALESCE(o.order_count, 0) AS order_count
    FROM views v
    LEFT JOIN orders o
        ON v.product_id = o.product_id
),
category_totals AS (
    SELECT
        category_name,
        SUM(view_count) AS category_total_views,
        SUM(order_count) AS category_total_orders
    FROM product_data
    GROUP BY category_name
),
product_analysis AS (
    SELECT
        p.category_name,
        p.product_id,
        p.product_name,
        p.view_count,
        p.order_count,
        ROUND(100.0 * p.view_count / ct.category_total_views, 2) AS category_view_share_pct,
        ROUND(100.0 * p.order_count / NULLIF(ct.category_total_orders, 0), 2) AS category_purchase_share_pct,
        ROUND(
            (1.0 * p.view_count / ct.category_total_views)
            / NULLIF(1.0 * p.order_count / ct.category_total_orders, 0),
            2
        ) AS view_to_purchase_ratio
    FROM product_data p
    JOIN category_totals ct
        ON p.category_name = ct.category_name
),
ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category_name
            ORDER BY view_to_purchase_ratio DESC, view_count DESC
        ) AS category_rank
    FROM product_analysis
    WHERE view_count >= 100
)
SELECT
    category_name,
    category_rank,
    product_id,
    product_name,
    view_count,
    order_count,
    category_view_share_pct,
    category_purchase_share_pct,
    view_to_purchase_ratio
FROM ranked_products
WHERE category_rank <= 5
ORDER BY category_name, category_rank;
