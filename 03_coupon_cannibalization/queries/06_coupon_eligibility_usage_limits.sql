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
coupon_redemptions AS (
    SELECT
        ro.order_id,
        ro.customer_id,
        ro.created_at,
        ro.customer_order_number,
        c.coupon_id,
        UPPER(c.code) AS coupon_code,
        c.max_uses,
        c.max_uses_per_customer,
        CASE
            WHEN c.starts_at IS NOT NULL
                 AND ro.created_at < c.starts_at THEN TRUE
            WHEN c.ends_at IS NOT NULL
                 AND ro.created_at > c.ends_at THEN TRUE
            ELSE FALSE
        END AS outside_valid_dates,
        ROW_NUMBER() OVER (
            PARTITION BY c.coupon_id
            ORDER BY ro.created_at, ro.order_id
        ) AS coupon_use_number,
        ROW_NUMBER() OVER (
            PARTITION BY c.coupon_id, ro.customer_id
            ORDER BY ro.created_at, ro.order_id
        ) AS customer_coupon_use_number
    FROM ranked_orders ro
    JOIN ecom.coupons c
        ON c.coupon_id = ro.applied_coupon_id
    WHERE UPPER(c.code) IN ('WELCOME10', 'WELCOME15', 'FIRSTBUY')
)
SELECT
    coupon_code,
    COUNT(*) AS redemptions,
    COUNT(*) FILTER (
        WHERE customer_order_number > 1
    ) AS repeat_order_redemptions,
    COUNT(*) FILTER (
        WHERE outside_valid_dates
    ) AS redemptions_outside_valid_dates,
    COUNT(*) FILTER (
        WHERE max_uses_per_customer IS NOT NULL
          AND customer_coupon_use_number > max_uses_per_customer
    ) AS redemptions_over_customer_limit,
    COUNT(DISTINCT customer_id) FILTER (
        WHERE max_uses_per_customer IS NOT NULL
          AND customer_coupon_use_number > max_uses_per_customer
    ) AS customers_over_customer_limit,
    COUNT(*) FILTER (
        WHERE max_uses IS NOT NULL
          AND coupon_use_number > max_uses
    ) AS redemptions_over_coupon_limit
FROM coupon_redemptions
GROUP BY coupon_code
ORDER BY coupon_code;
