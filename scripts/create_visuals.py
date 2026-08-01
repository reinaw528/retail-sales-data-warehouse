"""Create polished sales analytics charts from the saved analysis tables."""

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import pandas as pd


COLORS = {
    "navy": "#173F5F",
    "blue": "#20639B",
    "teal": "#3CAEA3",
    "gold": "#F6C85F",
    "coral": "#ED553B",
    "gray": "#5B6770",
    "light_gray": "#E9EEF2",
}


def apply_chart_style() -> None:
    """Apply a consistent, presentation-ready Matplotlib style."""
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 10,
            "axes.titleweight": "bold",
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.grid": True,
            "axes.axisbelow": True,
            "grid.color": COLORS["light_gray"],
            "grid.linewidth": 0.8,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
        }
    )


def save_monthly_performance(monthly_sales: pd.DataFrame, output_path: Path) -> None:
    """Plot monthly revenue with profit on a secondary axis."""
    data = monthly_sales.copy()
    data["month"] = pd.to_datetime(data["month"])
    fig, axis_revenue = plt.subplots(figsize=(12, 6.5))
    axis_profit = axis_revenue.twinx()

    axis_revenue.plot(data["month"], data["revenue"], color=COLORS["blue"], linewidth=3, label="Revenue")
    axis_revenue.fill_between(data["month"], data["revenue"], color=COLORS["blue"], alpha=0.10)
    axis_profit.plot(data["month"], data["profit"], color=COLORS["teal"], linewidth=2.5, label="Profit")

    axis_revenue.set_title("Monthly Revenue and Profit", loc="left", pad=16)
    axis_revenue.set_ylabel("Revenue")
    axis_profit.set_ylabel("Profit")
    axis_revenue.yaxis.set_major_formatter(ticker.StrMethodFormatter("${x:,.0f}"))
    axis_profit.yaxis.set_major_formatter(ticker.StrMethodFormatter("${x:,.0f}"))
    axis_revenue.tick_params(axis="x", rotation=35)
    handles = axis_revenue.get_lines() + axis_profit.get_lines()
    axis_revenue.legend(handles, [line.get_label() for line in handles], frameon=False, loc="upper left")
    fig.tight_layout()
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def save_top_products(top_products: pd.DataFrame, output_path: Path) -> None:
    """Create a ranked horizontal bar chart for the top products by revenue."""
    data = top_products.sort_values("revenue", ascending=True)
    fig, axis = plt.subplots(figsize=(12, 7))
    bars = axis.barh(data["product_name"], data["revenue"], color=COLORS["blue"])
    axis.set_title("Top 10 Products by Revenue", loc="left", pad=16)
    axis.set_xlabel("Revenue")
    axis.xaxis.set_major_formatter(ticker.StrMethodFormatter("${x:,.0f}"))

    for bar, revenue in zip(bars, data["revenue"]):
        axis.text(revenue, bar.get_y() + bar.get_height() / 2, f"  ${revenue:,.0f}", va="center", color=COLORS["gray"])
    fig.tight_layout()
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def save_retention(retention: pd.DataFrame, output_path: Path) -> None:
    """Plot monthly active customers and the corresponding retention rate."""
    data = retention.copy()
    data["month"] = pd.to_datetime(data["month"])
    fig, axis_customers = plt.subplots(figsize=(12, 6.5))
    axis_rate = axis_customers.twinx()

    axis_customers.bar(data["month"], data["active_customers"], width=20, color=COLORS["gold"], alpha=0.85, label="Active customers")
    axis_rate.plot(data["month"], data["retention_rate_pct"], color=COLORS["coral"], marker="o", linewidth=2.5, label="Retention rate")

    axis_customers.set_title("Customer Activity and Monthly Retention", loc="left", pad=16)
    axis_customers.set_ylabel("Active customers")
    axis_rate.set_ylabel("Retention rate")
    axis_rate.yaxis.set_major_formatter(ticker.PercentFormatter())
    axis_customers.tick_params(axis="x", rotation=35)
    handles = [axis_customers.patches[0], axis_rate.get_lines()[0]]
    axis_customers.legend(handles, ["Active customers", "Retention rate"], frameon=False, loc="upper left")
    fig.tight_layout()
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def save_kpi_overview(kpis: pd.DataFrame, output_path: Path) -> None:
    """Generate a clean KPI scorecard image for use in reports or dashboards."""
    metrics = kpis.iloc[0]
    cards = [
        ("Total Revenue", f"${metrics['total_revenue']:,.0f}"),
        ("Total Profit", f"${metrics['total_profit']:,.0f}"),
        ("Profit Margin", f"{metrics['profit_margin_pct']:.1f}%"),
        ("Average Order Value", f"${metrics['average_order_value']:,.2f}"),
    ]
    fig, axes = plt.subplots(1, len(cards), figsize=(14, 3.2))
    for axis, (label, value), color in zip(axes, cards, [COLORS["navy"], COLORS["blue"], COLORS["teal"], COLORS["coral"]]):
        axis.set_facecolor(color)
        axis.text(0.5, 0.62, value, ha="center", va="center", color="white", fontsize=19, fontweight="bold")
        axis.text(0.5, 0.34, label, ha="center", va="center", color="white", fontsize=10)
        axis.set_xticks([])
        axis.set_yticks([])
        for spine in axis.spines.values():
            spine.set_visible(False)
    fig.suptitle("Sales Performance Overview", x=0.05, ha="left", fontsize=15, fontweight="bold")
    fig.tight_layout()
    fig.savefig(output_path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    """Load analysis outputs and save chart images to the outputs directory."""
    project_root = Path(__file__).resolve().parents[1]
    analysis_dir = project_root / "reports" / "analysis_outputs"
    output_dir = project_root / "reports" / "outputs"
    output_dir.mkdir(parents=True, exist_ok=True)

    apply_chart_style()
    monthly_sales = pd.read_csv(analysis_dir / "monthly_sales.csv")
    top_products = pd.read_csv(analysis_dir / "top_products.csv")
    retention = pd.read_csv(analysis_dir / "customer_retention.csv")
    kpis = pd.read_csv(analysis_dir / "kpis.csv")

    save_monthly_performance(monthly_sales, output_dir / "monthly_revenue_profit.png")
    save_top_products(top_products, output_dir / "top_products_by_revenue.png")
    save_retention(retention, output_dir / "customer_retention.png")
    save_kpi_overview(kpis, output_dir / "kpi_overview.png")
    print(f"Created 4 charts in: {output_dir}")


if __name__ == "__main__":
    main()
