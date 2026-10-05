SELECT
    cs.segment_name,
    count(*) filter (WHERE o.applied_coupon_id IS NOT NULL) as orders_with_coupons,
    count(distinct o.order_id) as total_orders,
    round((100.0*(count(*) filter (WHERE o.applied_coupon_id IS NOT NULL)) / count(distinct o.order_id)),2) as coupon_redemption_rate
FROM
    ecom.orders o join ecom.customers c on o.customer_id = c.customer_id
    join ecom.segment_memberships sm on c.customer_id = sm.customer_id
    AND o.created_at BETWEEN sm.valid_from AND sm.valid_to
    join ecom.customer_segments cs on sm.segment_id = cs.segment_id
group BY
    cs.segment_name
order by 
    coupon_redemption_rate;
