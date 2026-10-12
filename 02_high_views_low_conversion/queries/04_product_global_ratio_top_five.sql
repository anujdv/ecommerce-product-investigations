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
totals AS (
    SELECT
        (SELECT SUM(view_count) FROM views) AS total_views,
        (SELECT SUM(order_count) FROM orders) AS total_orders
),
product_analysis AS (
    SELECT
        v.category_name,
        v.product_id,
        v.product_name,
        v.view_count,
        COALESCE(o.order_count, 0) AS order_count,
        ROUND(100.0 * v.view_count / t.total_views, 2) AS view_share_pct,
        ROUND(100.0 * COALESCE(o.order_count, 0) / t.total_orders, 2) AS purchase_share_pct,
        ROUND(
            (1.0 * v.view_count / t.total_views)
            / NULLIF(1.0 * COALESCE(o.order_count, 0) / t.total_orders, 0),
            2
        ) AS view_to_purchase_ratio
    FROM views v
    LEFT JOIN orders o
        ON v.product_id = o.product_id
    CROSS JOIN totals t
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
    view_share_pct,
    purchase_share_pct,
    view_to_purchase_ratio
FROM ranked_products
WHERE category_rank <= 5
ORDER BY category_name, category_rank;
