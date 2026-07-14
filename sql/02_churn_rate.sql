-- Implied churn rate by month.
--
-- A customer is "churned" if they have no order within CHURN_MONTHS months
-- after their last purchase. CHURN_MONTHS is computed in pipeline.py from
-- the data (ceil(median_repurchase_interval * 2)) and substituted here at
-- runtime as the :churn_months parameter.
--
-- Active customers in a given month = placed at least one order in that month
-- OR placed an order within the last CHURN_MONTHS months.
-- Churned customers = last order was more than CHURN_MONTHS months ago
-- relative to the reporting month.

WITH last_order_per_customer AS (
    SELECT
        "Customer ID"                      AS customer_id,
        DATE(MAX("Order Date"))            AS last_order_date
    FROM orders
    GROUP BY "Customer ID"
),

-- All months in the dataset range
months AS (
    SELECT DISTINCT STRFTIME('%Y-%m', "Order Date") AS month
    FROM orders
),

customer_months AS (
    SELECT
        m.month,
        l.customer_id,
        l.last_order_date,
        -- months between last order and reporting month
        (CAST(STRFTIME('%Y', m.month || '-01') AS INTEGER) - CAST(STRFTIME('%Y', l.last_order_date) AS INTEGER)) * 12
        + (CAST(STRFTIME('%m', m.month || '-01') AS INTEGER) - CAST(STRFTIME('%m', l.last_order_date) AS INTEGER))
            AS months_since_last_order
    FROM months m
    CROSS JOIN last_order_per_customer l
    -- only include months after the customer's first appearance
    WHERE m.month >= STRFTIME('%Y-%m', l.last_order_date)
),

monthly_status AS (
    SELECT
        month,
        customer_id,
        CASE WHEN months_since_last_order > :churn_months THEN 1 ELSE 0 END AS is_churned
    FROM customer_months
)

SELECT
    month,
    COUNT(DISTINCT customer_id)                                          AS total_customers,
    SUM(is_churned)                                                      AS churned_customers,
    ROUND(SUM(is_churned) * 100.0 / COUNT(DISTINCT customer_id), 1)     AS churn_rate_pct
FROM monthly_status
GROUP BY month
ORDER BY month;
