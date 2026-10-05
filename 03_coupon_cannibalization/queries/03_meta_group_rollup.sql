SELECT
    CASE 
        WHEN cs.segment_name IN ('New Customer','Window Shopper','At Risk','Churned')
            THEN 'Incremental'
        WHEN cs.segment_name IN ('Active Buyer','Loyal','Champion','Big Spender','Premium','Coupon Hunter')
            THEN 'Cannibalization'
    END AS meta_group,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS orders_with_coupons,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) 
        / NULLIF(COUNT(DISTINCT o.order_id),0), 2
    ) AS coupon_redemption_rate
FROM ecom.orders o
JOIN ecom.customers c 
    ON o.customer_id = c.customer_id
JOIN ecom.segment_memberships sm 
    ON c.customer_id = sm.customer_id
    AND o.created_at BETWEEN sm.valid_from AND sm.valid_to
JOIN ecom.customer_segments cs 
    ON sm.segment_id = cs.segment_id
GROUP BY meta_group;
