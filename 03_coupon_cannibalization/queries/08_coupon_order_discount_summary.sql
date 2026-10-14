SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(AVG(o.total), 2) AS avg_paid_basket,
    ROUND(AVG(o.discount), 2) AS avg_recorded_discount,
    ROUND(SUM(o.discount), 2) AS total_recorded_discount,
    COUNT(*) FILTER (WHERE o.discount IS NULL) AS orders_missing_discount,
    ROUND(
        100.0 * SUM(o.discount)
        / NULLIF(SUM(o.total + o.discount), 0),
        2
    ) AS recorded_discount_pct_of_pre_discount_value
FROM ecom.orders o
JOIN ecom.coupons c
    ON c.coupon_id = o.applied_coupon_id
GROUP BY c.discount_type
ORDER BY total_recorded_discount DESC;
