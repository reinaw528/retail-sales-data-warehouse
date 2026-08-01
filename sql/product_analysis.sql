-- Product and category performance with revenue ranking.
WITH product_performance AS (
    SELECT
        p.category_name,
        p.product_name,
        SUM(f.quantity) AS units_sold,
        SUM(f.revenue_amount) AS revenue,
        SUM(f.profit_amount) AS profit,
        AVG(f.discount_pct) AS average_discount_pct,
        COUNT(DISTINCT f.order_number) AS orders
    FROM analytics.fact_sales AS f
    JOIN analytics.dim_product AS p ON p.product_key = f.product_key
    JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
    WHERE os.is_completed
    GROUP BY p.category_name, p.product_name
)
SELECT
    category_name,
    product_name,
    units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2) AS profit,
    ROUND(100.0 * profit / NULLIF(revenue, 0), 2) AS profit_margin_pct,
    ROUND(100.0 * average_discount_pct, 2) AS average_discount_pct,
    orders,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS overall_revenue_rank,
    DENSE_RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS category_revenue_rank
FROM product_performance
ORDER BY revenue DESC;

-- Category-level summary for category cards and a treemap.
SELECT
    p.category_name,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.revenue_amount), 2) AS revenue,
    ROUND(SUM(f.profit_amount), 2) AS profit,
    ROUND(100.0 * SUM(f.profit_amount) / NULLIF(SUM(f.revenue_amount), 0), 2) AS profit_margin_pct
FROM analytics.fact_sales AS f
JOIN analytics.dim_product AS p ON p.product_key = f.product_key
JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
WHERE os.is_completed
GROUP BY p.category_name
ORDER BY revenue DESC;

-- Monthly product trends, retaining all product-month combinations that sold.
SELECT
    d.year_month,
    p.category_name,
    p.product_name,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.revenue_amount), 2) AS revenue,
    ROUND(SUM(f.profit_amount), 2) AS profit
FROM analytics.fact_sales AS f
JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
JOIN analytics.dim_product AS p ON p.product_key = f.product_key
JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key
WHERE os.is_completed
GROUP BY d.year_month, p.category_name, p.product_name
ORDER BY d.year_month, revenue DESC;
