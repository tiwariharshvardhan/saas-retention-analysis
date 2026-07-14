-- Regional benchmarking: revenue, customer count, retention rate, and avg order
-- value by region. Retention rate = customers with >1 order / total customers.

WITH customer_order_counts AS (
    SELECT
        "Customer ID"   AS customer_id,
        Region          AS region,
        COUNT(*)        AS order_count
    FROM orders
    GROUP BY "Customer ID", Region
),

region_stats AS (
    SELECT
        region,
        COUNT(DISTINCT customer_id)                                          AS total_customers,
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)                   AS repeat_customers,
        ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0
              / COUNT(DISTINCT customer_id), 1)                              AS retention_rate_pct
    FROM customer_order_counts
    GROUP BY region
),

revenue_stats AS (
    SELECT
        Region                              AS region,
        ROUND(SUM(Sales), 2)               AS total_revenue,
        ROUND(AVG(Sales), 2)               AS avg_order_value,
        COUNT(*)                            AS total_orders
    FROM orders
    GROUP BY Region
)

SELECT
    r.region,
    r.total_customers,
    r.repeat_customers,
    r.retention_rate_pct,
    v.total_revenue,
    v.avg_order_value,
    v.total_orders
FROM region_stats r
JOIN revenue_stats v ON v.region = r.region
ORDER BY v.total_revenue DESC;
