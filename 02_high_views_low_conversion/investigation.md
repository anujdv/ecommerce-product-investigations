

Product views
session_events
    ↓
variant → product → category

Purchases
orders
    ↓
order_items
    ↓
variant → product → category



## 1. Category Purchase Baseline
I counted distinct orders containing at least one product from each category.
```sql
SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id) AS orders
FROM ecom.orders o
JOIN ecom.order_items oi
    ON o.order_id = oi.order_id
JOIN ecom.product_variants pv
    ON oi.variant_id = pv.variant_id
JOIN ecom.products p
    ON p.product_id = pv.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
WHERE o.created_at >= '2026-04-19'
GROUP BY
    c.category_name
ORDER BY
    orders DESC;
```
| category_name | orders |
| --- | --- |
| Skincare | 2,696 |
| Shoes | 2,627 |
| Haircare | 2,619 |
| Accessories | 2,529 |
| Decor | 2,502 |
| Headphones | 2,499 |
| Tops | 2,492 |
| Jeans | 2,447 |
| Jackets | 2,441 |
| Kitchen | 2,421 |
| Smartwatch | 2,356 |
| Makeup | 2,309 |
| Speakers | 2,307 |
| Bedding | 2,138 |

Date Alignment

The session_events table was instrumented starting April 19, 2026, while the orders table contains orders from an earlier period. Therefore, orders were restricted to:

created_at >= '2026-04-19'

This ensures that the purchase population is aligned with the period for which product-view events are available, allowing category view-share and purchase-share to be compared on a consistent time basis.

---

## 2. Category View Baseline

```sql
SELECT
    c.category_name,
    COUNT(*) AS views
FROM ecom.session_events se
JOIN ecom.product_variants pv
    ON se.variant_id = pv.variant_id
JOIN ecom.products p
    ON pv.product_id = p.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
WHERE se.event_type = 'product_view'
GROUP BY
    c.category_name
ORDER BY
    views DESC;
```

| category_name | views |
| --- | --- |
| Makeup | 18,046 |
| Jackets | 12,358 |
| Smartwatch | 11,878 |
| Jeans | 11,315 |
| Skincare | 11,243 |
| Haircare | 11,207 |
| Tops | 10,868 |
| Bedding | 10,422 |
| Decor | 10,340 |
| Accessories | 10,309 |
| Kitchen | 10,299 |
| Speakers | 10,169 |
| Shoes | 10,098 |
| Headphones | 9,889 |

## 3. Category View-to-Purchase Analysis

```sql
WITH views AS (
    SELECT
        c.category_name,
        COUNT(*) AS view_count
    FROM ecom.session_events se
    JOIN ecom.product_variants pv
        ON se.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE se.event_type = 'product_view'
    GROUP BY c.category_name
),

orders AS (
    SELECT
        c.category_name,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM ecom.orders o
    JOIN ecom.order_items oi
        ON o.order_id = oi.order_id
    JOIN ecom.product_variants pv
        ON oi.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE o.created_at >= '2026-04-19'
    GROUP BY c.category_name
),

totals AS (
    SELECT
        (SELECT SUM(view_count) FROM views) AS total_views,
        (SELECT SUM(order_count) FROM orders) AS total_orders
)

SELECT
    v.category_name,
    v.view_count,
    o.order_count,

    ROUND(
        100.0 * v.view_count / t.total_views,
        2
    ) AS view_share_pct,

    ROUND(
        100.0 * o.order_count / t.total_orders,
        2
    ) AS purchase_share_pct,

    ROUND(
        (1.0 * v.view_count / t.total_views)
        /
        NULLIF(
            1.0 * o.order_count / t.total_orders,
            0
        ),
        2
    ) AS view_to_purchase_ratio

FROM views v
LEFT JOIN orders o
    ON v.category_name = o.category_name
CROSS JOIN totals t
ORDER BY view_to_purchase_ratio DESC;
```
| category_name | view_count | order_count | view_share_pct | purchase_share_pct | view_to_purchase_ratio |
| --- | --- | --- | --- | --- | --- |
| Makeup | 18,046 | 2,309 | 11.39 | 6.72 | 1.7 |
| Jackets | 12,358 | 2,441 | 7.8 | 7.1 | 1.1 |
| Smartwatch | 11,878 | 2,356 | 7.5 | 6.85 | 1.09 |
| Bedding | 10,422 | 2,138 | 6.58 | 6.22 | 1.06 |
| Jeans | 11,315 | 2,447 | 7.14 | 7.12 | 1 |
| Speakers | 10,169 | 2,307 | 6.42 | 6.71 | 0.96 |
| Tops | 10,868 | 2,492 | 6.86 | 7.25 | 0.95 |
| Haircare | 11,207 | 2,619 | 7.07 | 7.62 | 0.93 |
| Kitchen | 10,299 | 2,421 | 6.5 | 7.04 | 0.92 |
| Skincare | 11,243 | 2,696 | 7.1 | 7.84 | 0.9 |
| Decor | 10,340 | 2,502 | 6.53 | 7.28 | 0.9 |
| Accessories | 10,309 | 2,529 | 6.51 | 7.36 | 0.88 |
| Headphones | 9,889 | 2,499 | 6.24 | 7.27 | 0.86 |
| Shoes | 10,098 | 2,627 | 6.37 | 7.64 | 0.83 |

Findings

No category exhibits the hypothesized 3–5× high-view, low-purchase paradox.

Makeup is the strongest outlier, accounting for 11.39% of views but only 6.72% of purchases, resulting in a 1.70× view-to-purchase ratio.

Jackets (1.10×), Smartwatch (1.09×), and Bedding (1.06×) show only modest view-share overrepresentation.

Jeans is approximately balanced at 1.00×.

All remaining categories have ratios below 1.0×, indicating that their purchase share is equal to or greater than their view share.


---

## 4. Product-Level Drill-Down

The category-level results do not show a large 3–5× imbalance, so the next step is to identify meaningful high-view, high-ratio products within each category. The `view_count >= 100` cutoff filters out very low-exposure items whose ratios can be unstable. The query below ranks products separately in each category using the **global** product view-share/purchase-share ratio and returns the top five.

### Global product view-to-purchase ratio

```sql
WITH views AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
        COUNT(*) AS view_count
    FROM ecom.session_events se
    JOIN ecom.product_variants pv
        ON se.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE se.event_type = 'product_view'
    GROUP BY c.category_name, p.product_id, p.product_name
),
orders AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM ecom.orders o
    JOIN ecom.order_items oi
        ON o.order_id = oi.order_id
    JOIN ecom.product_variants pv
        ON oi.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE o.created_at >= '2026-04-19'
    GROUP BY c.category_name, p.product_id, p.product_name
),
totals AS (
    SELECT
        (SELECT SUM(view_count) FROM views) AS total_views,
        (SELECT SUM(order_count) FROM orders) AS total_orders
),
product_analysis AS (
    SELECT
        v.category_name,
        v.product_id,
        v.product_name,
        v.view_count,
        COALESCE(o.order_count, 0) AS order_count,
        ROUND(100.0 * v.view_count / t.total_views, 2) AS view_share_pct,
        ROUND(100.0 * COALESCE(o.order_count, 0) / t.total_orders, 2) AS purchase_share_pct,
        ROUND(
            (1.0 * v.view_count / t.total_views)
            / NULLIF(1.0 * COALESCE(o.order_count, 0) / t.total_orders, 0),
            2
        ) AS view_to_purchase_ratio
    FROM views v
    LEFT JOIN orders o
        ON v.product_id = o.product_id
    CROSS JOIN totals t
),
ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category_name
            ORDER BY view_to_purchase_ratio DESC, view_count DESC
        ) AS category_rank
    FROM product_analysis
    WHERE view_count >= 100
)
SELECT
    category_name,
    category_rank,
    product_id,
    product_name,
    view_count,
    order_count,
    view_share_pct,
    purchase_share_pct,
    view_to_purchase_ratio
FROM ranked_products
WHERE category_rank <= 5
ORDER BY category_name, category_rank;
```

The ratio is global: each product's share of all product views divided by its share of all product orders. The ranking is partitioned by category so the output is a category-by-category shortlist.

### Full results: top five products in every category (global calculation)

| category_name | category_rank | product_id | product_name | view_count | order_count | view_share_pct | purchase_share_pct | view_to_purchase_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Accessories | 1 | 127 | Ivory & Oak Classic Canvas Tote | 263 | 4 | 0.17 | 0.01 | 15.08 |
| Accessories | 2 | 2,475 | Ivory & Oak Vintage Canvas Tote | 180 | 4 | 0.11 | 0.01 | 10.32 |
| Accessories | 3 | 1,083 | Mehr Classic Beanie | 134 | 4 | 0.08 | 0.01 | 7.68 |
| Accessories | 4 | 162 | Loom & Ladle Everyday Sunglasses | 137 | 6 | 0.09 | 0.02 | 5.24 |
| Accessories | 5 | 2,903 | Suta Threads Minimal Sunglasses | 106 | 6 | 0.07 | 0.02 | 4.05 |
| Bedding | 1 | 3,002 | Cedarline Percale Cotton Bedsheet Set | 1,469 | 15 | 0.93 | 0.04 | 22.46 |
| Bedding | 2 | 3,376 | TickTone Essentials Sateen Duvet Cover | 171 | 2 | 0.11 | 0.01 | 19.6 |
| Bedding | 3 | 2,408 | Vastra Craft Breathable Comforter | 398 | 8 | 0.25 | 0.02 | 11.41 |
| Bedding | 4 | 15 | Kosha 300-TC Quilt | 457 | 15 | 0.29 | 0.04 | 6.99 |
| Bedding | 5 | 2,129 | Dhaaga Percale Mattress Protector | 354 | 12 | 0.22 | 0.03 | 6.76 |
| Decor | 1 | 1,227 | Dhaaga Scandinavian Photo Frame Set | 691 | 7 | 0.44 | 0.02 | 22.63 |
| Decor | 2 | 54 | Tarang Scandinavian Wall Clock | 355 | 10 | 0.22 | 0.03 | 8.14 |
| Decor | 3 | 1,884 | Patang Craft Boho Planter | 162 | 7 | 0.1 | 0.02 | 5.31 |
| Decor | 4 | 1,798 | Korval Atelier Terracotta Table Lamp | 223 | 11 | 0.14 | 0.03 | 4.65 |
| Decor | 5 | 3,024 | Saffron Street Craft Handpainted Photo Frame Set | 145 | 9 | 0.09 | 0.02 | 3.69 |
| Haircare | 1 | 1,355 | Kalpana Atelier Damage-Repair Hair Oil | 454 | 13 | 0.29 | 0.04 | 8.01 |
| Haircare | 2 | 1,405 | Zyra Essentials Damage-Repair Hair Mask | 226 | 7 | 0.14 | 0.02 | 7.4 |
| Haircare | 3 | 3,701 | Crestwave Co. Damage-Repair Hair Serum | 525 | 17 | 0.33 | 0.05 | 7.08 |
| Haircare | 4 | 1,234 | UrbanRoot Studio Coconut Shampoo | 558 | 22 | 0.35 | 0.06 | 5.82 |
| Haircare | 5 | 321 | TickTone Essentials Coconut Shampoo | 316 | 16 | 0.2 | 0.04 | 4.53 |
| Headphones | 1 | 3,704 | Solstice Supply Bass+ Studio Monitors | 128 | 3 | 0.08 | 0.01 | 9.78 |
| Headphones | 2 | 932 | Terraform Goods Clarity ANC Headphones | 460 | 16 | 0.29 | 0.04 | 6.59 |
| Headphones | 3 | 2,045 | Everbloom Max Studio Monitors | 222 | 8 | 0.14 | 0.02 | 6.36 |
| Headphones | 4 | 2,320 | Dhaaga Bass+ Wireless Earbuds | 112 | 6 | 0.07 | 0.02 | 4.28 |
| Headphones | 5 | 3,754 | Suta Threads Origins Max Over-Ear Headphones | 167 | 10 | 0.11 | 0.03 | 3.83 |
| Jackets | 1 | 3,921 | Drift & Dwell Classic Windcheater | 1,455 | 19 | 0.92 | 0.05 | 17.56 |
| Jackets | 2 | 1,690 | Moksha Living Lightweight Hooded Jacket | 1,226 | 17 | 0.77 | 0.05 | 16.54 |
| Jackets | 3 | 924 | Dhaaga Works Oversized Biker Jacket | 142 | 7 | 0.09 | 0.02 | 4.65 |
| Jackets | 4 | 2,213 | Kosha Co. All-Weather Puffer Jacket | 239 | 16 | 0.15 | 0.04 | 3.43 |
| Jackets | 5 | 950 | Featherlite Sherpa-Lined Bomber Jacket | 280 | 25 | 0.18 | 0.07 | 2.57 |
| Jeans | 1 | 1,254 | Windrose Distressed Relaxed Jeans | 611 | 11 | 0.39 | 0.03 | 12.74 |
| Jeans | 2 | 703 | Strideway Distressed Straight Jeans | 168 | 4 | 0.11 | 0.01 | 9.63 |
| Jeans | 3 | 1,200 | Amara Beauty Mid-Rise High-Rise Jeans | 707 | 19 | 0.45 | 0.05 | 8.53 |
| Jeans | 4 | 3,953 | AeroBeat Essentials Distressed Slim Jeans | 244 | 10 | 0.15 | 0.03 | 5.59 |
| Jeans | 5 | 2,084 | Amara Beauty Raw Denim High-Rise Jeans | 254 | 12 | 0.16 | 0.03 | 4.85 |
| Kitchen | 1 | 3,257 | Silverbirch Works Stoneware Coffee French Press | 972 | 6 | 0.61 | 0.02 | 37.15 |
| Kitchen | 2 | 3,778 | Dhaaga Works Pro Nonstick Tawa | 225 | 5 | 0.14 | 0.01 | 10.32 |
| Kitchen | 3 | 2,839 | Onyx Labs House Heritage Storage Jar Set | 263 | 6 | 0.17 | 0.02 | 10.05 |
| Kitchen | 4 | 2,771 | Loom & Ladle Supply Stainless Cast Iron Skillet | 244 | 10 | 0.15 | 0.03 | 5.59 |
| Kitchen | 5 | 2,618 | Strideway Collective Stainless Nonstick Tawa | 212 | 11 | 0.13 | 0.03 | 4.42 |
| Makeup | 1 | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 2,644 | 8 | 1.67 | 0.02 | 75.78 |
| Makeup | 2 | 2,883 | Suta Threads Velvet Kajal | 4,334 | 14 | 2.74 | 0.04 | 70.98 |
| Makeup | 3 | 116 | Saanjh Velvet Matte Lipstick | 235 | 3 | 0.15 | 0.01 | 17.96 |
| Makeup | 4 | 1,519 | Zephyr & Co Co. Weightless Blush | 535 | 7 | 0.34 | 0.02 | 17.52 |
| Makeup | 5 | 3,028 | Mistral Velvet Compact Powder | 490 | 13 | 0.31 | 0.04 | 8.64 |
| Shoes | 1 | 234 | Loom & Ladle Flex Sandals | 636 | 20 | 0.4 | 0.06 | 7.29 |
| Shoes | 2 | 2,935 | Rustique Pro Slip-Ons | 218 | 7 | 0.14 | 0.02 | 7.14 |
| Shoes | 3 | 2,766 | TickTone Essentials Leather Derby Shoes | 146 | 13 | 0.09 | 0.04 | 2.58 |
| Shoes | 4 | 3,456 | Mirae Pro Derby Shoes | 132 | 12 | 0.08 | 0.03 | 2.52 |
| Shoes | 5 | 2,182 | Everbloom Leather Running Shoes | 156 | 18 | 0.1 | 0.05 | 1.99 |
| Skincare | 1 | 147 | Onyx Labs Niacinamide Sunscreen SPF 50 | 292 | 7 | 0.18 | 0.02 | 9.56 |
| Skincare | 2 | 1,413 | Solstice Supply Aloe Face Wash | 346 | 14 | 0.22 | 0.04 | 5.67 |
| Skincare | 3 | 1,615 | Raaga Brightening Vitamin C Serum | 129 | 6 | 0.08 | 0.02 | 4.93 |
| Skincare | 4 | 982 | TrueNorth Saffron Sunscreen SPF 50 | 122 | 6 | 0.08 | 0.02 | 4.66 |
| Skincare | 5 | 3,308 | Patang Craft Hydrating Face Mist | 159 | 10 | 0.1 | 0.03 | 3.65 |
| Smartwatch | 1 | 1,048 | Silverbirch Vital Hybrid Watch | 1,845 | 16 | 1.16 | 0.04 | 26.44 |
| Smartwatch | 2 | 3,604 | BassForge Collective Vital Kids Smartwatch | 1,077 | 24 | 0.68 | 0.07 | 10.29 |
| Smartwatch | 3 | 1,821 | Cedarline Atelier Pro GPS Watch | 428 | 12 | 0.27 | 0.03 | 8.18 |
| Smartwatch | 4 | 3,643 | Tarang Essentials Pulse Smartwatch | 193 | 12 | 0.12 | 0.03 | 3.69 |
| Smartwatch | 5 | 2,577 | Eastlight Supply Luxe Hybrid Watch | 127 | 11 | 0.08 | 0.03 | 2.65 |
| Speakers | 1 | 3,501 | Veyra Craft Outdoor Party Speaker | 173 | 3 | 0.11 | 0.01 | 13.22 |
| Speakers | 2 | 2,827 | TickTone Essentials Studio Party Speaker | 257 | 5 | 0.16 | 0.01 | 11.79 |
| Speakers | 3 | 94 | Patang Craft Mini Soundbar | 355 | 9 | 0.22 | 0.02 | 9.04 |
| Speakers | 4 | 3,526 | Terraform Goods Studio 360 Bookshelf Speakers | 304 | 9 | 0.19 | 0.02 | 7.75 |
| Speakers | 5 | 1,341 | Everbloom 360 Bluetooth Speaker | 120 | 4 | 0.08 | 0.01 | 6.88 |
| Tops | 1 | 1,273 | Indigo Lane Origins Essential Crop Top | 910 | 9 | 0.57 | 0.02 | 23.18 |
| Tops | 2 | 3,331 | Silverbirch Works Classic Blouse | 175 | 3 | 0.11 | 0.01 | 13.38 |
| Tops | 3 | 133 | NordWeave Collective Textured Linen Shirt | 108 | 2 | 0.07 | 0.01 | 12.38 |
| Tops | 4 | 2,496 | Patang Essential Tank Top | 207 | 4 | 0.13 | 0.01 | 11.87 |
| Tops | 5 | 1,822 | Zephyr & Co Essential Crew-Neck T-Shirt | 423 | 15 | 0.27 | 0.04 | 6.47 |

The table includes the complete output across all 14 categories (70 products).

### Interpreting the shortlist

Tiny products with zero purchases and only 1–7 views are not useful diagnostic leads: their extreme or undefined ratios are driven by too little exposure to support a meaningful comparison. The view threshold reduces this noise. By contrast, products with substantial traffic and relatively few orders are stronger leads. Examples from the results include Cedarline Percale Cotton Bedsheet Set (1,469 views, 15 orders, 22.46×), TickTone Essentials Sateen Duvet Cover (171 views, 2 orders, 19.6×), Dhaaga Scandinavian Photo Frame Set (691 views, 7 orders, 22.63×), Drift & Dwell Classic Windcheater (1,455 views, 19 orders, 17.56×), and Moksha Living Lightweight Hooded Jacket (1,226 views, 17 orders, 16.54×).

### Appendix A: Within-category robustness check

This is a secondary robustness check, retained for reproducibility rather than used as the primary metric. It compares each product's share of its category's views with its share of its category's orders and returns the top five products per category using the same exposure cutoff.

```sql
WITH views AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
        COUNT(*) AS view_count
    FROM ecom.session_events se
    JOIN ecom.product_variants pv
        ON se.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE se.event_type = 'product_view'
    GROUP BY c.category_name, p.product_id, p.product_name
),
orders AS (
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM ecom.orders o
    JOIN ecom.order_items oi
        ON o.order_id = oi.order_id
    JOIN ecom.product_variants pv
        ON oi.variant_id = pv.variant_id
    JOIN ecom.products p
        ON pv.product_id = p.product_id
    JOIN ecom.categories c
        ON p.category_id = c.category_id
    WHERE o.created_at >= '2026-04-19'
    GROUP BY c.category_name, p.product_id, p.product_name
),
product_data AS (
    SELECT
        v.category_name,
        v.product_id,
        v.product_name,
        v.view_count,
        COALESCE(o.order_count, 0) AS order_count
    FROM views v
    LEFT JOIN orders o
        ON v.product_id = o.product_id
),
category_totals AS (
    SELECT
        category_name,
        SUM(view_count) AS category_total_views,
        SUM(order_count) AS category_total_orders
    FROM product_data
    GROUP BY category_name
),
product_analysis AS (
    SELECT
        p.category_name,
        p.product_id,
        p.product_name,
        p.view_count,
        p.order_count,
        ROUND(100.0 * p.view_count / ct.category_total_views, 2) AS category_view_share_pct,
        ROUND(100.0 * p.order_count / NULLIF(ct.category_total_orders, 0), 2) AS category_purchase_share_pct,
        ROUND(
            (1.0 * p.view_count / ct.category_total_views)
            / NULLIF(1.0 * p.order_count / ct.category_total_orders, 0),
            2
        ) AS view_to_purchase_ratio
    FROM product_data p
    JOIN category_totals ct
        ON p.category_name = ct.category_name
),
ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category_name
            ORDER BY view_to_purchase_ratio DESC, view_count DESC
        ) AS category_rank
    FROM product_analysis
    WHERE view_count >= 100
)
SELECT
    category_name,
    category_rank,
    product_id,
    product_name,
    view_count,
    order_count,
    category_view_share_pct,
    category_purchase_share_pct,
    view_to_purchase_ratio
FROM ranked_products
WHERE category_rank <= 5
ORDER BY category_name, category_rank;
```

#### Full within-category results (top five per category)

| category_name | category_rank | product_id | product_name | view_count | order_count | category_view_share_pct | category_purchase_share_pct | view_to_purchase_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Accessories | 1 | 127 | Ivory & Oak Classic Canvas Tote | 263 | 4 | 2.55 | 0.15 | 16.95 |
| Accessories | 2 | 2,475 | Ivory & Oak Vintage Canvas Tote | 180 | 4 | 1.75 | 0.15 | 11.6 |
| Accessories | 3 | 1,083 | Mehr Classic Beanie | 134 | 4 | 1.3 | 0.15 | 8.63 |
| Accessories | 4 | 162 | Loom & Ladle Everyday Sunglasses | 137 | 6 | 1.33 | 0.23 | 5.88 |
| Accessories | 5 | 2,903 | Suta Threads Minimal Sunglasses | 106 | 6 | 1.03 | 0.23 | 4.55 |
| Bedding | 1 | 3,002 | Cedarline Percale Cotton Bedsheet Set | 1,469 | 15 | 14.1 | 0.67 | 21.12 |
| Bedding | 2 | 3,376 | TickTone Essentials Sateen Duvet Cover | 171 | 2 | 1.64 | 0.09 | 18.44 |
| Bedding | 3 | 2,408 | Vastra Craft Breathable Comforter | 398 | 8 | 3.82 | 0.36 | 10.73 |
| Bedding | 4 | 15 | Kosha 300-TC Quilt | 457 | 15 | 4.38 | 0.67 | 6.57 |
| Bedding | 5 | 2,129 | Dhaaga Percale Mattress Protector | 354 | 12 | 3.4 | 0.53 | 6.36 |
| Decor | 1 | 1,227 | Dhaaga Scandinavian Photo Frame Set | 691 | 7 | 6.68 | 0.26 | 25.32 |
| Decor | 2 | 54 | Tarang Scandinavian Wall Clock | 355 | 10 | 3.43 | 0.38 | 9.11 |
| Decor | 3 | 1,884 | Patang Craft Boho Planter | 162 | 7 | 1.57 | 0.26 | 5.94 |
| Decor | 4 | 1,798 | Korval Atelier Terracotta Table Lamp | 223 | 11 | 2.16 | 0.41 | 5.2 |
| Decor | 5 | 3,024 | Saffron Street Craft Handpainted Photo Frame Set | 145 | 9 | 1.4 | 0.34 | 4.13 |
| Haircare | 1 | 1,355 | Kalpana Atelier Damage-Repair Hair Oil | 454 | 13 | 4.05 | 0.47 | 8.6 |
| Haircare | 2 | 1,405 | Zyra Essentials Damage-Repair Hair Mask | 226 | 7 | 2.02 | 0.25 | 7.95 |
| Haircare | 3 | 3,701 | Crestwave Co. Damage-Repair Hair Serum | 525 | 17 | 4.68 | 0.62 | 7.61 |
| Haircare | 4 | 1,234 | UrbanRoot Studio Coconut Shampoo | 558 | 22 | 4.98 | 0.8 | 6.25 |
| Haircare | 5 | 321 | TickTone Essentials Coconut Shampoo | 316 | 16 | 2.82 | 0.58 | 4.87 |
| Headphones | 1 | 3,704 | Solstice Supply Bass+ Studio Monitors | 128 | 3 | 1.29 | 0.11 | 11.36 |
| Headphones | 2 | 932 | Terraform Goods Clarity ANC Headphones | 460 | 16 | 4.65 | 0.61 | 7.66 |
| Headphones | 3 | 2,045 | Everbloom Max Studio Monitors | 222 | 8 | 2.24 | 0.3 | 7.39 |
| Headphones | 4 | 2,320 | Dhaaga Bass+ Wireless Earbuds | 112 | 6 | 1.13 | 0.23 | 4.97 |
| Headphones | 5 | 3,754 | Suta Threads Origins Max Over-Ear Headphones | 167 | 10 | 1.69 | 0.38 | 4.45 |
| Jackets | 1 | 3,921 | Drift & Dwell Classic Windcheater | 1,455 | 19 | 11.77 | 0.74 | 15.99 |
| Jackets | 2 | 1,690 | Moksha Living Lightweight Hooded Jacket | 1,226 | 17 | 9.92 | 0.66 | 15.06 |
| Jackets | 3 | 924 | Dhaaga Works Oversized Biker Jacket | 142 | 7 | 1.15 | 0.27 | 4.24 |
| Jackets | 4 | 2,213 | Kosha Co. All-Weather Puffer Jacket | 239 | 16 | 1.93 | 0.62 | 3.12 |
| Jackets | 5 | 950 | Featherlite Sherpa-Lined Bomber Jacket | 280 | 25 | 2.27 | 0.97 | 2.34 |
| Jeans | 1 | 1,254 | Windrose Distressed Relaxed Jeans | 611 | 11 | 5.4 | 0.42 | 12.76 |
| Jeans | 2 | 703 | Strideway Distressed Straight Jeans | 168 | 4 | 1.48 | 0.15 | 9.65 |
| Jeans | 3 | 1,200 | Amara Beauty Mid-Rise High-Rise Jeans | 707 | 19 | 6.25 | 0.73 | 8.55 |
| Jeans | 4 | 3,953 | AeroBeat Essentials Distressed Slim Jeans | 244 | 10 | 2.16 | 0.38 | 5.6 |
| Jeans | 5 | 2,084 | Amara Beauty Raw Denim High-Rise Jeans | 254 | 12 | 2.24 | 0.46 | 4.86 |
| Kitchen | 1 | 3,257 | Silverbirch Works Stoneware Coffee French Press | 972 | 6 | 9.44 | 0.23 | 40.35 |
| Kitchen | 2 | 3,778 | Dhaaga Works Pro Nonstick Tawa | 225 | 5 | 2.18 | 0.19 | 11.21 |
| Kitchen | 3 | 2,839 | Onyx Labs House Heritage Storage Jar Set | 263 | 6 | 2.55 | 0.23 | 10.92 |
| Kitchen | 4 | 2,771 | Loom & Ladle Supply Stainless Cast Iron Skillet | 244 | 10 | 2.37 | 0.39 | 6.08 |
| Kitchen | 5 | 2,618 | Strideway Collective Stainless Nonstick Tawa | 212 | 11 | 2.06 | 0.43 | 4.8 |
| Makeup | 1 | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 2,644 | 8 | 14.65 | 0.33 | 44.87 |
| Makeup | 2 | 2,883 | Suta Threads Velvet Kajal | 4,334 | 14 | 24.02 | 0.57 | 42.03 |
| Makeup | 3 | 116 | Saanjh Velvet Matte Lipstick | 235 | 3 | 1.3 | 0.12 | 10.63 |
| Makeup | 4 | 1,519 | Zephyr & Co Co. Weightless Blush | 535 | 7 | 2.96 | 0.29 | 10.38 |
| Makeup | 5 | 3,028 | Mistral Velvet Compact Powder | 490 | 13 | 2.72 | 0.53 | 5.12 |
| Shoes | 1 | 234 | Loom & Ladle Flex Sandals | 636 | 20 | 6.3 | 0.72 | 8.76 |
| Shoes | 2 | 2,935 | Rustique Pro Slip-Ons | 218 | 7 | 2.16 | 0.25 | 8.58 |
| Shoes | 3 | 2,766 | TickTone Essentials Leather Derby Shoes | 146 | 13 | 1.45 | 0.47 | 3.1 |
| Shoes | 4 | 3,456 | Mirae Pro Derby Shoes | 132 | 12 | 1.31 | 0.43 | 3.03 |
| Shoes | 5 | 2,182 | Everbloom Leather Running Shoes | 156 | 18 | 1.54 | 0.65 | 2.39 |
| Skincare | 1 | 147 | Onyx Labs Niacinamide Sunscreen SPF 50 | 292 | 7 | 2.6 | 0.24 | 10.63 |
| Skincare | 2 | 1,413 | Solstice Supply Aloe Face Wash | 346 | 14 | 3.08 | 0.49 | 6.3 |
| Skincare | 3 | 1,615 | Raaga Brightening Vitamin C Serum | 129 | 6 | 1.15 | 0.21 | 5.48 |
| Skincare | 4 | 982 | TrueNorth Saffron Sunscreen SPF 50 | 122 | 6 | 1.09 | 0.21 | 5.18 |
| Skincare | 5 | 3,308 | Patang Craft Hydrating Face Mist | 159 | 10 | 1.41 | 0.35 | 4.05 |
| Smartwatch | 1 | 1,048 | Silverbirch Vital Hybrid Watch | 1,845 | 16 | 15.53 | 0.64 | 24.1 |
| Smartwatch | 2 | 3,604 | BassForge Collective Vital Kids Smartwatch | 1,077 | 24 | 9.07 | 0.97 | 9.38 |
| Smartwatch | 3 | 1,821 | Cedarline Atelier Pro GPS Watch | 428 | 12 | 3.6 | 0.48 | 7.45 |
| Smartwatch | 4 | 3,643 | Tarang Essentials Pulse Smartwatch | 193 | 12 | 1.62 | 0.48 | 3.36 |
| Smartwatch | 5 | 2,577 | Eastlight Supply Luxe Hybrid Watch | 127 | 11 | 1.07 | 0.44 | 2.41 |
| Speakers | 1 | 3,501 | Veyra Craft Outdoor Party Speaker | 173 | 3 | 1.7 | 0.12 | 13.69 |
| Speakers | 2 | 2,827 | TickTone Essentials Studio Party Speaker | 257 | 5 | 2.53 | 0.21 | 12.2 |
| Speakers | 3 | 94 | Patang Craft Mini Soundbar | 355 | 9 | 3.49 | 0.37 | 9.36 |
| Speakers | 4 | 3,526 | Terraform Goods Studio 360 Bookshelf Speakers | 304 | 9 | 2.99 | 0.37 | 8.02 |
| Speakers | 5 | 1,341 | Everbloom 360 Bluetooth Speaker | 120 | 4 | 1.18 | 0.17 | 7.12 |
| Tops | 1 | 1,273 | Indigo Lane Origins Essential Crop Top | 910 | 9 | 8.37 | 0.34 | 24.56 |
| Tops | 2 | 3,331 | Silverbirch Works Classic Blouse | 175 | 3 | 1.61 | 0.11 | 14.17 |
| Tops | 3 | 133 | NordWeave Collective Textured Linen Shirt | 108 | 2 | 0.99 | 0.08 | 13.12 |
| Tops | 4 | 2,496 | Patang Essential Tank Top | 207 | 4 | 1.9 | 0.15 | 12.57 |
| Tops | 5 | 1,822 | Zephyr & Co Essential Crew-Neck T-Shirt | 423 | 15 | 3.89 | 0.57 | 6.85 |

The within-category ranking is similar to the global ranking because both ratios are proportional to the product's views-to-orders relationship, with category-specific or global denominators scaling the ratio. Since the original hypothesis compares category view share against global view share and purchase share, retain the global ratio as the primary metric for consistency with the category analysis.

### Next diagnostic direction

For the shortlisted products, compare **price, discount, rating, review count, and browsing/exposure factors** with other products in the same category. This will help test three possible explanations: price sensitivity, quality or review concerns, and differences in browsing-surface exposure. The ratio identifies products to investigate; these comparisons are needed to examine what may explain their view-to-order imbalance.

---

## 5. Product Attribute Diagnostics

The product shortlist was used to focus the review and price checks on ten higher-exposure, high-ratio products. The product-level ranking table above contains the full 70-row result; these ten products were selected for a manageable diagnostic sample across categories.

### SQL: review and price-list summary for the ten selected products

```
WITH targets(product_id) AS (
    VALUES
        (801), (2883), (3257), (1048), (1273),
        (1227), (3002), (3921), (127), (1254)
),
review_summary AS (
    SELECT
        product_id,
        COUNT(*) AS review_count,
        ROUND(AVG(rating), 2) AS average_rating
    FROM ecom.product_reviews
    GROUP BY product_id
),
active_prices AS (
    SELECT
        pv.product_id,
        pr.variant_id,
        pr.price_list_id,
        pl.name AS price_list_name,
        pl.currency,
        pr.list_price,
        pr.sale_price,
        ROW_NUMBER() OVER (
            PARTITION BY pr.variant_id, pr.price_list_id
            ORDER BY pr.valid_from DESC
        ) AS price_rank
    FROM ecom.prices pr
    JOIN ecom.product_variants pv
        ON pr.variant_id = pv.variant_id
    JOIN ecom.price_lists pl
        ON pr.price_list_id = pl.price_list_id
    WHERE pr.valid_from <= DATE '2026-04-19'
      AND (pr.valid_to IS NULL OR pr.valid_to >= DATE '2026-04-19')
),
price_summary AS (
    SELECT
        product_id,
        price_list_name,
        currency,
        COUNT(*) AS variant_price_count,
        ROUND(AVG(list_price), 2) AS avg_list_price,
        ROUND(AVG(sale_price), 2) AS avg_sale_price,
        ROUND(
            AVG(
                100.0 * (list_price - sale_price)
                / NULLIF(list_price, 0)
            ),
            2
        ) AS avg_discount_pct,
        SUM(CASE WHEN sale_price > list_price THEN 1 ELSE 0 END)
            AS variants_sale_above_list
    FROM active_prices
    WHERE price_rank = 1
    GROUP BY product_id, price_list_name, currency
)
SELECT
    c.category_name,
    p.product_id,
    p.product_name,
    r.review_count,
    r.average_rating,
    ps.price_list_name,
    ps.currency,
    ps.variant_price_count,
    ps.avg_list_price,
    ps.avg_sale_price,
    ps.avg_discount_pct,
    ps.variants_sale_above_list
FROM targets t
JOIN ecom.products p
    ON t.product_id = p.product_id
JOIN ecom.categories c
    ON p.category_id = c.category_id
LEFT JOIN review_summary r
    ON p.product_id = r.product_id
LEFT JOIN price_summary ps
    ON p.product_id = ps.product_id
ORDER BY c.category_name, p.product_id, ps.currency;
```

### Results: review and price-list summary

| category_name | product_id | product_name | review_count | average_rating | price_list_name | currency | variant_price_count | avg_list_price | avg_sale_price | avg_discount_pct | variants_sale_above_list |
| --- | ---: | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| category_name | product_id | product_name | review_count | average_rating | price_list_name | currency | variant_price_count | avg_list_price | avg_sale_price | avg_discount_pct | variants_sale_above_list |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Accessories | 127 | Ivory & Oak Classic Canvas Tote | 2 | 4.5 | INDIA | INR | 1 | 599 | 524.12 | 12.5 | 0 |
| Accessories | 127 | Ivory & Oak Classic Canvas Tote | 2 | 4.5 | US | USD | 1 | 7.17 |  |  | 0 |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 3 | 4 | INDIA | INR | 5 | 1,899 |  |  | 0 |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 3 | 4 | US | USD | 5 | 22.74 | 13.86 | 11.41 | 0 |
| Decor | 1,227 | Dhaaga Scandinavian Photo Frame Set |  |  | INDIA | INR | 2 | 2,249 | 2,098.68 | 16.02 | 0 |
| Decor | 1,227 | Dhaaga Scandinavian Photo Frame Set |  |  | US | USD | 2 | 26.94 |  |  | 0 |
| Jackets | 3,921 | Drift & Dwell Classic Windcheater | 1 | 1 | INDIA | INR | 6 | 2,482.33 | 1,756.81 | 16.84 | 0 |
| Jackets | 3,921 | Drift & Dwell Classic Windcheater | 1 | 1 | US | USD | 6 | 29.73 | 36.02 | 16.43 | 0 |
| Jeans | 1,254 | Windrose Distressed Relaxed Jeans | 2 | 4.5 | INDIA | INR | 4 | 1,674 | 1,944.11 | 13.67 | 0 |
| Jeans | 1,254 | Windrose Distressed Relaxed Jeans | 2 | 4.5 | US | USD | 4 | 20.05 | 14.56 | 12.94 | 0 |
| Kitchen | 3,257 | Silverbirch Works Stoneware Coffee French Press | 1 | 5 | INDIA | INR | 1 | 249 | 211.24 | 15.16 | 0 |
| Kitchen | 3,257 | Silverbirch Works Stoneware Coffee French Press | 1 | 5 | US | USD | 1 | 2.98 | 2.75 | 7.72 | 0 |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 5 | 4 | INDIA | INR | 3 | 515.67 | 241.1 | 19.36 | 0 |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 5 | 4 | US | USD | 3 | 6.18 | 2.97 | 17.18 | 0 |
| Makeup | 2,883 | Suta Threads Velvet Kajal | 1 | 4 | INDIA | INR | 5 | 639 |  |  | 0 |
| Makeup | 2,883 | Suta Threads Velvet Kajal | 1 | 4 | US | USD | 5 | 7.65 |  |  | 0 |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 3 | 3.33 | INDIA | INR | 6 | 8,065.67 | 6,189.12 | 16.79 | 0 |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 3 | 3.33 | US | USD | 6 | 96.6 | 69.16 | 12.39 | 0 |
| Tops | 1,273 | Indigo Lane Origins Essential Crop Top | 2 | 5 | INDIA | INR | 4 | 661.5 | 633.42 | 15.43 | 0 |
| Tops | 1,273 | Indigo Lane Origins Essential Crop Top | 2 | 5 | US | USD | 4 | 7.92 | 7.61 | 15.41 | 0 |

### SQL: retrieve review text

```
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
```

### Review text results for the ten selected products

| Category | Product ID | Product | Rating | Title | Review text | Created at |
| --- | ---: | --- | ---: | --- | ---: | --- |
| Accessories | 127 | Ivory & Oak Classic Canvas Tote | 4 | Almost perfect | Gifted this to my sister and holds shape even after several washes, and fabric feels premium. Only gripe: colour faded after two washes. Would still recommend it. | June 8, 2026, 8:59 PM |
| Accessories | 127 | Ivory & Oak Classic Canvas Tote | 5 | Impressed | Was skeptical at first but stitching is neat throughout. My new go-to. | May 26, 2026, 9:26 AM |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 5 | Exceeded expectations | Ordered during the sale and keeps cool through the night, and fits our mattress perfectly. Worth every rupee. | June 28, 2026, 11:06 PM |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 5 | Just buy it | Was skeptical at first but colours have not faded. Five stars from me. | June 15, 2026, 2:34 AM |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 2 | Wouldn't buy again | Expected much better. elastic gave out within a month, and on top of that colour bled onto other laundry. Expected more at this price point. | June 13, 2026, 12:50 AM |
| Jackets | 3,921 | Drift & Dwell Classic Windcheater | 1 | Terrible | Really disappointed — runs a size small, and on top of that fabric feels thin and cheap. Requested a refund immediately. | May 26, 2026, 2:55 AM |
| Jeans | 1,254 | Windrose Distressed Relaxed Jeans | 5 | Excellent quality | Upgraded from a cheaper one and very comfortable for all-day wear. Highly recommend. | June 12, 2026, 5:26 PM |
| Jeans | 1,254 | Windrose Distressed Relaxed Jeans | 4 | Recommended | Ordered during the sale and the fit is spot on, and very comfortable for all-day wear. Only gripe: colour faded after two washes. Would still recommend it. | May 26, 2026, 4:00 PM |
| Kitchen | 3,257 | Silverbirch Works Stoneware Coffee French Press | 5 | Just buy it | After a month of daily use, feels like restaurant-grade quality, and cleanup takes seconds. Would buy again without thinking. | June 21, 2026, 7:49 PM |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 4 | Solid product | Ordered during the sale and absorbed quickly without stickiness, and did not break me out. Only gripe: texture is greasy and heavy. Good value overall. | June 14, 2026, 9:55 AM |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 5 | Great purchase | Ordered during the sale and a little goes a long way. My new go-to. | May 25, 2026, 4:16 AM |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 1 | Waste of money | Hard to recommend — texture is greasy and heavy, and on top of that broke me out within days. Avoid this one. | May 16, 2026, 5:30 PM |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 5 | Impressed | Was skeptical at first but noticeable glow within two weeks, and a little goes a long way. Five stars from me. | May 5, 2026, 1:46 PM |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 5 | Exceeded expectations | Upgraded from a cheaper one and fragrance is subtle and pleasant. My new go-to. | April 18, 2026, 1:29 PM |
| Makeup | 2,883 | Suta Threads Velvet Kajal | 4 | Very good | Honestly impressed — fragrance is subtle and pleasant, and did not break me out. Only gripe: texture is greasy and heavy. Would still recommend it. | May 21, 2026, 9:16 PM |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 4 | Recommended | Upgraded from a cheaper one and pairing is instant every time. Only gripe: stopped charging after a month. Happy with the purchase. | July 6, 2026, 9:44 PM |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 5 | Exceeded expectations | Upgraded from a cheaper one and sound quality is crisp with deep bass, and build quality feels solid. Would buy again without thinking. | May 20, 2026, 5:54 AM |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 1 | Waste of money | Wanted to love this but battery drains overnight even on standby. Requested a refund immediately. | May 14, 2026, 5:34 AM |
| Tops | 1,273 | Indigo Lane Origins Essential Crop Top | 5 | Exceeded expectations | Honestly impressed — very comfortable for all-day wear, and colour matches the photos exactly. My new go-to. | May 20, 2026, 8:01 PM |
| Tops | 1,273 | Indigo Lane Origins Essential Crop Top | 5 | Great purchase | Was skeptical at first but stitching is neat throughout, and true to size. Five stars from me. | April 14, 2026, 8:31 PM |

The review sample is small. Specific complaints in the available reviews include fit/fabric for the windcheater, elastic/color bleeding for the bedsheet, texture/skin reaction for the eyeshadow palette, and charging/battery issues for the smartwatch. These are hypotheses to investigate, not established causes. Some reviews predate April 19, 2026, so they fall outside the aligned event/order period.

---

## 6. Funnel Analysis

The event schema shows that product_view and add_to_cart have product and variant identifiers. purchase has an order_id but no product identifier. Checkout, address, shipping, and payment events are session-level. Purchases were therefore attributed to products by joining session_events.order_id to order_items and then to product_variants.

### SQL: product funnel compared with category peers

```
WITH targets(product_id) AS (
    VALUES
        (801), (2883), (3257), (1048), (1273),
        (1227), (3002), (3921), (127), (1254)
),
target_categories AS (
    SELECT DISTINCT p.category_id
    FROM ecom.products p
    JOIN targets t ON p.product_id = t.product_id
),
product_views AS (
    SELECT
        se.session_id,
        se.product_id,
        MIN(se.occurred_at) AS first_view_at
    FROM ecom.session_events se
    JOIN ecom.products p ON se.product_id = p.product_id
    JOIN target_categories tc ON p.category_id = tc.category_id
    WHERE se.event_type = 'product_view'
      AND se.occurred_at >= DATE '2026-04-19'
    GROUP BY se.session_id, se.product_id
),
cart_events AS (
    SELECT session_id, product_id, occurred_at AS cart_at
    FROM ecom.session_events
    WHERE event_type = 'add_to_cart'
      AND product_id IS NOT NULL
),
purchase_products AS (
    SELECT
        se.session_id,
        pv.product_id,
        se.occurred_at AS purchase_at
    FROM ecom.session_events se
    JOIN ecom.order_items oi ON se.order_id = oi.order_id
    JOIN ecom.product_variants pv ON oi.variant_id = pv.variant_id
    WHERE se.event_type = 'purchase'
      AND se.order_id IS NOT NULL
),
view_cart_sessions AS (
    SELECT
        v.session_id,
        v.product_id,
        v.first_view_at,
        MIN(c.cart_at) AS first_cart_at
    FROM product_views v
    LEFT JOIN cart_events c
        ON c.session_id = v.session_id
       AND c.product_id = v.product_id
       AND c.cart_at >= v.first_view_at
    GROUP BY v.session_id, v.product_id, v.first_view_at
),
session_stages AS (
    SELECT
        vc.session_id,
        vc.product_id,
        vc.first_cart_at,
        MIN(
            CASE WHEN pp.purchase_at >= vc.first_view_at
                 THEN pp.purchase_at END
        ) AS purchase_after_view_at,
        MIN(
            CASE WHEN vc.first_cart_at IS NOT NULL
                   AND pp.purchase_at >= vc.first_cart_at
                 THEN pp.purchase_at END
        ) AS purchase_after_cart_at
    FROM view_cart_sessions vc
    LEFT JOIN purchase_products pp
        ON pp.session_id = vc.session_id
       AND pp.product_id = vc.product_id
    GROUP BY vc.session_id, vc.product_id, vc.first_cart_at
),
product_funnel AS (
    SELECT
        product_id,
        COUNT(*) AS viewed_sessions,
        SUM(CASE WHEN first_cart_at IS NOT NULL THEN 1 ELSE 0 END)
            AS cart_sessions,
        SUM(CASE WHEN purchase_after_view_at IS NOT NULL THEN 1 ELSE 0 END)
            AS purchase_sessions,
        SUM(CASE WHEN purchase_after_cart_at IS NOT NULL THEN 1 ELSE 0 END)
            AS purchases_after_cart
    FROM session_stages
    GROUP BY product_id
),
product_metrics AS (
    SELECT
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name,
        f.viewed_sessions,
        f.cart_sessions,
        f.purchase_sessions,
        f.purchases_after_cart,
        ROUND(
            100.0 * f.cart_sessions / NULLIF(f.viewed_sessions, 0), 2
        ) AS view_to_cart_pct,
        ROUND(
            100.0 * f.purchase_sessions / NULLIF(f.viewed_sessions, 0), 2
        ) AS view_to_purchase_pct,
        ROUND(
            100.0 * f.purchases_after_cart / NULLIF(f.cart_sessions, 0), 2
        ) AS cart_to_purchase_pct
    FROM product_funnel f
    JOIN ecom.products p ON f.product_id = p.product_id
    JOIN ecom.categories c ON p.category_id = c.category_id
    WHERE f.viewed_sessions >= 100
),
peer_benchmarks AS (
    SELECT
        pm.category_id,
        COUNT(*) AS peer_product_count,
        SUM(pm.viewed_sessions) AS peer_viewed_sessions,
        ROUND(
            100.0 * SUM(pm.cart_sessions)
            / NULLIF(SUM(pm.viewed_sessions), 0), 2
        ) AS peer_view_to_cart_pct,
        ROUND(
            100.0 * SUM(pm.purchase_sessions)
            / NULLIF(SUM(pm.viewed_sessions), 0), 2
        ) AS peer_view_to_purchase_pct,
        ROUND(
            100.0 * SUM(pm.purchases_after_cart)
            / NULLIF(SUM(pm.cart_sessions), 0), 2
        ) AS peer_cart_to_purchase_pct
    FROM product_metrics pm
    LEFT JOIN targets t ON pm.product_id = t.product_id
    WHERE t.product_id IS NULL
    GROUP BY pm.category_id
)
SELECT
    pm.category_name,
    pm.product_id,
    pm.product_name,
    pm.viewed_sessions,
    pm.cart_sessions,
    pm.view_to_cart_pct,
    pm.purchase_sessions,
    pm.view_to_purchase_pct,
    pm.purchases_after_cart,
    pm.cart_to_purchase_pct,
    pb.peer_product_count,
    pb.peer_viewed_sessions,
    pb.peer_view_to_cart_pct,
    pb.peer_view_to_purchase_pct,
    pb.peer_cart_to_purchase_pct
FROM product_metrics pm
JOIN targets t ON pm.product_id = t.product_id
LEFT JOIN peer_benchmarks pb ON pm.category_id = pb.category_id
ORDER BY pm.category_name, pm.product_name;
```

### Funnel and peer-benchmark results

| category_name | product_id | product_name | viewed_sessions | cart_sessions | view_to_cart_pct | purchase_sessions | view_to_purchase_pct | purchases_after_cart | cart_to_purchase_pct | peer_product_count | peer_viewed_sessions | peer_view_to_cart_pct | peer_view_to_purchase_pct | peer_cart_to_purchase_pct |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Accessories | 127 | Ivory & Oak Classic Canvas Tote | 262 | 14 | 5.34 | 4 | 1.53 | 4 | 28.57 | 13 | 1,786 | 13.38 | 7.45 | 55.65 |
| Bedding | 3,002 | Cedarline Percale Cotton Bedsheet Set | 1,453 | 101 | 6.95 | 15 | 1.03 | 15 | 14.85 | 12 | 2,422 | 11.77 | 6.15 | 52.28 |
| Decor | 1,227 | Dhaaga Scandinavian Photo Frame Set | 682 | 33 | 4.84 | 6 | 0.88 | 6 | 18.18 | 11 | 1,792 | 13.17 | 7.42 | 56.36 |
| Jackets | 3,921 | Drift & Dwell Classic Windcheater | 1,436 | 98 | 6.82 | 18 | 1.25 | 18 | 18.37 | 16 | 3,482 | 14.65 | 8.21 | 56.08 |
| Jeans | 1,254 | Windrose Distressed Relaxed Jeans | 608 | 55 | 9.05 | 10 | 1.64 | 10 | 18.18 | 17 | 3,233 | 13.49 | 7.45 | 55.28 |
| Kitchen | 3,257 | Silverbirch Works Stoneware Coffee French Press | 962 | 59 | 6.13 | 6 | 0.62 | 6 | 10.17 | 9 | 1,802 | 12.15 | 7.16 | 58.9 |
| Makeup | 801 | Indigo Lane Origins Longwear Eyeshadow Palette | 2,577 | 153 | 5.94 | 8 | 0.31 | 8 | 5.23 | 20 | 3,992 | 11.75 | 5.86 | 49.89 |
| Makeup | 2,883 | Suta Threads Velvet Kajal | 4,165 | 259 | 6.22 | 12 | 0.29 | 12 | 4.63 | 20 | 3,992 | 11.75 | 5.86 | 49.89 |
| Smartwatch | 1,048 | Silverbirch Vital Hybrid Watch | 1,818 | 113 | 6.22 | 16 | 0.88 | 16 | 14.16 | 8 | 2,386 | 10.52 | 5.07 | 48.21 |
| Tops | 1,273 | Indigo Lane Origins Essential Crop Top | 903 | 59 | 6.53 | 9 | 1 | 9 | 15.25 | 17 | 2,604 | 13.25 | 8.03 | 60.58 |

A separate event summary showed that purchase events have order_id but no product_id; add_to_cart has product and variant identifiers; and checkout/address/shipping/payment events have no product or order identifiers. Therefore, checkout-stage behavior can be studied at session level, but not reliably attributed to a specific product using these columns alone.

---

## 7. Overall Conclusion

At category level, no category shows the hypothesized 3–5× imbalance. Makeup is the largest category-level outlier at 1.70×, while the other categories are close to balanced or have purchase share at least as high as view share.

At product level, the global view-share-to-purchase-share ratio highlights products that receive much more of the catalogue’s views than of its product-order occurrences. The top five per category table contains all 70 shortlisted products; a focused set of ten was then used for further diagnosis.

The ten selected products underperform their category peers across the observed product funnel. Their view-to-cart rates range from 4.84% to 9.05%, compared with peer rates from 10.52% to 14.65%. Their view-to-purchase rates range from 0.29% to 1.64%, versus peer rates from 5.07% to 8.21%. Their cart-to-purchase rates range from 4.63% to 28.57%, versus peer rates from 48.21% to 60.58%. The largest gaps appear for the two Makeup products.

Review comments suggest possible fit, product-quality, texture/skin-reaction, and battery/charging concerns for some products. The review counts are small, so these are hypotheses rather than proven causes. Prices were evaluated separately by price list and currency using records valid on April 19, 2026; the available results do not establish a consistent price explanation.

**Conclusion:** The analysis identifies a set of high-view products with much weaker purchase activity than same-category peers. It does not establish one causal explanation. Reviews point to potential product-experience issues for some SKUs, but stronger review, return, or customer-level evidence would be needed to confirm the reasons.
