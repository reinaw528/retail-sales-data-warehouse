-- Executive KPIs. Filter to completed orders at query time rather than deleting
-- other statuses, so the same model supports operational reporting.
WITH completed_sales AS (
    SELECT f.*
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
)
SELECT
    ROUND(SUM(revenue_amount), 2) AS total_revenue,
    ROUND(SUM(profit_amount), 2) AS total_profit,
    ROUND(100.0 * SUM(profit_amount) / NULLIF(SUM(revenue_amount), 0), 2) AS profit_margin_pct,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    ROUND(SUM(revenue_amount) / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS average_order_value
FROM completed_sales;

-- Monthly revenue, profit, and month-over-month revenue growth.
WITH monthly_sales AS (
    SELECT
        d.year_month,
        MIN(d.calendar_date) AS month_start,
        SUM(f.revenue_amount) AS revenue,
        SUM(f.profit_amount) AS profit,
        COUNT(DISTINCT f.order_number) AS orders,
        COUNT(DISTINCT f.customer_key) AS customers
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
    GROUP BY d.year_month
)
SELECT
    year_month,
    month_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2) AS profit,
    orders,
    customers,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
        / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0), 2) AS revenue_mom_growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY month_start), 2) AS running_revenue
FROM monthly_sales
ORDER BY month_start;

-- Regional performance, suitable for the Executive Summary page.
SELECT
    c.region,
    ROUND(SUM(f.revenue_amount), 2) AS revenue,
    ROUND(SUM(f.profit_amount), 2) AS profit,
    ROUND(100.0 * SUM(f.profit_amount) / NULLIF(SUM(f.revenue_amount), 0), 2) AS profit_margin_pct,
    COUNT(DISTINCT f.order_number) AS orders,
    COUNT(DISTINCT f.customer_key) AS customers
FROM analytics.fact_sales AS f
JOIN analytics.dim_customer AS c ON c.customer_key = f.customer_key
JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
WHERE os.is_completed
GROUP BY c.region
ORDER BY revenue DESC;
