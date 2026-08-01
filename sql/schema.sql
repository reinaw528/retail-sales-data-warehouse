-- Retail Sales Analytics: normalized PostgreSQL transactional schema
-- Target: PostgreSQL 14+ (uses generated columns and identity keys)

CREATE SCHEMA IF NOT EXISTS retail;

CREATE TABLE IF NOT EXISTS retail.customer_segments (
    segment_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    segment_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_customer_segments_name UNIQUE (segment_name)
);

CREATE TABLE IF NOT EXISTS retail.geographies (
    geography_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    region VARCHAR(50) NOT NULL,
    CONSTRAINT uq_geographies_location UNIQUE (city, state, region)
);

CREATE TABLE IF NOT EXISTS retail.customers (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_customer_id VARCHAR(50) NOT NULL,
    customer_name VARCHAR(200) NOT NULL,
    email VARCHAR(320),
    segment_key SMALLINT NOT NULL,
    geography_key INTEGER NOT NULL,
    signup_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customers_source_id UNIQUE (source_customer_id),
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT fk_customers_segment
        FOREIGN KEY (segment_key) REFERENCES retail.customer_segments (segment_key)
        ON DELETE RESTRICT,
    CONSTRAINT fk_customers_geography
        FOREIGN KEY (geography_key) REFERENCES retail.geographies (geography_key)
        ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS retail.product_categories (
    category_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_product_categories_name UNIQUE (category_name)
);

CREATE TABLE IF NOT EXISTS retail.products (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_product_id VARCHAR(50),
    product_name VARCHAR(200) NOT NULL,
    category_key SMALLINT NOT NULL,
    current_list_price NUMERIC(12, 2) NOT NULL,
    current_unit_cost NUMERIC(12, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_products_source_id UNIQUE (source_product_id),
    CONSTRAINT uq_products_name_category UNIQUE (product_name, category_key),
    CONSTRAINT ck_products_list_price_positive CHECK (current_list_price > 0),
    CONSTRAINT ck_products_unit_cost_nonnegative CHECK (current_unit_cost >= 0),
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_key) REFERENCES retail.product_categories (category_key)
        ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS retail.sales_channels (
    channel_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_sales_channels_name UNIQUE (channel_name)
);

CREATE TABLE IF NOT EXISTS retail.payment_methods (
    payment_method_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_method_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_payment_methods_name UNIQUE (payment_method_name)
);

CREATE TABLE IF NOT EXISTS retail.order_statuses (
    status_key SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL,
    CONSTRAINT uq_order_statuses_name UNIQUE (status_name)
);

CREATE TABLE IF NOT EXISTS retail.orders (
    order_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_order_id VARCHAR(50) NOT NULL,
    customer_key BIGINT NOT NULL,
    order_timestamp TIMESTAMPTZ NOT NULL,
    channel_key SMALLINT NOT NULL,
    payment_method_key SMALLINT NOT NULL,
    status_key SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_orders_source_id UNIQUE (source_order_id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_key) REFERENCES retail.customers (customer_key)
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_channel
        FOREIGN KEY (channel_key) REFERENCES retail.sales_channels (channel_key)
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_payment_method
        FOREIGN KEY (payment_method_key) REFERENCES retail.payment_methods (payment_method_key)
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_status
        FOREIGN KEY (status_key) REFERENCES retail.order_statuses (status_key)
        ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS retail.order_items (
    order_item_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_key BIGINT NOT NULL,
    line_number SMALLINT NOT NULL,
    product_key BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    unit_cost NUMERIC(12, 2) NOT NULL,
    discount_pct NUMERIC(5, 4) NOT NULL DEFAULT 0,
    gross_amount NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    net_sales_amount NUMERIC(14, 2) GENERATED ALWAYS AS
        (ROUND(quantity * unit_price * (1 - discount_pct), 2)) STORED,
    profit_amount NUMERIC(14, 2) GENERATED ALWAYS AS
        (ROUND((quantity * unit_price * (1 - discount_pct)) - (quantity * unit_cost), 2)) STORED,
    CONSTRAINT uq_order_items_order_line UNIQUE (order_key, line_number),
    CONSTRAINT ck_order_items_line_number_positive CHECK (line_number > 0),
    CONSTRAINT ck_order_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_order_items_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT ck_order_items_unit_cost_nonnegative CHECK (unit_cost >= 0),
    CONSTRAINT ck_order_items_discount_range CHECK (discount_pct >= 0 AND discount_pct <= 1),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_key) REFERENCES retail.orders (order_key)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_key) REFERENCES retail.products (product_key)
        ON DELETE RESTRICT
);

-- PostgreSQL automatically indexes primary keys and unique constraints.
-- These indexes cover foreign-key validation and common analytical access paths.
CREATE INDEX IF NOT EXISTS ix_customers_segment_key ON retail.customers (segment_key);
CREATE INDEX IF NOT EXISTS ix_customers_geography_key ON retail.customers (geography_key);
CREATE INDEX IF NOT EXISTS ix_products_category_key ON retail.products (category_key);
CREATE INDEX IF NOT EXISTS ix_orders_customer_key ON retail.orders (customer_key);
CREATE INDEX IF NOT EXISTS ix_orders_order_timestamp ON retail.orders (order_timestamp);
CREATE INDEX IF NOT EXISTS ix_orders_channel_key ON retail.orders (channel_key);
CREATE INDEX IF NOT EXISTS ix_orders_payment_method_key ON retail.orders (payment_method_key);
CREATE INDEX IF NOT EXISTS ix_orders_status_key ON retail.orders (status_key);
CREATE INDEX IF NOT EXISTS ix_orders_customer_timestamp ON retail.orders (customer_key, order_timestamp DESC);
CREATE INDEX IF NOT EXISTS ix_order_items_order_key ON retail.order_items (order_key);
CREATE INDEX IF NOT EXISTS ix_order_items_product_key ON retail.order_items (product_key);
