# May-13 Revenue Cliff Investigation

## Problem

The case says revenue dropped sharply on May 13. I wanted to first check if the drop was actually visible in the data and then find out what changed on that day.

---

## 1. Baseline Analysis

I started by checking daily orders, revenue and AOV from May 1 to May 20.

### Query

```sql
SELECT
    DATE(created_at) AS order_date,
    COUNT(DISTINCT order_id) AS orders,
    SUM(total) AS revenue,
    SUM(total) / COUNT(DISTINCT order_id) AS aov
FROM ecom.orders
WHERE created_at >= '2026-05-01'
  AND created_at < '2026-05-21'
GROUP BY DATE(created_at)
ORDER BY order_date;
```
| order_date   | orders | revenue      | aov      |
|--------------|-------:|-------------:|---------:|
| May 1, 2026  | 286    | 22,88,592.82 | 8,002.07 |
| May 2, 2026  | 433    | 33,22,423.58 | 7,673.03 |
| May 3, 2026  | 424    | 33,17,579.74 | 7,824.48 |
| May 4, 2026  | 385    | 28,91,274.50 | 7,509.80 |
| May 5, 2026  | 320    | 23,06,352.84 | 7,207.35 |
| May 6, 2026  | 326    | 27,37,478.66 | 8,397.17 |
| May 7, 2026  | 341    | 27,87,220.84 | 8,173.67 |
| May 8, 2026  | 316    | 21,98,813.56 | 6,958.27 |
| May 9, 2026  | 351    | 27,11,131.66 | 7,724.02 |
| May 10, 2026 | 361    | 25,89,363.88 | 7,172.75 |
| May 11, 2026 | 297    | 21,68,488.58 | 7,301.31 |
| May 12, 2026 | 302    | 20,27,728.88 | 6,714.33 |
| **May 13, 2026** | **298** | **18,84,969.96** | **6,325.40** |
| May 14, 2026 | 289    | 20,17,223.04 | 6,980.01 |
| May 15, 2026 | 288    | 24,06,585.72 | 8,356.20 |
| May 16, 2026 | 335    | 26,44,893.96 | 7,895.21 |
| May 17, 2026 | 303    | 23,78,738.34 | 7,850.62 |
| May 18, 2026 | 387    | 28,66,389.42 | 7,406.69 |
| May 19, 2026 | 324    | 23,92,945.10 | 7,385.63 |
| May 20, 2026 | 314    | 25,00,107.96 | 7,962.13 |


### What I found

May 13 had the lowest revenue in this period.

- Orders: 298
- Revenue: ₹18,84,969.96
- AOV: ₹6,325.40

The number of orders was not much different from the days around it. The bigger change was in AOV, which was the lowest during the period.

The data also did not show a 60% revenue drop. So I did not assume the case description was correct and moved on to payment failures.

### Realized Revenue Check

I reran the same analysis using only orders where `payment_status = 'paid'`.

### Query

```sql
SELECT
    DATE(created_at) AS order_date,
    COUNT(DISTINCT order_id) AS orders,
    SUM(total) AS revenue,
    SUM(total) / COUNT(DISTINCT order_id) AS aov
FROM ecom.orders
WHERE created_at >= '2026-05-01'
  AND created_at < '2026-05-21'
  AND payment_status = 'paid'
GROUP BY DATE(created_at)
ORDER BY order_date;
```
| order_date       | orders  | revenue         | aov          |
| ---------------- | ------- | --------------- | ------------ |
| May 1, 2026      | 270     | 21,77,124.56    | 8,063.42     |
| May 2, 2026      | 416     | 32,33,912.22    | 7,773.83     |
| May 3, 2026      | 406     | 31,44,508.54    | 7,745.09     |
| May 4, 2026      | 361     | 27,38,593.40    | 7,586.13     |
| May 5, 2026      | 311     | 22,40,887.62    | 7,205.43     |
| May 6, 2026      | 311     | 26,37,782.96    | 8,481.62     |
| May 7, 2026      | 320     | 26,83,070.20    | 8,384.59     |
| May 8, 2026      | 301     | 20,86,164.12    | 6,930.78     |
| May 9, 2026      | 333     | 25,90,820.48    | 7,780.24     |
| May 10, 2026     | 347     | 24,81,583.26    | 7,151.54     |
| May 11, 2026     | 287     | 21,06,445.80    | 7,339.53     |
| May 12, 2026     | 290     | 19,48,573.74    | 6,719.22     |
| **May 13, 2026** | **141** | **8,75,269.90** | **6,207.59** |
| May 14, 2026     | 269     | 18,41,405.40    | 6,845.37     |
| May 15, 2026     | 275     | 23,29,698.10    | 8,471.63     |
| May 16, 2026     | 323     | 24,74,515.08    | 7,661.04     |
| May 17, 2026     | 283     | 22,09,994.06    | 7,809.17     |
| May 18, 2026     | 365     | 27,33,704.32    | 7,489.60     |
| May 19, 2026     | 306     | 22,72,787.90    | 7,427.41     |
| May 20, 2026     | 300     | 23,61,501.62    | 7,871.67     |

What I found
The paid-order view shows a much clearer drop on May 13.
- Paid orders: 141
- Revenue: ₹8,75,269.90
- AOV: ₹6,207.59
Paid orders dropped from 290 on May 12 to 141 on May 13, while realized revenue dropped from ₹19,48,573.74 to ₹8,75,269.90.

---

## 2. Payment Status

I checked payment status around May 13 to see whether failed payments increased on the same day.


### Query

```sql
SELECT
    DATE(created_at) AS order_date,
    payment_status,
    COUNT(DISTINCT order_id) AS orders,
    SUM(total) AS order_value
FROM ecom.orders
WHERE created_at >= '2026-05-10'
  AND created_at < '2026-05-20'
GROUP BY
    DATE(created_at),
    payment_status
ORDER BY
    order_date,
    payment_status;
```
<img width="2164" height="644" alt="Metabase-New question-10_2_2026, 4_41_49 PM" src="https://github.com/user-attachments/assets/2a3bd94f-9954-4000-b30e-1bca36ebb7c1" />

### What I found

There was a clear increase in failed payments on May 13 compared with the surrounding days.

This made payment failure one of the main areas to investigate further.

---

## 3. Payment Method Investigation

After seeing the increase in payment failures on May 13, I drilled down by payment method to see where the spike was coming from.

### Query

```sql
SELECT
    DATE(o.created_at) AS order_date,
    pm.method_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE
        WHEN o.payment_status = 'failed'
             AND pt.status = 'failed'
        THEN o.order_id
    END) AS failed_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.payment_status = 'failed'
                 AND pt.status = 'failed'
            THEN o.order_id
        END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS failure_rate
FROM ecom.orders o
JOIN ecom.payment_intents pi
    ON o.order_id = pi.order_id
JOIN ecom.payment_methods pm
    ON pi.payment_method_id = pm.payment_method_id
JOIN ecom.payment_transactions pt
    ON pi.payment_intent_id = pt.payment_intent_id
WHERE
    o.created_at >= '2026-05-10'
    AND o.created_at < '2026-05-20'
GROUP BY
    DATE(o.created_at),
    pm.method_name
ORDER BY
    order_date,
    pm.method_name;
```
| order_date   | method_name | total_orders | failed_orders | failure_rate |
| ------------ | ----------- | ------------ | ------------- | ------------ |
| May 10, 2026 | card        | 122          | 5             | 4.1          |
| May 10, 2026 | cod         | 36           | 1             | 2.78         |
| May 10, 2026 | netbanking  | 34           | 0             | 0            |
| May 10, 2026 | upi         | 120          | 4             | 3.33         |
| May 10, 2026 | wallet      | 49           | 1             | 2.04         |
| May 11, 2026 | card        | 106          | 4             | 3.77         |
| May 11, 2026 | cod         | 30           | 0             | 0            |
| May 11, 2026 | netbanking  | 38           | 1             | 2.63         |
| May 11, 2026 | upi         | 82           | 2             | 2.44         |
| May 11, 2026 | wallet      | 41           | 1             | 2.44         |
| May 12, 2026 | card        | 100          | 4             | 4            |
| May 12, 2026 | cod         | 44           | 2             | 4.55         |
| May 12, 2026 | netbanking  | 21           | 0             | 0            |
| May 12, 2026 | upi         | 90           | 2             | 2.22         |
| May 12, 2026 | wallet      | 47           | 3             | 6.38         |
| **May 13, 2026** | **card** | **49** | **6** | **12.24** |
| **May 13, 2026** | **cod** | **21** | **1** | **4.76** |
| **May 13, 2026** | **netbanking** | **18** | **2** | **11.11** |
| **May 13, 2026** | **upi** | **195** | **140** | **71.79** |
| **May 13, 2026** | **wallet** | **15** | **1** | **6.67** |
| May 14, 2026 | card        | 107          | 7             | 6.54         |
| May 14, 2026 | cod         | 39           | 4             | 10.26        |
| May 14, 2026 | netbanking  | 21           | 1             | 4.76         |
| May 14, 2026 | upi         | 83           | 2             | 2.41         |
| May 14, 2026 | wallet      | 39           | 3             | 7.69         |
| May 15, 2026 | card        | 103          | 4             | 3.88         |
| May 15, 2026 | cod         | 41           | 0             | 0            |
| May 15, 2026 | netbanking  | 35           | 0             | 0            |
| May 15, 2026 | upi         | 72           | 3             | 4.17         |
| May 15, 2026 | wallet      | 37           | 3             | 8.11         |
| May 16, 2026 | card        | 110          | 4             | 3.64         |
| May 16, 2026 | cod         | 44           | 0             | 0            |
| May 16, 2026 | netbanking  | 37           | 1             | 2.7          |
| May 16, 2026 | upi         | 106          | 4             | 3.77         |
| May 16, 2026 | wallet      | 38           | 0             | 0            |
| May 17, 2026 | card        | 114          | 6             | 5.26         |
| May 17, 2026 | cod         | 29           | 3             | 10.34        |
| May 17, 2026 | netbanking  | 29           | 1             | 3.45         |
| May 17, 2026 | upi         | 102          | 6             | 5.88         |
| May 17, 2026 | wallet      | 29           | 1             | 3.45         |
| May 18, 2026 | card        | 133          | 4             | 3.01         |
| May 18, 2026 | cod         | 52           | 2             | 3.85         |
| May 18, 2026 | netbanking  | 29           | 1             | 3.45         |
| May 18, 2026 | upi         | 121          | 6             | 4.96         |
| May 18, 2026 | wallet      | 52           | 4             | 7.69         |
| May 19, 2026 | card        | 117          | 3             | 2.56         |
| May 19, 2026 | cod         | 39           | 2             | 5.13         |
| May 19, 2026 | netbanking  | 38           | 1             | 2.63         |
| May 19, 2026 | upi         | 88           | 5             | 5.68         |
| May 19, 2026 | wallet      | 42           | 2             | 4.76         |

### What I found
The payment failure spike on May 13 was mainly concentrated in UPI.
On May 13, UPI had a failure rate of 71.79%, compared with 2.22% on May 12. The other payment methods had much lower failure rates:
UPI accounted for 140 of the 150 failed orders on May 13.
This confirmed that UPI was the main payment method affected, so I then checked whether the failures were coming from one particular gateway.

## 4. Payment Gateway Investigation
Next, I checked whether the payment failures within UPI were coming from one particular gateway.
### Query

```sql
SELECT
    DATE(o.created_at) AS order_date,
    pt.gateway,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE
        WHEN o.payment_status = 'failed'
             AND pt.status = 'failed'
        THEN o.order_id
    END) AS failed_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.payment_status = 'failed'
                 AND pt.status = 'failed'
            THEN o.order_id
        END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS failure_rate
FROM ecom.orders o
JOIN ecom.payment_intents pi
    ON o.order_id = pi.order_id
JOIN ecom.payment_methods pm
    ON pi.payment_method_id = pm.payment_method_id
JOIN ecom.payment_transactions pt
    ON pi.payment_intent_id = pt.payment_intent_id
WHERE
    o.created_at >= '2026-05-10'
    AND o.created_at < '2026-05-20'
    AND pm.method_name = 'upi'
GROUP BY
    DATE(o.created_at),
    pt.gateway
ORDER BY
    order_date,
    pt.gateway;
```

| order_date   | gateway  | total_orders | failed_orders | failure_rate |
|--------------|----------|-------------:|-------------:|-------------:|
| May 10, 2026 | cash     | 14           | 1            | 7.14         |
| May 10, 2026 | payu     | 19           | 0            | 0            |
| May 10, 2026 | razorpay | 60           | 3            | 5            |
| May 10, 2026 | stripe   | 27           | 0            | 0            |
| May 11, 2026 | cash     | 16           | 1            | 6.25         |
| May 11, 2026 | payu     | 16           | 0            | 0            |
| May 11, 2026 | razorpay | 33           | 0            | 0            |
| May 11, 2026 | stripe   | 17           | 1            | 5.88         |
| May 12, 2026 | cash     | 13           | 0            | 0            |
| May 12, 2026 | payu     | 14           | 0            | 0            |
| May 12, 2026 | razorpay | 48           | 1            | 2.08         |
| May 12, 2026 | stripe   | 15           | 1            | 6.67         |
| **May 13, 2026** | **cash**     | **32**  | **28** | **87.5** |
| **May 13, 2026** | **payu**     | **47**  | **30** | **63.83** |
| **May 13, 2026** | **razorpay** | **100** | **79** | **79** |
| **May 13, 2026** | **stripe**   | **37**  | **24** | **64.86** |
| May 14, 2026 | cash     | 10           | 0            | 0            |
| May 14, 2026 | payu     | 21           | 0            | 0            |
| May 14, 2026 | razorpay | 40           | 2            | 5            |
| May 14, 2026 | stripe   | 12           | 0            | 0            |
| May 15, 2026 | cash     | 9            | 0            | 0            |
| May 15, 2026 | payu     | 17           | 0            | 0            |
| May 15, 2026 | razorpay | 30           | 1            | 3.33         |
| May 15, 2026 | stripe   | 16           | 2            | 12.5         |
| May 16, 2026 | cash     | 13           | 0            | 0            |
| May 16, 2026 | payu     | 24           | 0            | 0            |
| May 16, 2026 | razorpay | 48           | 1            | 2.08         |
| May 16, 2026 | stripe   | 21           | 3            | 14.29        |
| May 17, 2026 | cash     | 13           | 0            | 0            |
| May 17, 2026 | payu     | 22           | 2            | 9.09         |
| May 17, 2026 | razorpay | 47           | 4            | 8.51         |
| May 17, 2026 | stripe   | 20           | 0            | 0            |
| May 18, 2026 | cash     | 18           | 0            | 0            |
| May 18, 2026 | payu     | 31           | 5            | 16.13        |
| May 18, 2026 | razorpay | 51           | 1            | 1.96         |
| May 18, 2026 | stripe   | 21           | 0            | 0            |
| May 19, 2026 | cash     | 9            | 0            | 0            |
| May 19, 2026 | payu     | 26           | 3            | 11.54        |
| May 19, 2026 | razorpay | 37           | 2            | 5.41         |
| May 19, 2026 | stripe   | 16           | 0            | 0            |

<img width="2164" height="644" alt="Metabase-New question-10_2_2026, 4_45_29 PM" src="https://github.com/user-attachments/assets/f685d683-dfe0-4aae-9ecb-e43372ea7b62" />


### What I found

On May 13, failure rates increased across multiple gateways:

| order_date   | gateway  | total_orders | failed_orders | failure_rate |
|--------------|----------|-------------:|-------------:|-------------:|
| **May 13, 2026** | **cash**     | **32**  | **28** | **87.5** |
| **May 13, 2026** | **payu**     | **47**  | **30** | **63.83** |
| **May 13, 2026** | **razorpay** | **100** | **79** | **79** |
| **May 13, 2026** | **stripe**   | **37**  | **24** | **64.86** |

Since the spike was present across multiple gateways, it did not look like an issue with just one provider.

---

## 5. Payment Failure Reason Investigation

I then checked the error codes for failed transactions on May 13.

### Query

```sql
SELECT
    gateway,
    error_code,
    error_message,
    COUNT(*) AS failed_transactions
FROM ecom.payment_transactions
WHERE txn_time >= '2026-05-13'
  AND txn_time < '2026-05-14'
  AND status = 'failed'
GROUP BY
    gateway,
    error_code,
    error_message
ORDER BY failed_transactions DESC;
```

### What I found

The main error was:

`GATEWAY_TIMEOUT - Gateway did not respond within 30s`

There were 168 failed transactions with this error:

| gateway  | error_code      | error_message                      | failed_transactions |
|----------|-----------------|------------------------------------|--------------------:|
| razorpay | GATEWAY_TIMEOUT | Gateway did not respond within 30s | 90                  |
| payu     | GATEWAY_TIMEOUT | Gateway did not respond within 30s | 28                  |
| cash     | GATEWAY_TIMEOUT | Gateway did not respond within 30s | 27                  |
| stripe   | GATEWAY_TIMEOUT | Gateway did not respond within 30s | 23                  |
| razorpay | NETWORK         | Payment failed                     | 3                   |
| razorpay | BANK_DECLINE    | Payment failed                     | 3                   |
| payu     | FRAUD           | Payment failed                     | 3                   |
| stripe   | BANK_DECLINE    | Payment failed                     | 2                   |
| stripe   | NETWORK         | Payment failed                     | 1                   |
| cash     | NETWORK         | Payment failed                     | 1                   |
| payu     | NETWORK         | Payment failed                     | 1                   |
| razorpay | FRAUD           | Payment failed                     | 1                   |
| razorpay | UPI_TIMEOUT     | Payment failed                     | 1                   |

Other errors such as bank declines, network errors and fraud checks were much smaller in comparison.

The same timeout appearing across different gateways made a shared payment infrastructure or dependency a more likely explanation than a problem with one gateway.

---
## 6. Outage Window

After identifying the payment failure spike on May 13, I broke the failed transactions down by hour to determine whether the issue lasted throughout the day or was concentrated within a specific time window.

### Query

```sql
SELECT
    DATE_TRUNC('hour', pt.txn_time) AS hour,
    COUNT(*) AS failed_transactions,
    COUNT(*) FILTER (
        WHERE pt.error_code = 'GATEWAY_TIMEOUT'
    ) AS gateway_timeouts
FROM ecom.payment_transactions pt
WHERE pt.txn_time >= '2026-05-13'
  AND pt.txn_time < '2026-05-14'
  AND pt.status = 'failed'
GROUP BY DATE_TRUNC('hour', pt.txn_time)
ORDER BY hour;
```
| hour | failed_transactions | gateway_timeouts |
|---|---:|---:|
| May 13, 2026, 6:00 AM | 1 | 0 |
| May 13, 2026, 9:00 AM | 15 | 15 |
| May 13, 2026, 10:00 AM | 23 | 21 |
| May 13, 2026, 11:00 AM | 16 | 15 |
| May 13, 2026, 12:00 PM | 12 | 11 |
| May 13, 2026, 1:00 PM | 24 | 22 |
| May 13, 2026, 2:00 PM | 27 | 27 |
| May 13, 2026, 3:00 PM | 32 | 27 |
| May 13, 2026, 4:00 PM | 31 | 30 |
| May 13, 2026, 5:00 PM | 1 | 0 |
| May 13, 2026, 6:00 PM | 1 | 0 |
| May 13, 2026, 11:00 PM | 1 | 0 |

#### What I found
The payment failure spike was concentrated in a specific window on May 13 rather than lasting throughout the entire day.
Gateway timeout failures first increased significantly around 9:00 AM and continued through 4:00 PM. The highest number of failed transactions occurred between 2:00 PM and 4:00 PM, with 27, 32 and 31 failed transactions respectively.
By 5:00 PM, failed transactions dropped back to 1 and there were no gateway timeouts, indicating that the issue had largely recovered.
Based on the hourly data, the main incident window was approximately 9:00 AM to 4:00 PM, with recovery by 5:00 PM.
The hourly analysis identifies the affected window, but it does not provide the exact minute when the incident started or ended.


## 6. Business Impact

I then checked which orders were linked to the gateway timeout failures.

### Query

```sql
WITH timeout_orders AS (
    SELECT DISTINCT
        pi.order_id
    FROM ecom.payment_transactions pt
    JOIN ecom.payment_intents pi
        ON pt.payment_intent_id = pi.payment_intent_id
    WHERE pt.txn_time >= '2026-05-13'
      AND pt.txn_time < '2026-05-14'
      AND pt.status = 'failed'
      AND pt.error_code = 'GATEWAY_TIMEOUT'
)
SELECT
    o.payment_status,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total) AS order_value
FROM ecom.orders o
JOIN timeout_orders t
    ON o.order_id = t.order_id
GROUP BY o.payment_status
ORDER BY orders DESC;
```

### Result

| payment_status | orders | order_value |
|---|---:|---:|
| failed | 134 | ₹8,66,262.50 |

### What this means

134 orders were affected by at least one gateway timeout on May 13.

The total value of these orders was ₹8,66,262.50, and all of them had a final payment status of `failed`.

I am treating this as affected order value and not confirmed lost revenue, since I cannot tell from the available data if any of these customers later placed another successful order.

---
## 7. Monday Morning Actions

Based on the investigation, I would recommend two safeguards to detect and mitigate a similar incident.

### 1. Add real-time payment failure monitoring and alerting

Set up monitoring for payment failure rates by **payment method, gateway and error type**, with an alert when the failure rate moves significantly above its normal baseline.

For example, the May 13 UPI failure rate reached **71.79%**, compared with **2.22%** on May 12. The gateway timeout spike was also concentrated between approximately **9:00 AM and 4:00 PM**.

An alert based on payment failure rate and `GATEWAY_TIMEOUT` errors would allow the operations team to identify the issue much earlier instead of discovering the revenue impact after the day has ended.

### 2. Add payment-method fallback and graceful degradation

Since the failure spike was concentrated in **UPI**, the checkout flow should detect when UPI is experiencing elevated failures and guide customers toward alternative payment methods such as cards, netbanking or wallets.

The system could temporarily reduce the prominence of the affected payment method or automatically surface alternative methods when its failure rate crosses a defined threshold.

This would reduce the dependency on a single payment rail and help preserve successful checkouts during a UPI outage.

### Expected impact

These safeguards address both sides of the incident:

- **Monitoring and alerting** would reduce the time taken to detect the problem.
- **Payment-method fallback** would reduce the number of customers unable to complete checkout while the affected payment rail is unavailable.

## Conclusion

May 13 experienced a sharp decline in realized revenue, driven primarily by a large increase in payment failures. The failure spike was concentrated in UPI, where the failure rate reached 71.79% compared with 2.22% on May 12. Multiple gateways handling UPI transactions were affected, and GATEWAY_TIMEOUT was the dominant failure reason.

The incident was concentrated approximately between 9:00 AM and 4:00 PM, with recovery by 5:00 PM. In total, 134 orders were linked to at least one gateway timeout, representing ₹8,66,262.50 in affected order value.

The available data identifies the affected payment method, gateways, error type and incident window, but does not reveal the underlying technical cause of the timeout.

Based on this, the payment system looks like the main reason behind the drop in revenue on May 13. Since the same timeout happened across multiple gateways, this looks more like a shared payment infrastructure issue than a problem with one gateway.

I could identify where the problem happened and how much order value was affected, but I cannot find the exact technical reason for the timeout from the data available to me.
