-- Customer lifetime value and order behavior.
WITH completed_sales AS (
    SELECT f.*
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
), customer_metrics AS (
    SELECT
        c.source_customer_id,
        c.customer_name,
        c.customer_segment,
        c.region,
        COUNT(DISTINCT f.order_number) AS orders,
        SUM(f.revenue_amount) AS lifetime_revenue,
        SUM(f.profit_amount) AS lifetime_profit,
        MIN(d.calendar_date) AS first_purchase_date,
        MAX(d.calendar_date) AS last_purchase_date
    FROM completed_sales AS f
    JOIN analytics.dim_customer AS c ON c.customer_key = f.customer_key
    JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
    GROUP BY c.source_customer_id, c.customer_name, c.customer_segment, c.region
)
SELECT
    *,
    ROUND(lifetime_revenue / NULLIF(orders, 0), 2) AS average_order_value,
    DENSE_RANK() OVER (ORDER BY lifetime_revenue DESC) AS customer_revenue_rank
FROM customer_metrics
ORDER BY lifetime_revenue DESC;

-- Monthly customer retention. A retained customer was active in both the prior
-- month and the current month; the denominator is the prior month's customers.
WITH monthly_customers AS (
    SELECT DISTINCT
        d.year_month,
        DATE_TRUNC('month', d.calendar_date)::DATE AS month_start,
        f.customer_key
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
), month_pairs AS (
    SELECT
        current_month.month_start,
        COUNT(DISTINCT previous_month.customer_key) AS prior_month_customers,
        COUNT(DISTINCT current_month.customer_key) AS current_month_customers,
        COUNT(DISTINCT CASE
            WHEN previous_month.customer_key IS NOT NULL THEN current_month.customer_key
        END) AS retained_customers
    FROM monthly_customers AS current_month
    LEFT JOIN monthly_customers AS previous_month
        ON previous_month.customer_key = current_month.customer_key
       AND previous_month.month_start = current_month.month_start - INTERVAL '1 month'
    GROUP BY current_month.month_start
), prior_counts AS (
    SELECT month_start, COUNT(DISTINCT customer_key) AS prior_month_customers
    FROM monthly_customers
    GROUP BY month_start
)
SELECT
    mp.month_start,
    pc.prior_month_customers,
    mp.current_month_customers,
    mp.retained_customers,
    ROUND(100.0 * mp.retained_customers / NULLIF(pc.prior_month_customers, 0), 2) AS retention_rate_pct
FROM month_pairs AS mp
LEFT JOIN prior_counts AS pc
    ON pc.month_start = mp.month_start - INTERVAL '1 month'
ORDER BY mp.month_start;

-- RFM segmentation for customer targeting.
WITH customer_rfm AS (
    SELECT
        f.customer_key,
        MAX(d.calendar_date) AS last_order_date,
        COUNT(DISTINCT f.order_number) AS frequency,
        SUM(f.revenue_amount) AS monetary
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
    GROUP BY f.customer_key
), scored_rfm AS (
    SELECT
        *,
        (SELECT MAX(calendar_date) FROM analytics.dim_date) - last_order_date AS recency_days,
        6 - NTILE(5) OVER (ORDER BY last_order_date) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_rfm
)
SELECT
    c.source_customer_id,
    c.customer_name,
    c.customer_segment,
    c.region,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    recency_score,
    frequency_score,
    monetary_score,
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
        ELSE 'Needs Attention'
    END AS rfm_segment
FROM scored_rfm AS r
JOIN analytics.dim_customer AS c ON c.customer_key = r.customer_key
ORDER BY monetary DESC;
