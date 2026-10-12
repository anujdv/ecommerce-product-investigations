SELECT
    c.category_name,
    p.product_id,
    p.product_name,
    r.rating,
    r.title,
    r.body,
    r.created_at
FROM ecom.product_reviews r
JOIN ecom.products p
    ON r.product_id = p.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
WHERE p.product_id IN (
    801, 2883, 3257, 1048, 1273,
    1227, 3002, 3921, 127, 1254
)
ORDER BY c.category_name, p.product_id, r.created_at DESC;
