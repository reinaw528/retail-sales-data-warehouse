-- DataGrip-compatible PostgreSQL load process.
-- The cleaned Python dataset is imported directly into staging.retail_sales_cleaned.
-- This file contains PostgreSQL SQL only; it does not use psql meta-commands.
--
-- Run order in DataGrip:
-- 1. Execute the CREATE SCHEMA/TABLE statement below.
-- 2. In the Database tool window, right-click staging.retail_sales_cleaned and select
--    Import/Export | Import Data from File(s). Choose data/cleaned/retail_sales_cleaned.csv, select CSV,
--    enable "First row is header", map columns by name, and execute the import.
-- 3. Execute the row-count query below as a separate statement. It must return > 0.
-- 4. Only after that, execute the validation and ETL section beginning at DO $$.
--
-- For a full reload, run TRUNCATE TABLE staging.retail_sales_cleaned; before repeating
-- the DataGrip import. Do not run that command after importing the CSV.

SET TIME ZONE 'UTC';

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.retail_sales_cleaned (
    order_id VARCHAR(50) NOT NULL,
    order_date DATE NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    customer_name VARCHAR(200) NOT NULL,
    email VARCHAR(320) NOT NULL,
    customer_segment VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    state VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    signup_date DATE NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    category VARCHAR(100) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    discount_pct NUMERIC(5, 4) NOT NULL,
    sales_amount NUMERIC(14, 2) NOT NULL,
    cost_amount NUMERIC(14, 2) NOT NULL,
    profit_amount NUMERIC(14, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    sales_channel VARCHAR(50) NOT NULL,
    order_status VARCHAR(50) NOT NULL,
    CONSTRAINT ck_cleaned_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_cleaned_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT ck_cleaned_unit_cost_nonnegative CHECK (cost_amount >= 0),
    CONSTRAINT ck_cleaned_discount_range CHECK (discount_pct BETWEEN 0 AND 1)
);

-- Migration support for a cleaned staging table created by an earlier version.
ALTER TABLE staging.retail_sales_cleaned ADD COLUMN IF NOT EXISTS email VARCHAR(320);
ALTER TABLE staging.retail_sales_cleaned ADD COLUMN IF NOT EXISTS signup_date DATE;
ALTER TABLE staging.retail_sales_cleaned ADD COLUMN IF NOT EXISTS product_id VARCHAR(50);
ALTER TABLE staging.retail_sales_cleaned ADD COLUMN IF NOT EXISTS order_status VARCHAR(50);

-- Run this statement after the DataGrip import and confirm staging_row_count > 0.
SELECT COUNT(*) AS staging_row_count
FROM staging.retail_sales_cleaned;

-- ETL starts here. The guard prevents accidental execution against an empty staging table.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM staging.retail_sales_cleaned) THEN
        RAISE EXCEPTION
            'staging.retail_sales_cleaned is empty. Import retail_sales_cleaned.csv in DataGrip and verify the row count before running the ETL.';
    END IF;
END;
$$;

-- Reject incomplete imports before any normalized table is changed.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM staging.retail_sales_cleaned
        WHERE order_id IS NULL
           OR order_date IS NULL
           OR customer_id IS NULL
           OR customer_name IS NULL
           OR email IS NULL
           OR customer_segment IS NULL
           OR region IS NULL
           OR state IS NULL
           OR city IS NULL
           OR signup_date IS NULL
           OR product_id IS NULL
           OR category IS NULL
           OR product_name IS NULL
           OR quantity IS NULL
           OR unit_price IS NULL
           OR discount_pct IS NULL
           OR sales_amount IS NULL
           OR cost_amount IS NULL
           OR profit_amount IS NULL
           OR payment_method IS NULL
           OR sales_channel IS NULL
           OR order_status IS NULL
    ) THEN
        RAISE EXCEPTION
            'The staging import has required business fields missing. Recreate the cleaned CSV and re-import it before running the ETL.';
    END IF;
END;
$$;

BEGIN;

-- Load reusable lookup entities first so all foreign keys can be resolved.
INSERT INTO retail.customer_segments (segment_name)
SELECT DISTINCT customer_segment
FROM staging.retail_sales_cleaned
WHERE customer_segment IS NOT NULL
ON CONFLICT (segment_name) DO NOTHING;

INSERT INTO retail.geographies (city, state, region)
SELECT DISTINCT city, state, region
FROM staging.retail_sales_cleaned
WHERE city IS NOT NULL AND state IS NOT NULL AND region IS NOT NULL
ON CONFLICT (city, state, region) DO NOTHING;

INSERT INTO retail.product_categories (category_name)
SELECT DISTINCT category
FROM staging.retail_sales_cleaned
WHERE category IS NOT NULL
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO retail.sales_channels (channel_name)
SELECT DISTINCT sales_channel
FROM staging.retail_sales_cleaned
WHERE sales_channel IS NOT NULL
ON CONFLICT (channel_name) DO NOTHING;

INSERT INTO retail.payment_methods (payment_method_name)
SELECT DISTINCT payment_method
FROM staging.retail_sales_cleaned
WHERE payment_method IS NOT NULL
ON CONFLICT (payment_method_name) DO NOTHING;

INSERT INTO retail.order_statuses (status_name)
SELECT DISTINCT order_status
FROM staging.retail_sales_cleaned
WHERE order_status IS NOT NULL
ON CONFLICT (status_name) DO NOTHING;

-- The latest source row supplies the current customer attributes.
INSERT INTO retail.customers (
    source_customer_id, customer_name, email, segment_key, geography_key, signup_date
)
SELECT DISTINCT ON (s.customer_id)
    s.customer_id,
    COALESCE(NULLIF(s.customer_name, ''), 'Unknown'),
    s.email,
    cs.segment_key,
    g.geography_key,
    cast(s.signup_date as date)
FROM staging.retail_sales_cleaned AS s
JOIN retail.customer_segments AS cs ON cs.segment_name = s.customer_segment
JOIN retail.geographies AS g ON (g.city, g.state, g.region) = (s.city, s.state, s.region)
ORDER BY s.customer_id, s.order_date DESC
ON CONFLICT (source_customer_id) DO UPDATE
SET customer_name = EXCLUDED.customer_name,
    email = EXCLUDED.email,
    segment_key = EXCLUDED.segment_key,
    geography_key = EXCLUDED.geography_key,
    signup_date = EXCLUDED.signup_date,
    updated_at = CURRENT_TIMESTAMP;

-- Product ID is retained from the cleaned source; product name plus category is
-- also enforced as the normalized product business key.
INSERT INTO retail.products (
    source_product_id, product_name, category_key, current_list_price, current_unit_cost
)
SELECT DISTINCT ON (s.product_name, pc.category_key)
    s.product_id as assource_product_id,
    s.product_name,
    pc.category_key,
    cast(s.unit_price as numeric) as current_list_price,
    cast(s.cost_amount as numeric)/ NULLIF(cast(s.quantity as numeric), 0) as current_unit_cost
FROM staging.retail_sales_cleaned AS s
JOIN retail.product_categories AS pc ON pc.category_name = s.category
WHERE s.product_name IS NOT NULL
  AND cast(s.quantity as numeric) > 0
  AND cast(s.unit_price as numeric)> 0
  AND cast(s.cost_amount as numeric) >= 0
ORDER BY s.product_name, pc.category_key, s.order_date DESC
ON CONFLICT (product_name, category_key) DO UPDATE
SET current_list_price = EXCLUDED.current_list_price,
    current_unit_cost = EXCLUDED.current_unit_cost,
    source_product_id = EXCLUDED.source_product_id,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO retail.orders (
    source_order_id, customer_key, order_timestamp, channel_key, payment_method_key, status_key
)
SELECT DISTINCT ON (s.order_id)
    s.order_id,
    c.customer_key,
    s.order_date::TIMESTAMP AT TIME ZONE 'UTC',
    sc.channel_key,
    pm.payment_method_key,
    os.status_key
FROM staging.retail_sales_cleaned AS s
JOIN retail.customers AS c ON c.source_customer_id = s.customer_id
JOIN retail.sales_channels AS sc ON sc.channel_name = s.sales_channel
JOIN retail.payment_methods AS pm ON pm.payment_method_name = s.payment_method
JOIN retail.order_statuses AS os ON os.status_name = s.order_status
ORDER BY s.order_id, s.order_date DESC
ON CONFLICT (source_order_id) DO UPDATE
SET customer_key = EXCLUDED.customer_key,
    order_timestamp = EXCLUDED.order_timestamp,
    channel_key = EXCLUDED.channel_key,
    payment_method_key = EXCLUDED.payment_method_key,
    status_key = EXCLUDED.status_key,
    updated_at = CURRENT_TIMESTAMP;

WITH source_lines AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY s.product_name, s.category, s.customer_id
        )::SMALLINT AS line_number
    FROM staging.retail_sales_cleaned AS s
)
INSERT INTO retail.order_items (
    order_key, line_number, product_key, quantity, unit_price, unit_cost, discount_pct
)
SELECT
    o.order_key,
    s.line_number,
    p.product_key,
    cast(s.quantity as numeric),
    cast(s.unit_price as numeric),
    cast(s.cost_amount as numeric) / NULLIF(cast(s.quantity as numeric), 0),
    cast(s.discount_pct as numeric)
FROM source_lines AS s
JOIN retail.orders AS o ON o.source_order_id = s.order_id
JOIN retail.product_categories AS pc ON pc.category_name = s.category
JOIN retail.products AS p
    ON p.product_name = s.product_name
   AND p.category_key = pc.category_key
ON CONFLICT (order_key, line_number) DO UPDATE
SET product_key = EXCLUDED.product_key,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    unit_cost = EXCLUDED.unit_cost,
    discount_pct = EXCLUDED.discount_pct;

-- Full-refresh reporting mart. This keeps Power BI extracts internally consistent.
TRUNCATE TABLE analytics.fact_sales,
               analytics.dim_customer,
               analytics.dim_product,
               analytics.dim_sales_channel,
               analytics.dim_payment_method,
               analytics.dim_order_status,
               analytics.dim_date
RESTART IDENTITY;

INSERT INTO analytics.dim_date (
    date_key, calendar_date, day_number, day_name, week_number,
    month_number, month_name, quarter_number, year_number, year_month, is_weekend
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(DAY FROM d)::SMALLINT,
    TO_CHAR(d, 'FMDay'),
    EXTRACT(WEEK FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    TO_CHAR(d, 'FMMonth'),
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(YEAR FROM d)::SMALLINT,
    TO_CHAR(d, 'YYYY-MM'),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM GENERATE_SERIES(
    (SELECT MIN(order_timestamp)::DATE FROM retail.orders),
    (SELECT MAX(order_timestamp)::DATE FROM retail.orders),
    INTERVAL '1 day'
) AS d;

INSERT INTO analytics.dim_customer (
    source_customer_id, customer_name, email, customer_segment, city, state, region, signup_date
)
SELECT
    c.source_customer_id,
    c.customer_name,
    c.email,
    cs.segment_name,
    g.city,
    g.state,
    g.region,
    c.signup_date
FROM retail.customers AS c
JOIN retail.customer_segments AS cs ON cs.segment_key = c.segment_key
JOIN retail.geographies AS g ON g.geography_key = c.geography_key;

INSERT INTO analytics.dim_product (
    source_product_id, product_name, category_name, current_list_price, current_unit_cost, is_active
)
SELECT
    p.source_product_id,
    p.product_name,
    pc.category_name,
    p.current_list_price,
    p.current_unit_cost,
    p.is_active
FROM retail.products AS p
JOIN retail.product_categories AS pc ON pc.category_key = p.category_key;

INSERT INTO analytics.dim_sales_channel (channel_name)
SELECT channel_name FROM retail.sales_channels;

INSERT INTO analytics.dim_payment_method (payment_method_name)
SELECT payment_method_name FROM retail.payment_methods;

INSERT INTO analytics.dim_order_status (status_name, is_completed)
SELECT status_name, status_name = 'Completed'
FROM retail.order_statuses;

INSERT INTO analytics.fact_sales (
    source_order_item_key, order_number, line_number, order_date_key,
    customer_key, product_key, sales_channel_key, payment_method_key, order_status_key,
    quantity, unit_price, unit_cost, discount_pct, gross_amount, revenue_amount, profit_amount
)
SELECT
    oi.order_item_key,
    o.source_order_id,
    oi.line_number,
    TO_CHAR(o.order_timestamp::DATE, 'YYYYMMDD')::INTEGER,
    dc.customer_key,
    dp.product_key,
    dsc.sales_channel_key,
    dpm.payment_method_key,
    dos.order_status_key,
    oi.quantity,
    oi.unit_price,
    oi.unit_cost,
    oi.discount_pct,
    oi.gross_amount,
    oi.net_sales_amount,
    oi.profit_amount
FROM retail.order_items AS oi
JOIN retail.orders AS o ON o.order_key = oi.order_key
JOIN retail.customers AS c ON c.customer_key = o.customer_key
JOIN analytics.dim_customer AS dc ON dc.source_customer_id = c.source_customer_id AND dc.is_current
JOIN retail.products AS p ON p.product_key = oi.product_key
JOIN retail.product_categories AS pc ON pc.category_key = p.category_key
JOIN analytics.dim_product AS dp
    ON dp.product_name = p.product_name
   AND dp.category_name = pc.category_name
   AND dp.is_current
JOIN retail.sales_channels AS sc ON sc.channel_key = o.channel_key
JOIN analytics.dim_sales_channel AS dsc ON dsc.channel_name = sc.channel_name
JOIN retail.payment_methods AS pm ON pm.payment_method_key = o.payment_method_key
JOIN analytics.dim_payment_method AS dpm ON dpm.payment_method_name = pm.payment_method_name
JOIN retail.order_statuses AS os ON os.status_key = o.status_key
JOIN analytics.dim_order_status AS dos ON dos.status_name = os.status_name;

COMMIT;

ANALYZE analytics.fact_sales;
ANALYZE analytics.dim_customer;
ANALYZE analytics.dim_product;
