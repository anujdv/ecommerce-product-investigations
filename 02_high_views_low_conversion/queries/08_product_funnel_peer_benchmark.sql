WITH targets(product_id) AS (
    VALUES
        (801), (2883), (3257), (1048), (1273),
        (1227), (3002), (3921), (127), (1254)
),
target_categories AS (
    SELECT DISTINCT p.category_id
    FROM ecom.products p
    JOIN targets t ON p.product_id = t.product_id
),
product_views AS (
    SELECT
        se.session_id,
        se.product_id,
        MIN(se.occurred_at) AS first_view_at
    FROM ecom.session_events se
    JOIN ecom.products p ON se.product_id = p.product_id
    JOIN target_categories tc ON p.category_id = tc.category_id
    WHERE se.event_type = 'product_view'
      AND se.occurred_at >= DATE '2026-04-19'
    GROUP BY se.session_id, se.product_id
),
cart_events AS (
    SELECT session_id, product_id, occurred_at AS cart_at
    FROM ecom.session_events
    WHERE event_type = 'add_to_cart'
      AND product_id IS NOT NULL
),
purchase_products AS (
    SELECT
        se.session_id,
        pv.product_id,
        se.occurred_at AS purchase_at
    FROM ecom.session_events se
    JOIN ecom.order_items oi ON se.order_id = oi.order_id
    JOIN ecom.product_variants pv ON oi.variant_id = pv.variant_id
    WHERE se.event_type = 'purchase'
      AND se.order_id IS NOT NULL
),
view_cart_sessions AS (
    SELECT
        v.session_id,
        v.product_id,
        v.first_view_at,
        MIN(c.cart_at) AS first_cart_at
    FROM product_views v
    LEFT JOIN cart_events c
        ON c.session_id = v.session_id
       AND c.product_id = v.product_id
       AND c.cart_at >= v.first_view_at
    GROUP BY v.session_id, v.product_id, v.first_view_at
),
session_stages AS (
    SELECT
        vc.session_id,
        vc.product_id,
        vc.first_cart_at,
        MIN(
            CASE WHEN pp.purchase_at >= vc.first_view_at
                 THEN pp.purchase_at END
        ) AS purchase_after_view_at,
        MIN(
            CASE WHEN vc.first_cart_at IS NOT NULL
                   AND pp.purchase_at >= vc.first_cart_at
                 THEN pp.purchase_at END
        ) AS purchase_after_cart_at
    FROM view_cart_sessions vc
    LEFT JOIN purchase_products pp
        ON pp.session_id = vc.session_id
       AND pp.product_id = vc.product_id
    GROUP BY vc.session_id, vc.product_id, vc.first_cart_at
),
product_funnel AS (
    SELECT
        product_id,
        COUNT(*) AS viewed_sessions,
        SUM(CASE WHEN first_cart_at IS NOT NULL THEN 1 ELSE 0 END)
            AS cart_sessions,
        SUM(CASE WHEN purchase_after_view_at IS NOT NULL THEN 1 ELSE 0 END)
            AS purchase_sessions,
        SUM(CASE WHEN purchase_after_cart_at IS NOT NULL THEN 1 ELSE 0 END)
            AS purchases_after_cart
    FROM session_stages
    GROUP BY product_id
),
product_metrics AS (
    SELECT
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name,
        f.viewed_sessions,
        f.cart_sessions,
        f.purchase_sessions,
        f.purchases_after_cart,
        ROUND(
            100.0 * f.cart_sessions / NULLIF(f.viewed_sessions, 0), 2
        ) AS view_to_cart_pct,
        ROUND(
            100.0 * f.purchase_sessions / NULLIF(f.viewed_sessions, 0), 2
        ) AS view_to_purchase_pct,
        ROUND(
            100.0 * f.purchases_after_cart / NULLIF(f.cart_sessions, 0), 2
        ) AS cart_to_purchase_pct
    FROM product_funnel f
    JOIN ecom.products p ON f.product_id = p.product_id
    JOIN ecom.categories c ON p.category_id = c.category_id
    WHERE f.viewed_sessions >= 100
),
peer_benchmarks AS (
    SELECT
        pm.category_id,
        COUNT(*) AS peer_product_count,
        SUM(pm.viewed_sessions) AS peer_viewed_sessions,
        ROUND(
            100.0 * SUM(pm.cart_sessions)
            / NULLIF(SUM(pm.viewed_sessions), 0), 2
        ) AS peer_view_to_cart_pct,
        ROUND(
            100.0 * SUM(pm.purchase_sessions)
            / NULLIF(SUM(pm.viewed_sessions), 0), 2
        ) AS peer_view_to_purchase_pct,
        ROUND(
            100.0 * SUM(pm.purchases_after_cart)
            / NULLIF(SUM(pm.cart_sessions), 0), 2
        ) AS peer_cart_to_purchase_pct
    FROM product_metrics pm
    LEFT JOIN targets t ON pm.product_id = t.product_id
    WHERE t.product_id IS NULL
    GROUP BY pm.category_id
)
SELECT
    pm.category_name,
    pm.product_id,
    pm.product_name,
    pm.viewed_sessions,
    pm.cart_sessions,
    pm.view_to_cart_pct,
    pm.purchase_sessions,
    pm.view_to_purchase_pct,
    pm.purchases_after_cart,
    pm.cart_to_purchase_pct,
    pb.peer_product_count,
    pb.peer_viewed_sessions,
    pb.peer_view_to_cart_pct,
    pb.peer_view_to_purchase_pct,
    pb.peer_cart_to_purchase_pct
FROM product_metrics pm
JOIN targets t ON pm.product_id = t.product_id
LEFT JOIN peer_benchmarks pb ON pm.category_id = pb.category_id
ORDER BY pm.category_name, pm.product_name;
