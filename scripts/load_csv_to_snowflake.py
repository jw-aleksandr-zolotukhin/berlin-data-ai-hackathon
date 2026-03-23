"""
Reusable CSV → Snowflake loader.

Usage:
    # Load a single file
    uv run python scripts/load_csv_to_snowflake.py data/transactions.csv

    # Load all CSVs in a directory
    uv run python scripts/load_csv_to_snowflake.py data/

    # Load into a specific database/schema
    uv run python scripts/load_csv_to_snowflake.py data/ --database MY_DB --schema RAW

    # Append instead of replace
    uv run python scripts/load_csv_to_snowflake.py data/new_rows.csv --mode append

    # Custom table name
    uv run python scripts/load_csv_to_snowflake.py data/messy_filename.csv --table-name clean_name

Setup:
    1. cp env.example .env
    2. Fill in your Snowflake credentials in .env
    3. uv add snowflake-connector-python pandas pyarrow python-dotenv
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root (supports repo-local .env files)
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas


def get_connection() -> snowflake.connector.SnowflakeConnection:
    """Connect to Snowflake using .env or environment variables.

    Reads from .env file in project root (auto-loaded), or from shell env vars.

    Required variables:
        SNOWFLAKE_ACCOUNT   - e.g. "xy12345.us-east-1"
        SNOWFLAKE_USER      - your username
        SNOWFLAKE_PASSWORD  - your password
        SNOWFLAKE_WAREHOUSE - e.g. "COMPUTE_WH"
        SNOWFLAKE_DATABASE  - default database (overridable via --database)
        SNOWFLAKE_SCHEMA    - default schema (overridable via --schema)
    """
    account = os.environ.get("SNOWFLAKE_ACCOUNT")
    if not account:
        print("Missing SNOWFLAKE_ACCOUNT. Copy env.example to .env and fill in your credentials:")
        print("  cp env.example .env")
        sys.exit(1)

    return snowflake.connector.connect(
        account=account,
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE"),
        database=os.environ.get("SNOWFLAKE_DATABASE"),
        schema=os.environ.get("SNOWFLAKE_SCHEMA"),
    )


def csv_to_table_name(csv_path: Path) -> str:
    """Derive table name from filename: transactions.csv → TRANSACTIONS."""
    return csv_path.stem.upper().replace("-", "_").replace(" ", "_")


def load_csv(
    conn: snowflake.connector.SnowflakeConnection,
    csv_path: Path,
    table_name: str,
    database: str | None,
    schema: str | None,
    mode: str,
) -> dict:
    """Load a single CSV into Snowflake. Returns load stats."""
    df = pd.read_csv(csv_path)

    if df.empty:
        return {"file": csv_path.name, "table": table_name, "rows": 0, "status": "skipped (empty)"}

    # Clean column names: spaces/special chars → underscores, uppercase
    df.columns = [
        col.strip().upper().replace(" ", "_").replace("-", "_").replace(".", "_")
        for col in df.columns
    ]

    # Set database/schema context if provided
    if database:
        conn.cursor().execute(f"USE DATABASE {database}")
    if schema:
        conn.cursor().execute(f"USE SCHEMA {schema}")

    overwrite = mode == "replace"

    success, num_chunks, num_rows, _ = write_pandas(
        conn,
        df,
        table_name,
        auto_create_table=True,
        overwrite=overwrite,
    )

    return {
        "file": csv_path.name,
        "table": table_name,
        "rows": num_rows,
        "chunks": num_chunks,
        "status": "loaded" if success else "failed",
    }


def find_csvs(path: Path) -> list[Path]:
    """Find all CSV files in a path (file or directory)."""
    if path.is_file() and path.suffix.lower() == ".csv":
        return [path]
    if path.is_dir():
        csvs = sorted(path.glob("*.csv"))
        if not csvs:
            print(f"No CSV files found in {path}")
            sys.exit(1)
        return csvs
    print(f"Not a CSV file or directory: {path}")
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Load CSVs into Snowflake tables")
    parser.add_argument("path", type=Path, help="CSV file or directory of CSVs")
    parser.add_argument("--database", "-d", help="Target database (overrides env/default)")
    parser.add_argument("--schema", "-s", help="Target schema (overrides env/default)")
    parser.add_argument("--table-name", "-t", help="Table name (single file only)")
    parser.add_argument(
        "--mode",
        choices=["replace", "append"],
        default="replace",
        help="Replace table or append rows (default: replace)",
    )
    args = parser.parse_args()

    csv_files = find_csvs(args.path)

    if args.table_name and len(csv_files) > 1:
        print("--table-name can only be used with a single file, not a directory")
        sys.exit(1)

    conn = get_connection()
    print(f"Connected to Snowflake: {conn.account}")

    results = []
    for csv_path in csv_files:
        table_name = args.table_name.upper() if args.table_name else csv_to_table_name(csv_path)
        print(f"  Loading {csv_path.name} → {table_name} ...", end=" ", flush=True)
        result = load_csv(conn, csv_path, table_name, args.database, args.schema, args.mode)
        print(f"{result['status']} ({result['rows']} rows)")
        results.append(result)

    conn.close()

    # Summary
    total_rows = sum(r["rows"] for r in results)
    loaded = sum(1 for r in results if r["status"] == "loaded")
    print(f"\nDone: {loaded}/{len(results)} files loaded, {total_rows:,} total rows")


if __name__ == "__main__":
    main()
