"""Clean and validate raw retail-sales data for analysis."""

from pathlib import Path

import pandas as pd


REQUIRED_COLUMNS = {
    "order_id", "order_date", "customer_id", "customer_name", "email", "customer_segment",
    "region", "state", "city", "signup_date", "product_id", "category", "product_name", "quantity", "unit_price",
    "discount_pct", "sales_amount", "cost_amount", "profit_amount", "payment_method",
    "sales_channel", "order_status",
}


def clean_sales_data(data: pd.DataFrame) -> pd.DataFrame:
    """Remove duplicates/invalid records and impute appropriate missing values."""
    missing_columns = REQUIRED_COLUMNS.difference(data.columns)
    #print("Raw data columns:", data.shape)
    if missing_columns:
        raise ValueError(f"Missing required columns: {sorted(missing_columns)}")

    cleaned = data.copy().drop_duplicates()
    
    cleaned["order_date"] = pd.to_datetime(cleaned["order_date"], errors="coerce")
    cleaned["signup_date"] = pd.to_datetime(cleaned["signup_date"], errors="coerce")

    text_columns = [
        "customer_name", "customer_segment", "region", "state", "city", "category",
        "product_name", "payment_method", "sales_channel",
    ]
    for column in text_columns:
        cleaned[column] = cleaned[column].fillna("Unknown").astype(str).str.strip()

    required_text_columns = ["email", "product_id", "order_status"]
    for column in required_text_columns:
        cleaned[column] = cleaned[column].astype("string").str.strip().replace("", pd.NA)

    numeric_columns = [
        "quantity", "unit_price", "discount_pct", "sales_amount", "cost_amount", "profit_amount"
    ]
    for column in numeric_columns:
        cleaned[column] = pd.to_numeric(cleaned[column], errors="coerce")

    cleaned["discount_pct"] = cleaned["discount_pct"].fillna(0)
    cleaned["quantity"] = cleaned["quantity"].fillna(cleaned["quantity"].median())
    for column in ["unit_price", "sales_amount", "cost_amount", "profit_amount"]:
        cleaned[column] = cleaned[column].fillna(cleaned[column].median())

    cleaned = cleaned.dropna(
        subset=["order_id", "customer_id", "email", "signup_date", "product_id", "order_status", "order_date"]
    )
    
    cleaned = cleaned.drop_duplicates(subset="order_id", keep="first")
    cleaned = cleaned[
        (cleaned["quantity"] > 0)
        & (cleaned["unit_price"] > 0)
        & (cleaned["sales_amount"] >= 0)
        & (cleaned["cost_amount"] >= 0)
        & cleaned["discount_pct"].between(0, 1)
    ].copy()
    
    cleaned["quantity"] = cleaned["quantity"].round().astype(int)
    cleaned["sales_amount"] = (cleaned["quantity"] * cleaned["unit_price"] * (1 - cleaned["discount_pct"])).round(2)
    cleaned["profit_amount"] = (cleaned["sales_amount"] - cleaned["cost_amount"]).round(2)
    #print("Raw data after cleaning:", cleaned.shape)
    return cleaned.sort_values(["order_date", "order_id"]).reset_index(drop=True)


def main() -> None:
    """Read raw sales data, clean it, and write the analysis-ready CSV."""
    project_root = Path(__file__).resolve().parents[1]
    input_path = project_root / "data" / "raw" / "retail_sales_raw.csv"
    output_path = project_root / "data" / "cleaned" / "retail_sales_cleaned.csv"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    #print(output_path)

    raw_sales = pd.read_csv(input_path)
    cleaned_sales = clean_sales_data(raw_sales)
    cleaned_sales.to_csv(output_path, index=False)
    print(f"Cleaned {len(raw_sales):,} raw records into {len(cleaned_sales):,} valid records: {output_path}")


if __name__ == "__main__":
    main()
