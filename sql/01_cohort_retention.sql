-- Cohort retention: for each monthly signup cohort, count how many customers
-- placed an order in each subsequent month (M0–M6).
--
-- "Signup" = month of a customer's first order.
-- Retention at Mn = customer placed at least one order n months after cohort month.

WITH first_orders AS (
    SELECT
        "Customer ID"                                                AS customer_id,
        DATE(MIN("Order Date"))                                      AS first_order_date,
        STRFTIME('%Y-%m', MIN("Order Date"))                        AS cohort_month
    FROM orders
    GROUP BY "Customer ID"
),

all_orders AS (
    SELECT
        "Customer ID"  AS customer_id,
        DATE("Order Date") AS order_date
    FROM orders
),

cohort_orders AS (
    SELECT
        f.cohort_month,
        f.customer_id,
        -- months between cohort month and this order's month
        (CAST(STRFTIME('%Y', a.order_date) AS INTEGER) - CAST(STRFTIME('%Y', f.first_order_date) AS INTEGER)) * 12
        + (CAST(STRFTIME('%m', a.order_date) AS INTEGER) - CAST(STRFTIME('%m', f.first_order_date) AS INTEGER))
            AS months_since_cohort
    FROM first_orders f
    JOIN all_orders a ON a.customer_id = f.customer_id
    WHERE months_since_cohort BETWEEN 0 AND 6
),

cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM first_orders
    GROUP BY cohort_month
),

retained AS (
    SELECT cohort_month, months_since_cohort, COUNT(DISTINCT customer_id) AS retained_customers
    FROM cohort_orders
    GROUP BY cohort_month, months_since_cohort
)

SELECT
    r.cohort_month,
    s.cohort_size,
    r.months_since_cohort                                           AS month_number,
    r.retained_customers,
    ROUND(r.retained_customers * 100.0 / s.cohort_size, 1)         AS retention_pct
FROM retained r
JOIN cohort_sizes s ON s.cohort_month = r.cohort_month
ORDER BY r.cohort_month, r.months_since_cohort;
