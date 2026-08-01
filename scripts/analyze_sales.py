"""Calculate portfolio-ready sales KPIs from cleaned retail transaction data."""

from pathlib import Path

import pandas as pd


def calculate_customer_retention(sales: pd.DataFrame) -> pd.DataFrame:
    """Calculate monthly retention based on customers active in consecutive months."""
    customer_months = (
        sales.assign(month=sales["order_date"].dt.to_period("M"))
        .groupby("month")["customer_id"]
        .agg(lambda customers: set(customers))
        .sort_index()
    )

    rows = []
    previous_customers: set[str] | None = None
    for month, current_customers in customer_months.items():
        active_customers = len(current_customers)
        retained_customers = (
            len(current_customers.intersection(previous_customers))
            if previous_customers is not None
            else 0
        )
        retention_rate = (
            round(retained_customers / len(previous_customers) * 100, 2)
            if previous_customers
            else None
        )
        rows.append(
            {
                "month": month.to_timestamp(),
                "active_customers": active_customers,
                "retained_customers": retained_customers,
                "retention_rate_pct": retention_rate,
            }
        )
        previous_customers = current_customers

    return pd.DataFrame(rows)


def analyze_sales(sales: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """Return KPI, monthly sales, top-product, and retention analysis tables."""
    required_columns = {
        "order_id", "order_date", "customer_id", "product_name", "quantity",
        "sales_amount", "cost_amount", "profit_amount",
    }
    missing_columns = required_columns.difference(sales.columns)
    if missing_columns:
        raise ValueError(f"Missing required columns: {sorted(missing_columns)}")

    data = sales.copy()
    data["order_date"] = pd.to_datetime(data["order_date"], errors="coerce")
    data = data.dropna(subset=["order_date"])
    data["month"] = data["order_date"].dt.to_period("M")

    total_revenue = data["sales_amount"].sum()
    total_profit = data["profit_amount"].sum()
    total_orders = data["order_id"].nunique()
    total_customers = data["customer_id"].nunique()
    kpis = pd.DataFrame(
        [
            {
                "total_revenue": round(total_revenue, 2),
                "total_profit": round(total_profit, 2),
                "profit_margin_pct": round(total_profit / total_revenue * 100, 2) if total_revenue else 0,
                "total_orders": total_orders,
                "total_customers": total_customers,
                "average_order_value": round(total_revenue / total_orders, 2) if total_orders else 0,
            }
        ]
    )

    monthly_sales = (
        data.groupby("month", as_index=False)
        .agg(
            revenue=("sales_amount", "sum"),
            profit=("profit_amount", "sum"),
            orders=("order_id", "nunique"),
            customers=("customer_id", "nunique"),
        )
        .sort_values("month")
    )
    monthly_sales["month"] = monthly_sales["month"].dt.to_timestamp()
    monthly_sales["revenue"] = monthly_sales["revenue"].round(2)
    monthly_sales["profit"] = monthly_sales["profit"].round(2)
    monthly_sales["revenue_growth_pct"] = (monthly_sales["revenue"].pct_change() * 100).round(2)

    top_products = (
        data.groupby(["category", "product_name"], as_index=False)
        .agg(
            revenue=("sales_amount", "sum"),
            profit=("profit_amount", "sum"),
            units_sold=("quantity", "sum"),
            orders=("order_id", "nunique"),
        )
        .sort_values(["revenue", "profit"], ascending=False)
        .head(10)
        .reset_index(drop=True)
    )
    top_products.insert(0, "revenue_rank", top_products.index + 1)
    top_products[["revenue", "profit"]] = top_products[["revenue", "profit"]].round(2)

    retention = calculate_customer_retention(data)
    return {
        "kpis": kpis,
        "monthly_sales": monthly_sales,
        "top_products": top_products,
        "customer_retention": retention,
    }


def main() -> None:
    """Run the analysis and save dashboard-ready CSV output tables."""
    project_root = Path(__file__).resolve().parents[1]
    input_path = project_root / "data" / "cleaned" / "retail_sales_cleaned.csv"
    output_dir = project_root / "reports" / "analysis_outputs"
    output_dir.mkdir(parents=True, exist_ok=True)

    results = analyze_sales(pd.read_csv(input_path))
    for analysis_name, result in results.items():
        result.to_csv(output_dir / f"{analysis_name}.csv", index=False)

    kpis = results["kpis"].iloc[0]
    print(
        f"Analysis complete: revenue=${kpis['total_revenue']:,.2f}, "
        f"profit=${kpis['total_profit']:,.2f}, orders={kpis['total_orders']:,}."
    )
    print(f"Saved analysis tables to: {output_dir}")


if __name__ == "__main__":
    main()
