WITH line_discounts AS (
    SELECT
        oi.order_id,
        SUM(COALESCE(oi.line_discount, 0)) AS summed_line_discount
    FROM ecom.order_items oi
    GROUP BY oi.order_id
)
SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(SUM(COALESCE(o.discount, 0)), 2) AS order_discount_total,
    ROUND(SUM(COALESCE(ld.summed_line_discount, 0)), 2) AS line_discount_total,
    ROUND(
        SUM(COALESCE(o.discount, 0))
        - SUM(COALESCE(ld.summed_line_discount, 0)),
        2
    ) AS order_vs_line_difference,
    COUNT(*) FILTER (
        WHERE ABS(
            COALESCE(o.discount, 0)
            - COALESCE(ld.summed_line_discount, 0)
        ) > 0.01
    ) AS orders_with_difference
FROM ecom.orders o
JOIN ecom.coupons c
    ON c.coupon_id = o.applied_coupon_id
LEFT JOIN line_discounts ld
    ON ld.order_id = o.order_id
GROUP BY c.discount_type
ORDER BY c.discount_type;
