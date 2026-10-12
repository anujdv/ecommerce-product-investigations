-- Review and price-list summary
-- Source: 02_high_views_low_conversion/investigation.md

WITH targets(product_id) AS (
    VALUES
        (801), (2883), (3257), (1048), (1273),
        (1227), (3002), (3921), (127), (1254)
),
review_summary AS (
    SELECT
        product_id,
        COUNT(*) AS review_count,
        ROUND(AVG(rating), 2) AS average_rating
    FROM ecom.product_reviews
    GROUP BY product_id
),
active_prices AS (
    SELECT
        pv.product_id,
        pr.variant_id,
        pr.price_list_id,
        pl.name AS price_list_name,
        pl.currency,
        pr.list_price,
        pr.sale_price,
        ROW_NUMBER() OVER (
            PARTITION BY pr.variant_id, pr.price_list_id
            ORDER BY pr.valid_from DESC
        ) AS price_rank
    FROM ecom.prices pr
    JOIN ecom.product_variants pv
        ON pr.variant_id = pv.variant_id
    JOIN ecom.price_lists pl
        ON pr.price_list_id = pl.price_list_id
    WHERE pr.valid_from <= DATE '2026-04-19'
      AND (pr.valid_to IS NULL OR pr.valid_to >= DATE '2026-04-19')
),
price_summary AS (
    SELECT
        product_id,
        price_list_name,
        currency,
        COUNT(*) AS variant_price_count,
        ROUND(AVG(list_price), 2) AS avg_list_price,
        ROUND(AVG(sale_price), 2) AS avg_sale_price,
        ROUND(
            AVG(
                100.0 * (list_price - sale_price)
                / NULLIF(list_price, 0)
            ),
            2
        ) AS avg_discount_pct,
        SUM(CASE WHEN sale_price > list_price THEN 1 ELSE 0 END)
            AS variants_sale_above_list
    FROM active_prices
    WHERE price_rank = 1
    GROUP BY product_id, price_list_name, currency
)
SELECT
    c.category_name,
    p.product_id,
    p.product_name,
    r.review_count,
    r.average_rating,
    ps.price_list_name,
    ps.currency,
    ps.variant_price_count,
    ps.avg_list_price,
    ps.avg_sale_price,
    ps.avg_discount_pct,
    ps.variants_sale_above_list
FROM targets t
JOIN ecom.products p
    ON t.product_id = p.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
LEFT JOIN review_summary r
    ON p.product_id = r.product_id
LEFT JOIN price_summary ps
    ON p.product_id = ps.product_id
ORDER BY c.category_name, p.product_id, ps.currency;
