SELECT
  cs.segment_name,
  count(*) FILTER (
    WHERE
      o.applied_coupon_id IS NOT NULL
  ) AS orders_with_coupons,
  count(DISTINCT o.order_id) AS total_orders,
  round(
    (
      100.0 * (
        count(*) FILTER (
          WHERE
            o.applied_coupon_id IS NOT NULL
        )
      ) / count(DISTINCT o.order_id)
    ),
    2
  ) AS coupon_redemption_rate
FROM
  ecom.orders o
  JOIN ecom.customers c ON o.customer_id = c.customer_id
  JOIN ecom.segment_memberships sm ON c.customer_id = sm.customer_id
  AND o.created_at >= sm.valid_from
  AND (
    sm.valid_to IS NULL
    OR o.created_at <= sm.valid_to
  )
  JOIN ecom.customer_segments cs ON sm.segment_id = cs.segment_id
GROUP BY
  cs.segment_name
ORDER BY
  coupon_redemption_rate;
