WITH ranked_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.created_at,
        o.applied_coupon_id,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.created_at, o.order_id
        ) AS customer_order_number
    FROM ecom.orders o
),
target_redemptions AS (
    SELECT
        ro.order_id,
        ro.customer_id,
        ro.customer_order_number,
        c.code AS coupon_code
    FROM ranked_orders ro
    JOIN ecom.coupons c
        ON c.coupon_id = ro.applied_coupon_id
    WHERE UPPER(c.code) IN ('WELCOME10', 'WELCOME15', 'FIRSTBUY')
)
SELECT
    coupon_code,
    COUNT(*) AS redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number = 1
    ) AS first_order_redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number > 1
    ) AS repeat_order_redemptions,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE customer_order_number > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_redemption_pct
FROM target_redemptions
GROUP BY coupon_code
ORDER BY coupon_code;
