SELECT
    CASE 
        WHEN cs.segment_name IN ('New Customer','Window Shopper','At Risk','Churned')
            THEN 'Incremental'
        ELSE 'Cannibalization'
    END AS meta_group,
    AVG(o.total) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS avg_coupon_order_value,
    AVG(o.total) FILTER (WHERE o.applied_coupon_id IS NULL) AS avg_non_coupon_order_value,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NOT NULL) AS coupon_orders,
    COUNT(*) FILTER (WHERE o.applied_coupon_id IS NULL) AS non_coupon_orders
FROM ecom.orders o
JOIN ecom.customers c ON o.customer_id = c.customer_id
JOIN ecom.segment_memberships sm ON c.customer_id = sm.customer_id
    AND o.created_at BETWEEN sm.valid_from AND sm.valid_to
JOIN ecom.customer_segments cs ON sm.segment_id = cs.segment_id
GROUP BY meta_group;
