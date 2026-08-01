-- Retail Sales Analytics: Power BI star-schema reporting mart
-- Fact grain: one row per order line item.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.dim_date (
    date_key INTEGER PRIMARY KEY,
    calendar_date DATE NOT NULL,
    day_number SMALLINT NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    week_number SMALLINT NOT NULL,
    month_number SMALLINT NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    quarter_number SMALLINT NOT NULL,
    year_number SMALLINT NOT NULL,
    year_month VARCHAR(7) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    CONSTRAINT uq_dim_date_calendar_date UNIQUE (calendar_date),
    CONSTRAINT ck_dim_date_key_positive CHECK (date_key > 0),
    CONSTRAINT ck_dim_date_day_number CHECK (day_number BETWEEN 1 AND 31),
    CONSTRAINT ck_dim_date_week_number CHECK (week_number BETWEEN 1 AND 53),
    CONSTRAINT ck_dim_date_month_number CHECK (month_number BETWEEN 1 AND 12),
    CONSTRAINT ck_dim_date_quarter_number CHECK (quarter_number BETWEEN 1 AND 4)
);

CREATE TABLE IF NOT EXISTS analytics.dim_customer (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_customer_id VARCHAR(50) NOT NULL,
    customer_name VARCHAR(200) NOT NULL,
    email VARCHAR(320),
    customer_segment VARCHAR(50) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    region VARCHAR(50) NOT NULL,
    signup_date DATE,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_dim_customer_effective_dates
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS analytics.dim_product (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_product_id VARCHAR(50),
    product_name VARCHAR(200) NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    current_list_price NUMERIC(12, 2) NOT NULL,
    current_unit_cost NUMERIC(12, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_dim_product_list_price_positive CHECK (current_list_price > 0),
    CONSTRAINT ck_dim_product_unit_cost_nonnegative CHECK (current_unit_cost >= 0),
    CONSTRAINT ck_dim_product_effective_dates
        CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS analytics.dim_sales_channel (
    sales_channel_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_dim_sales_channel_name UNIQUE (channel_name)
);

CREATE TABLE IF NOT EXISTS analytics.dim_payment_method (
    payment_method_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_method_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_dim_payment_method_name UNIQUE (payment_method_name)
);

CREATE TABLE IF NOT EXISTS analytics.dim_order_status (
    order_status_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL,
    is_completed BOOLEAN NOT NULL,
    CONSTRAINT uq_dim_order_status_name UNIQUE (status_name)
);

CREATE TABLE IF NOT EXISTS analytics.fact_sales (
    sales_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_order_item_key BIGINT NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    line_number SMALLINT NOT NULL,
    order_date_key INTEGER NOT NULL,
    customer_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    sales_channel_key SMALLINT NOT NULL,
    payment_method_key SMALLINT NOT NULL,
    order_status_key SMALLINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    unit_cost NUMERIC(12, 2) NOT NULL,
    discount_pct NUMERIC(5, 4) NOT NULL,
    gross_amount NUMERIC(14, 2) NOT NULL,
    revenue_amount NUMERIC(14, 2) NOT NULL,
    profit_amount NUMERIC(14, 2) NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fact_sales_source_line UNIQUE (source_order_item_key),
    CONSTRAINT uq_fact_sales_order_line UNIQUE (order_number, line_number),
    CONSTRAINT ck_fact_sales_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_fact_sales_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT ck_fact_sales_unit_cost_nonnegative CHECK (unit_cost >= 0),
    CONSTRAINT ck_fact_sales_discount_range CHECK (discount_pct BETWEEN 0 AND 1),
    CONSTRAINT fk_fact_sales_date
        FOREIGN KEY (order_date_key) REFERENCES analytics.dim_date (date_key),
    CONSTRAINT fk_fact_sales_customer
        FOREIGN KEY (customer_key) REFERENCES analytics.dim_customer (customer_key),
    CONSTRAINT fk_fact_sales_product
        FOREIGN KEY (product_key) REFERENCES analytics.dim_product (product_key),
    CONSTRAINT fk_fact_sales_channel
        FOREIGN KEY (sales_channel_key) REFERENCES analytics.dim_sales_channel (sales_channel_key),
    CONSTRAINT fk_fact_sales_payment_method
        FOREIGN KEY (payment_method_key) REFERENCES analytics.dim_payment_method (payment_method_key),
    CONSTRAINT fk_fact_sales_order_status
        FOREIGN KEY (order_status_key) REFERENCES analytics.dim_order_status (order_status_key)
);

-- Common Power BI extract and reporting access paths.
CREATE INDEX IF NOT EXISTS ix_fact_sales_order_date_key ON analytics.fact_sales (order_date_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_customer_key ON analytics.fact_sales (customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product_key ON analytics.fact_sales (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_channel_key ON analytics.fact_sales (sales_channel_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_status_key ON analytics.fact_sales (order_status_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_date_product ON analytics.fact_sales (order_date_key, product_key);
CREATE INDEX IF NOT EXISTS ix_dim_customer_current_source ON analytics.dim_customer (source_customer_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS ix_dim_product_current_business_key
    ON analytics.dim_product (product_name, category_name) WHERE is_current;

-- Convenience view for ad hoc analysis. Power BI should normally import the
-- fact table and dimensions directly to preserve a semantic star model.
CREATE OR REPLACE VIEW analytics.vw_sales_detail AS
SELECT
    f.sales_key,
    f.order_number,
    f.line_number,
    d.calendar_date AS order_date,
    d.year_number,
    d.quarter_number,
    d.month_number,
    d.month_name,
    d.year_month,
    c.source_customer_id,
    c.customer_name,
    c.customer_segment,
    c.city,
    c.state,
    c.region,
    p.product_name,
    p.category_name,
    sc.channel_name,
    pm.payment_method_name,
    os.status_name,
    os.is_completed,
    f.quantity,
    f.unit_price,
    f.unit_cost,
    f.discount_pct,
    f.gross_amount,
    f.revenue_amount,
    f.profit_amount
FROM analytics.fact_sales AS f
JOIN analytics.dim_date AS d ON d.date_key = f.order_date_key
JOIN analytics.dim_customer AS c ON c.customer_key = f.customer_key
JOIN analytics.dim_product AS p ON p.product_key = f.product_key
JOIN analytics.dim_sales_channel AS sc ON sc.sales_channel_key = f.sales_channel_key
JOIN analytics.dim_payment_method AS pm ON pm.payment_method_key = f.payment_method_key
JOIN analytics.dim_order_status AS os ON os.order_status_key = f.order_status_key;
