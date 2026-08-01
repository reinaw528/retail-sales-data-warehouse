# Retail Sales Data Warehouse
End-to-End ETL Pipeline & Power BI Analytics
An end-to-end retail analytics project demonstrating the complete data pipeline from raw CSV files to a PostgreSQL data warehouse and Business Intelligence reporting.

## Overview
This project demonstrates an end-to-end retail analytics solution, covering the complete data lifecycle from raw CSV files to an interactive Power BI dashboard.

The project includes:

Data Cleaning with Python
PostgreSQL Data Warehouse
3NF Operational Data Model
Star Schema Data Mart
ETL Pipeline
Business KPI Development
Power BI Dashboard


## Architecture

```
Raw CSV
    │
    ▼
Python Data Cleaning
    │
    ▼
Staging Layer
    │
    ▼
3NF Relational Database
    │
    ▼
Star Schema
    │
    ▼
Power BI Dashboard
```

---

## Tech Stack

- PostgreSQL
- SQL
- Python
- Pandas
- Power BI
- Git & GitHub

---

## Data Pipeline

1. Generate and clean retail sales data
2. Load cleaned data into the staging layer
3. Populate normalized (3NF) operational tables
4. Build dimensional tables and fact tables
5. Validate ETL results
6. Prepare data for business intelligence reporting

---

## Data Model

The project follows a multi-layer warehouse architecture.

**Staging Layer**

- Raw cleaned retail data

**Operational Database (3NF)**

- Customers
- Products
- Orders
- Categories
- Sales Channels
- Payment Methods
- Geography

**Analytics Layer (Star Schema)**

- Fact Sales
- Dim Customer
- Dim Product
- Dim Date
- Dim Sales Channel
- Dim Payment Method
- Dim Order Status

---

## Project Structure

```
data/
python/
sql/
docs/
powerbi/
screenshots/
README.md
```

---

## SQL Features

This project demonstrates practical SQL skills, including:

- JOINs
- Common Table Expressions (CTEs)
- Aggregate Functions
- Data Cleaning
- Data Type Conversion
- UPSERT (`ON CONFLICT`)
- ETL Pipeline Development
- Star Schema Modeling

---

## Business KPIs

Example metrics include:

- Total Sales
- Total Profit
- Profit Margin
- Average Order Value
- Sales Trend
- Customer Segmentation
- Product Performance
- Regional Sales Analysis

---

## Future Improvements

- Interactive Power BI Dashboard
- Incremental ETL Pipeline
- Data Quality Validation
- Automated ETL Scheduling
- Cloud Deployment

---

## Author

Built as a portfolio project to demonstrate end-to-end data analytics, SQL, ETL, and data warehousing skills.
