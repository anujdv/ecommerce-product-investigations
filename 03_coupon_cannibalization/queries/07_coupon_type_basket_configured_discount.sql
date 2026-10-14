SELECT
    c.discount_type,
    COUNT(DISTINCT o.order_id) AS coupon_orders,
    ROUND(AVG(o.total), 2) AS avg_paid_basket,
    ROUND(AVG(c.discount_value), 2) AS avg_configured_discount_value
FROM ecom.orders AS o
JOIN ecom.coupons AS c
    ON c.coupon_id = o.applied_coupon_id
GROUP BY c.discount_type
ORDER BY coupon_orders DESC;
