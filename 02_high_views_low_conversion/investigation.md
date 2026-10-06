

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

### Results: requested category shortlist (global calculation)

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

### Interpreting the shortlist

Tiny products with zero purchases and only 1–7 views are not useful diagnostic leads: their extreme or undefined ratios are driven by too little exposure to support a meaningful comparison. The view threshold reduces this noise. By contrast, products with substantial traffic and relatively few orders are stronger leads. Examples from the results include Cedarline Percale Cotton Bedsheet Set (1,469 views, 15 orders, 22.46×), TickTone Essentials Sateen Duvet Cover (171 views, 2 orders, 19.6×), Dhaaga Scandinavian Photo Frame Set (691 views, 7 orders, 22.63×), Drift & Dwell Classic Windcheater (1,455 views, 19 orders, 17.56×), and Moksha Living Lightweight Hooded Jacket (1,226 views, 17 orders, 16.54×).

### Within-category calculation

The alternative within-category ratio compares each product's share of its own category's views with its share of its own category's orders. This query uses the same exposure cutoff and returns the top five products per category.

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

The within-category ranking is similar to the global ranking because both ratios are proportional to the product's views-to-orders relationship, with category-specific or global denominators scaling the ratio. Since the original hypothesis compares category view share against global view share and purchase share, retain the global ratio as the primary metric for consistency with the category analysis.

### Next diagnostic direction

For the shortlisted products, compare **price, discount, rating, review count, and browsing/exposure factors** with other products in the same category. This will help test three possible explanations: price sensitivity, quality or review concerns, and differences in browsing-surface exposure. The ratio identifies products to investigate; these comparisons are needed to examine what may explain their view-to-order imbalance.
