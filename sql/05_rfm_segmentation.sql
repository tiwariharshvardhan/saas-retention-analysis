-- RFM segmentation: score each customer 1–5 on Recency, Frequency, Monetary,
-- then map to a named segment.
--
-- Recency  = days since last order (fewer = better → higher score)
-- Frequency = number of orders (more = better)
-- Monetary  = total sales (higher = better)
--
-- Reference date = the latest order date in the dataset (not real "today"),
-- so recency is measured relative to the data, not the calendar.

WITH ref AS (
    SELECT DATE(MAX("Order Date")) AS ref_date FROM orders
),

customer_rfm AS (
    SELECT
        "Customer ID"                                              AS customer_id,
        CAST(JULIANDAY((SELECT ref_date FROM ref))
             - JULIANDAY(DATE(MAX("Order Date"))) AS INTEGER)      AS recency_days,
        COUNT(*)                                                   AS frequency,
        ROUND(SUM(Sales), 2)                                       AS monetary
    FROM orders
    GROUP BY "Customer ID"
),

scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- Recency: lower days = better, so invert the ntile order.
        6 - NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)         AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)          AS m_score
    FROM customer_rfm
),

segmented AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
            WHEN f_score >= 4                  THEN 'Loyal'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New'
            ELSE 'Lost'
        END AS segment
    FROM scored
)

SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    segment
FROM segmented
ORDER BY monetary DESC;
