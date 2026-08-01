"""Generate a realistic synthetic retail-sales dataset for the portfolio project."""

from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker


RECORD_COUNT = 10_000
RANDOM_SEED = 42

PRODUCT_CATALOG = [
    ("PROD-001", "Electronics", "Laptop", 899.99, 0.18),
    ("PROD-002", "Electronics", "Smartphone", 699.99, 0.15),
    ("PROD-003", "Electronics", "Wireless Headphones", 129.99, 0.08),
    ("PROD-004", "Home & Kitchen", "Coffee Maker", 89.99, 0.08),
    ("PROD-005", "Home & Kitchen", "Air Fryer", 119.99, 0.07),
    ("PROD-006", "Home & Kitchen", "Desk Lamp", 39.99, 0.06),
    ("PROD-007", "Clothing", "Men's T-Shirt", 24.99, 0.09),
    ("PROD-008", "Clothing", "Women's Jeans", 59.99, 0.08),
    ("PROD-009", "Clothing", "Running Shoes", 84.99, 0.07),
    ("PROD-010", "Beauty", "Skin Care Set", 49.99, 0.05),
    ("PROD-011", "Beauty", "Electric Toothbrush", 69.99, 0.04),
    ("PROD-012", "Sports & Outdoors", "Yoga Mat", 29.99, 0.03),
    ("PROD-013", "Sports & Outdoors", "Water Bottle", 19.99, 0.02),
]

REGIONS = {
    "West": ["California", "Oregon", "Washington", "Nevada"],
    "Northeast": ["New York", "Massachusetts", "New Jersey", "Pennsylvania"],
    "South": ["Texas", "Florida", "Georgia", "North Carolina"],
    "Midwest": ["Illinois", "Ohio", "Michigan", "Minnesota"],
}


def generate_sales_records(record_count: int = RECORD_COUNT) -> pd.DataFrame:
    """Return a reproducible DataFrame containing synthetic retail transactions."""
    fake = Faker("en_US")
    Faker.seed(RANDOM_SEED)
    rng = np.random.default_rng(RANDOM_SEED)

    product_indexes = rng.choice(
        len(PRODUCT_CATALOG),
        size=record_count,
        p=[product[4] for product in PRODUCT_CATALOG],
    )
    start_date = pd.Timestamp("2023-01-01")
    order_dates = start_date + pd.to_timedelta(
        rng.integers(0, 730, size=record_count), unit="D"
    )

    customer_profiles = {}
    records = []
    for index, product_index in enumerate(product_indexes, start=1):
        product_id, category, product_name, list_price, _ = PRODUCT_CATALOG[product_index]
        customer_id = f"CUST-{rng.integers(1, 2501):05d}"
        if customer_id not in customer_profiles:
            region = rng.choice(list(REGIONS))
            state = rng.choice(REGIONS[region])
            customer_profiles[customer_id] = {
                "customer_name": fake.name(),
                "email": fake.unique.email(),
                "customer_segment": rng.choice(["Consumer", "Corporate", "Home Office"], p=[0.62, 0.25, 0.13]),
                "region": region,
                "state": state,
                "city": fake.city(),
                "signup_date": (start_date - pd.to_timedelta(rng.integers(30, 1096), unit="D")).date(),
            }
        customer = customer_profiles[customer_id]
        quantity = int(rng.choice([1, 2, 3, 4, 5], p=[0.58, 0.24, 0.10, 0.05, 0.03]))
        unit_price = round(list_price * rng.uniform(0.90, 1.05), 2)
        discount_pct = float(rng.choice([0, 0.05, 0.10, 0.15, 0.20], p=[0.45, 0.22, 0.18, 0.10, 0.05]))
        sales_amount = round(quantity * unit_price * (1 - discount_pct), 2)
        cost_amount = round(quantity * unit_price * rng.uniform(0.48, 0.72), 2)

        records.append(
            {
                "order_id": f"ORD-{index:06d}",
                "order_date": order_dates[index - 1].date(),
                "customer_id": customer_id,
                **customer,
                "product_id": product_id,
                "category": category,
                "product_name": product_name,
                "quantity": quantity,
                "unit_price": unit_price,
                "discount_pct": discount_pct,
                "sales_amount": sales_amount,
                "cost_amount": cost_amount,
                "profit_amount": round(sales_amount - cost_amount, 2),
                "payment_method": rng.choice(["Credit Card", "Debit Card", "PayPal", "Gift Card"], p=[0.50, 0.25, 0.18, 0.07]),
                "sales_channel": rng.choice(["Online", "Store"], p=[0.68, 0.32]),
                "order_status": "Completed",
            }
        )

    return pd.DataFrame(records)


def main() -> None:
    """Write 10,000 retail transactions to the raw-data directory."""
    output_path = Path(__file__).resolve().parents[1] / "data" / "raw" / "retail_sales_raw.csv"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    sales = generate_sales_records()
    sales.to_csv(output_path, index=False)
    print(f"Created {len(sales):,} retail sales records: {output_path}")


if __name__ == "__main__":
    main()
