"""pipeline.py — run once before the dashboard.

Loads raw Kaggle CSV → SQLite → runs all SQL queries → writes outputs/ CSVs.

Usage:
    python pipeline.py                        # expects data/SaaS-Sales.csv
    python pipeline.py --data path/to/file.csv
"""

import argparse
import math
import os
import sqlite3

import pandas as pd

RAW_CSV = os.path.join("data", "SaaS-Sales.csv")
DB_PATH = ":memory:"  # no persistent DB needed; outputs are the CSVs
SQL_DIR = "sql"
OUT_DIR = "outputs"


def load_raw(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    # Normalise Order Date to ISO format SQLite can compare as strings.
    df["Order Date"] = pd.to_datetime(df["Order Date"], dayfirst=False).dt.strftime("%Y-%m-%d")
    return df


def compute_churn_window(df: pd.DataFrame) -> int:
    """Derive churn window from the data: ceil(median repurchase interval * 2).

    Repurchase interval = months between consecutive orders per customer.
    Only customers with >1 order contribute to the median.
    """
    df["Order Date"] = pd.to_datetime(df["Order Date"])
    intervals = []
    for _, grp in df.groupby("Customer ID"):
        dates = grp["Order Date"].sort_values().dt.to_period("M").unique()
        for a, b in zip(dates, dates[1:]):
            intervals.append(b - a)
    if not intervals:
        return 3  # sensible fallback
    median_months = pd.Series([i.n for i in intervals]).median()
    return math.ceil(median_months * 2)


def run_sql(conn: sqlite3.Connection, sql_file: str, params: dict | None = None) -> pd.DataFrame:
    with open(sql_file) as f:
        query = f.read()
    # sqlite3 uses ? positional params; we use named :param style in SQL files.
    return pd.read_sql_query(query, conn, params=params)


def main(raw_path: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    print(f"Loading {raw_path} ...")
    df = load_raw(raw_path)

    churn_months = compute_churn_window(df)
    print(f"Churn window: {churn_months} months  (ceil(median_repurchase_interval × 2))")

    # Write churn window so the dashboard can display it without recomputing.
    pd.DataFrame([{"churn_months": churn_months}]).to_csv(
        os.path.join(OUT_DIR, "churn_window.csv"), index=False
    )

    conn = sqlite3.connect(DB_PATH)
    df.to_sql("orders", conn, if_exists="replace", index=False)

    jobs = [
        ("01_cohort_retention.sql", "cohort_retention.csv", None),
        ("02_churn_rate.sql",       "churn_rate.csv",       {"churn_months": churn_months}),
        ("03_regional_benchmarks.sql", "regional_benchmarks.csv", None),
        ("04_revenue_trend.sql",    "revenue_trend.csv",    None),
    ]

    for sql_file, out_file, params in jobs:
        path = os.path.join(SQL_DIR, sql_file)
        print(f"Running {sql_file} ...")
        result = run_sql(conn, path, params)
        out_path = os.path.join(OUT_DIR, out_file)
        result.to_csv(out_path, index=False)
        print(f"  → {out_path}  ({len(result)} rows)")

    conn.close()
    print("\nDone. Run: streamlit run dashboard.py")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default=RAW_CSV)
    args = parser.parse_args()
    main(args.data)
