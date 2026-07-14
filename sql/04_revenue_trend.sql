-- Monthly revenue trend (MRR proxy).
-- Aggregates Sales by month, computes month-over-month growth %.

WITH monthly AS (
    SELECT
        STRFTIME('%Y-%m', "Order Date")    AS month,
        ROUND(SUM(Sales), 2)               AS revenue,
        COUNT(DISTINCT "Customer ID")      AS active_customers,
        COUNT(*)                           AS total_orders
    FROM orders
    GROUP BY month
),

with_growth AS (
    SELECT
        month,
        revenue,
        active_customers,
        total_orders,
        LAG(revenue) OVER (ORDER BY month) AS prev_revenue
    FROM monthly
)

SELECT
    month,
    revenue,
    active_customers,
    total_orders,
    ROUND((revenue - prev_revenue) * 100.0 / prev_revenue, 1) AS mom_growth_pct
FROM with_growth
ORDER BY month;
