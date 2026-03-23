# Snowflake Data Ingestion Guide

> Options for loading CSV data into Snowflake, ranked by simplicity.
> Focused on small-to-medium datasets (~40MB). For streaming or large-scale ingestion, see `snowflake-platform-features.md`.

---

## Quick Comparison

| Method | Schema Detection | Scriptable | Setup | Best For |
|---|---|---|---|---|
| **Snowsight UI** | Auto | No | None | One-time quick load |
| **SnowSQL PUT+COPY** | Manual or INFER_SCHEMA | Yes | SnowSQL CLI | Repeatable loads, CI scripts |
| **INFER_SCHEMA** | Auto | Yes | Stage | Unknown/changing schemas |
| **Python `write_pandas`** | Auto | Yes | Python env | Python-first workflows |
| **Snowpark** | Auto | Yes | Snowpark env | DataFrame transforms during load |

---

## 1. Snowsight Web UI Upload (Easiest)

No code required. Click-to-load in the Snowflake console.

1. Log into Snowsight → **Data** → **Add Data** → **Load Data into a Table**
2. Select your warehouse
3. Browse/drag your CSV files
4. Snowflake auto-detects schema
5. Done — table is live

**Limit:** 50MB per file.

---

## 2. SnowSQL CLI — PUT + COPY INTO (Scriptable)

```sql
-- 1. Create table
CREATE OR REPLACE TABLE my_db.raw.transactions (
    transaction_id VARCHAR,
    amount NUMBER(18,2),
    transaction_date DATE,
    status VARCHAR
);

-- 2. Upload CSV to internal stage
PUT file:///path/to/transactions.csv @my_db.raw.%transactions AUTO_COMPRESS=TRUE;

-- 3. Load into table
COPY INTO my_db.raw.transactions
  FROM @my_db.raw.%transactions
  FILE_FORMAT = (TYPE=CSV SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
  ON_ERROR = 'CONTINUE'
  PURGE = TRUE;
```

### Batch loading multiple files

```bash
for f in /path/to/data/*.csv; do
  table=$(basename "$f" .csv)
  snowsql -q "PUT file://$f @my_db.raw.%${table}"
  snowsql -q "COPY INTO my_db.raw.${table} FROM @my_db.raw.%${table} FILE_FORMAT=(TYPE=CSV SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='\"') PURGE=TRUE;"
done
```

---

## 3. Schema Auto-Detection with INFER_SCHEMA (No Manual CREATE TABLE)

Let Snowflake figure out the schema from your CSVs:

```sql
-- Stage the file first
CREATE OR REPLACE STAGE my_stage FILE_FORMAT = (TYPE=CSV PARSE_HEADER=TRUE);
PUT file:///path/to/transactions.csv @my_stage;

-- Auto-detect columns
SELECT * FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@my_stage/transactions.csv',
    FILE_FORMAT => 'my_stage'
  )
);

-- Create table from inferred schema
CREATE TABLE raw.transactions
  USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(INFER_SCHEMA(
      LOCATION => '@my_stage/transactions.csv',
      FILE_FORMAT => 'my_stage'
    ))
  );

-- Load with column name matching
COPY INTO raw.transactions
  FROM @my_stage/transactions.csv
  FILE_FORMAT = (TYPE=CSV SKIP_HEADER=1)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
```

---

## 4. Python Connector — `write_pandas` (If You're Already in Python)

```python
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import pandas as pd

conn = snowflake.connector.connect(
    account="your_account",
    user="your_user",
    password="your_password",
    database="my_db",
    schema="raw",
    warehouse="my_wh",
)

# Load each CSV
for csv_file in ["transactions.csv", "accounts.csv", "instruments.csv"]:
    df = pd.read_csv(f"/path/to/{csv_file}")
    table_name = csv_file.replace(".csv", "").upper()
    write_pandas(conn, df, table_name, auto_create_table=True)

conn.close()
```

`write_pandas` internally does PUT + COPY INTO — one function call handles everything.

---

## 5. Snowpark `save_as_table` (DataFrame API)

```python
from snowflake.snowpark import Session

session = Session.builder.configs({...}).create()

for csv in ["transactions", "accounts", "instruments"]:
    df = session.read.option("header", True).option("infer_schema", True).csv(f"file:///path/to/{csv}.csv")
    df.write.mode("overwrite").save_as_table(f"raw.{csv}")
```

---

## Best Practices for CSV Loading

1. **Split large files** — Snowflake loads files in parallel. Aim for 100–250 MB compressed per file, not one giant CSV.
2. **Compress first** — GZIP your CSVs before staging. Snowflake decompresses automatically and you save on storage/transfer.
3. **Use a dedicated warehouse** — Size it up (e.g., LARGE) for the load, then scale back down.
4. **Validate before committing** — Use `VALIDATION_MODE = 'RETURN_ERRORS'` on COPY INTO to dry-run first:
   ```sql
   COPY INTO my_table FROM @my_stage
     VALIDATION_MODE = 'RETURN_ERRORS';
   ```
5. **Use NUMERIC, not FLOAT** — For financial amounts (prices, balances), always use `NUMBER(38,8)` or similar fixed-precision types to avoid floating-point rounding.
6. **Partition by date** — If loading historical data, cluster your target table on date columns for downstream query performance.

---

## Recommended: Reusable Python Loader

This project includes a reusable CSV → Snowflake loader script at `scripts/load_csv_to_snowflake.py`.

### Setup
```bash
cp env.example .env    # fill in your Snowflake credentials
```

### Usage
```bash
# Load all CSVs in data/
uv run python scripts/load_csv_to_snowflake.py data/

# Load a single file
uv run python scripts/load_csv_to_snowflake.py data/transactions.csv

# Target a specific database/schema
uv run python scripts/load_csv_to_snowflake.py data/ --database MY_DB --schema RAW

# Append instead of replace
uv run python scripts/load_csv_to_snowflake.py data/new_rows.csv --mode append

# Custom table name
uv run python scripts/load_csv_to_snowflake.py data/messy_filename.csv --table-name TRANSACTIONS
```

Features:
- Auto-creates tables from CSV column headers
- Cleans column names (spaces/special chars → underscores, uppercase)
- Replace or append modes
- Loads single files or entire directories
- Credentials via `.env` file (gitignored) — see `env.example`

---

## Further Reading

- [snowflake-data-types-and-objects.md](snowflake-data-types-and-objects.md) — Stages, file formats, pipes
- [snowflake-platform-features.md](snowflake-platform-features.md) — Snowpipe, Snowpipe Streaming, external tables
- [snowflake-python-connector.md](snowflake-python-connector.md) — Full Python connector reference
- [snowflake-sql-commands.md](snowflake-sql-commands.md) — COPY INTO, PUT, CREATE STAGE syntax
