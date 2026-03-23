# FRED (Federal Reserve Economic Data) — Ingestion Research

## 1. What Is FRED?

FRED is a database maintained by the **Federal Reserve Bank of St. Louis** containing over **800,000 economic time series** from hundreds of domestic and international sources. It covers:

- US macroeconomic indicators (GDP, CPI, unemployment, PCE, federal funds rate)
- Financial market data (Treasury yields, mortgage rates, exchange rates)
- Regional economic data (state/MSA-level employment, housing)
- International data (from IMF, World Bank, ECB, etc.)
- Banking and financial sector data (M2, balance sheet items)

**Key facts:**
- Free to use with an API key
- Data is updated on the same schedule as original source releases
- Maintained since 1991; API available since ~2010
- Vintage/revision history available via the ALFRED database (Archival FRED)

---

## 2. API Access

### Getting an API Key

1. Register at https://fred.stlouisfed.org/docs/api/api_key.html
2. API key is a 32-character alphanumeric string
3. Free with no cost — tied to a St. Louis Fed account

### Base URL

```
https://api.stlouisfed.org/fred/
```

### Core Endpoints

| Endpoint | Description |
|---|---|
| `fred/series` | Metadata about a series |
| `fred/series/observations` | The actual data points |
| `fred/series/search` | Full-text search for series |
| `fred/series/categories` | Categories a series belongs to |
| `fred/series/release` | Release info for a series |
| `fred/series/updates` | Recently updated series |
| `fred/series/vintagedates` | Revision history dates |
| `fred/releases` | List all releases |
| `fred/release/dates` | Release calendar |
| `fred/category` | Category metadata |
| `fred/category/children` | Child categories |
| `fred/category/series` | Series within a category |
| `fred/tags/series` | Series by tag |

### Example Raw API Call

```
GET https://api.stlouisfed.org/fred/series/observations
  ?series_id=GDPC1
  &api_key=YOUR_API_KEY
  &file_type=json
  &observation_start=2000-01-01
  &observation_end=2024-01-01
  &frequency=q
  &units=pc1
```

**Common query parameters for observations:**

| Parameter | Values | Description |
|---|---|---|
| `series_id` | e.g. `GDPC1`, `UNRATE` | Required. The series identifier. |
| `observation_start` | `YYYY-MM-DD` | Start date filter |
| `observation_end` | `YYYY-MM-DD` | End date filter |
| `units` | `lin`, `chg`, `ch1`, `pch`, `pc1`, `pca`, `cch`, `cca`, `log` | Transformation applied |
| `frequency` | `d`, `w`, `bw`, `m`, `q`, `sa`, `a` | Aggregation frequency |
| `aggregation_method` | `avg`, `sum`, `eop` | How to aggregate |
| `output_type` | `1`, `2`, `3`, `4` | Real-time/vintage options |
| `vintage_dates` | comma-separated dates | For ALFRED vintage data |
| `limit` | 1–100000 (default 100000) | Max observations returned |
| `offset` | integer | Pagination offset |
| `sort_order` | `asc`, `desc` | Sort order |
| `file_type` | `json`, `xml`, `txt`, `xls` | Response format |

### Rate Limits

- **120 requests per 60 seconds** (2 requests/second sustained)
- No documented daily cap, but aggressive scraping will get you throttled or blocked
- Recommended: add a `time.sleep(0.5)` between calls in batch jobs
- For large-scale ingestion, FRED bulk download files are preferred (see Section 6)

---

## 3. Python Clients and SDKs

### Option A: `fredapi` (most popular)

```bash
pip install fredapi
```

```python
from fredapi import Fred

fred = Fred(api_key='your_api_key_here')

# Or set via environment variable FRED_API_KEY
# fred = Fred()

# Fetch a series as a pandas Series
gdp = fred.get_series('GDPC1')

# With date range
unrate = fred.get_series('UNRATE',
                         observation_start='2010-01-01',
                         observation_end='2024-01-01')

# Get series metadata
info = fred.get_series_info('GDPC1')
print(info['title'], info['units'], info['frequency'])

# Search for series
results = fred.search('unemployment rate')

# Get series with all info
gdp_full = fred.get_series_all_releases('GDPC1')  # vintage data

# Get category series
category_series = fred.get_series_in_category(32991)  # category ID

# Get series by release
release_series = fred.get_series_in_release(53)  # release ID
```

`fredapi` returns `pandas.Series` objects with a `DatetimeIndex`, making it immediately compatible with pandas workflows.

### Option B: `pandas-datareader`

```bash
pip install pandas-datareader
```

```python
import pandas_datareader as pdr
import datetime

start = datetime.datetime(2010, 1, 1)
end = datetime.datetime(2024, 1, 1)

# Fetch one or more series
df = pdr.get_data_fred(['GDPC1', 'UNRATE', 'CPIAUCSL'], start, end)

# Single series
gdp = pdr.get_data_fred('GDPC1', start, end)
```

`pandas-datareader` returns a `pandas.DataFrame`. It is a thin wrapper over the FRED API and has fewer features than `fredapi` (no search, no metadata). It can be less maintained — check its current status before relying on it for production.

### Option C: Direct HTTP with `requests`

```python
import requests
import pandas as pd

API_KEY = 'your_api_key'
BASE_URL = 'https://api.stlouisfed.org/fred'

def get_series(series_id: str,
               start: str | None = None,
               end: str | None = None) -> pd.DataFrame:
    params = {
        'series_id': series_id,
        'api_key': API_KEY,
        'file_type': 'json',
    }
    if start:
        params['observation_start'] = start
    if end:
        params['observation_end'] = end

    resp = requests.get(f'{BASE_URL}/series/observations', params=params)
    resp.raise_for_status()
    data = resp.json()

    df = pd.DataFrame(data['observations'])
    df['date'] = pd.to_datetime(df['date'])
    df['value'] = pd.to_numeric(df['value'], errors='coerce')  # '.' → NaN
    df = df.set_index('date')[['value']]
    df.columns = [series_id]
    return df
```

### Option D: `full_fred`

```bash
pip install full-fred
```

A more complete wrapper that exposes every FRED API endpoint including ALFRED (vintage data), tags, and sources. Less widely adopted than `fredapi`.

```python
from full_fred.fred import Fred

fred = Fred()
fred.set_api_key_file('.env')  # reads FRED_API_KEY

obs = fred.get_series_observations('GDPC1')
```

### Comparison Table

| Library | Pandas Integration | Full API Coverage | Vintage/ALFRED | Maintenance | Recommendation |
|---|---|---|---|---|---|
| `fredapi` | Yes (Series/DataFrame) | Good | Yes | Active | Primary choice |
| `pandas-datareader` | Yes (DataFrame) | Minimal | No | Intermittent | Legacy/simple use |
| `requests` (raw) | Manual | Full | Full | N/A | Custom pipelines |
| `full_fred` | Partial | Full | Yes | Less active | When full coverage needed |

---

## 4. Data Ingestion Patterns

### Pattern A: One-Time Bulk Load

Load all historical data for a list of series IDs on first run.

```python
import time
from fredapi import Fred
import pandas as pd

fred = Fred(api_key='your_api_key')

SERIES_IDS = ['GDPC1', 'UNRATE', 'CPIAUCSL', 'FEDFUNDS', 'T10Y2Y']

def bulk_load(series_ids: list[str]) -> pd.DataFrame:
    frames = {}
    for sid in series_ids:
        try:
            frames[sid] = fred.get_series(sid)
            time.sleep(0.5)  # respect rate limit
        except Exception as e:
            print(f"Failed {sid}: {e}")
    return pd.DataFrame(frames)

df = bulk_load(SERIES_IDS)
```

### Pattern B: Incremental / Delta Load

Only fetch new observations since the last known date. Suitable for scheduled jobs (daily/weekly).

```python
import sqlite3
from fredapi import Fred
import pandas as pd

fred = Fred(api_key='your_api_key')

def get_last_date(conn: sqlite3.Connection, series_id: str) -> str | None:
    cursor = conn.execute(
        "SELECT MAX(date) FROM observations WHERE series_id = ?", (series_id,)
    )
    row = cursor.fetchone()
    return row[0] if row[0] else None

def incremental_load(series_id: str, conn: sqlite3.Connection):
    last_date = get_last_date(conn, series_id)
    start = last_date if last_date else '1776-07-04'  # FRED's "beginning of time"

    series = fred.get_series(series_id, observation_start=start)
    if series.empty:
        return

    df = series.reset_index()
    df.columns = ['date', 'value']
    df['series_id'] = series_id
    df.to_sql('observations', conn, if_exists='append', index=False)
```

### Pattern C: Release-Triggered Load

Poll `fred/series/updates` to detect newly released data, then fetch only updated series.

```python
import requests

def get_recently_updated(api_key: str, limit: int = 100) -> list[str]:
    resp = requests.get(
        'https://api.stlouisfed.org/fred/series/updates',
        params={
            'api_key': api_key,
            'file_type': 'json',
            'filter_value': 'macro',
            'limit': limit,
        }
    )
    resp.raise_for_status()
    return [s['id'] for s in resp.json()['seriess']]
```

### Pattern D: Bulk Download (No API)

For large-scale ingestion, FRED publishes complete database dumps:

- **FRED bulk download**: `https://fred.stlouisfed.org/data/` — individual `.txt` files per series
- **FRED-MD / FRED-QD**: Curated monthly/quarterly macro datasets published by McCracken & Ng (2016). These are CSV files updated monthly, containing ~130 monthly or ~248 quarterly series commonly used in academic research.

```python
import pandas as pd

# FRED-MD: Monthly dataset (~130 macro series)
FRED_MD_URL = 'https://files.stlouisfed.org/files/htdocs/fred-md/monthly/current.csv'
df = pd.read_csv(FRED_MD_URL, skiprows=0)
# First row contains transformation codes, data starts row 2
transform_codes = df.iloc[0]
df = df.iloc[1:].reset_index(drop=True)
df['sasdate'] = pd.to_datetime(df['sasdate'])

# FRED-QD: Quarterly dataset
FRED_QD_URL = 'https://files.stlouisfed.org/files/htdocs/fred-md/quarterly/current.csv'
```

### Pattern E: Vintage / Real-Time Data (ALFRED)

Fetch data as it was known on a specific past date — important for backtesting to avoid look-ahead bias.

```python
from fredapi import Fred
import pandas as pd

fred = Fred(api_key='your_api_key')

# Get all vintage releases for a series
all_releases = fred.get_series_all_releases('GDPC1')
# Returns DataFrame with columns: date, value, realtime_start, realtime_end

# Get data as it was known on 2020-01-15
vintage = fred.get_series('GDPC1',
                           realtime_start='2020-01-15',
                           realtime_end='2020-01-15')
```

---

## 5. Data Formats

### JSON Response Structure

The default and recommended format. The `observations` endpoint returns:

```json
{
  "realtime_start": "2024-01-01",
  "realtime_end": "2024-12-31",
  "observation_start": "1947-01-01",
  "observation_end": "9999-12-31",
  "units": "lin",
  "output_type": 1,
  "file_type": "json",
  "order_by": "observation_date",
  "sort_order": "asc",
  "count": 308,
  "offset": 0,
  "limit": 100000,
  "observations": [
    {
      "realtime_start": "2024-01-01",
      "realtime_end": "2024-12-31",
      "date": "1947-01-01",
      "value": "2033.061"
    }
  ]
}
```

**Critical gotcha:** Missing values are returned as the string `"."` — not `null`, not `NaN`. Always handle explicitly:

```python
df['value'] = pd.to_numeric(df['value'], errors='coerce')  # '.' becomes NaN
```

### Other Formats

| Format | `file_type` value | Notes |
|---|---|---|
| JSON | `json` | Default; recommended for programmatic access |
| XML | `xml` | Verbose; only useful if consuming with XML tooling |
| Text | `txt` | Space-delimited; easy to parse but fragile |
| Excel | `xls` | Returns `.xls` binary; not recommended for automation |

### Series Metadata Fields

| Field | Example | Notes |
|---|---|---|
| `id` | `GDPC1` | Unique series identifier |
| `title` | `Real Gross Domestic Product` | Human-readable name |
| `units` | `Billions of Chained 2017 Dollars` | Units of measure |
| `frequency` | `Quarterly` | Native frequency |
| `seasonal_adjustment` | `Seasonally Adjusted Annual Rate` | SA status |
| `last_updated` | `2024-01-25 07:36:02-06` | Last revision timestamp |
| `observation_start` | `1947-01-01` | Earliest data point |
| `observation_end` | `2023-10-01` | Most recent data point |
| `popularity` | `91` | 0–100 FRED popularity score |
| `notes` | long string | Source description, methodology notes |

---

## 6. Storage and Caching Best Practices

### Schema Design (Relational / SQL)

```sql
-- Series metadata table
CREATE TABLE fred_series (
    series_id     TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    units         TEXT,
    frequency     TEXT,
    seasonal_adj  TEXT,
    last_updated  TIMESTAMP,
    obs_start     DATE,
    obs_end       DATE,
    fetched_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Observations table
CREATE TABLE fred_observations (
    series_id      TEXT NOT NULL REFERENCES fred_series(series_id),
    obs_date       DATE NOT NULL,
    value          DOUBLE PRECISION,
    realtime_start DATE,  -- populated only for vintage data
    realtime_end   DATE,  -- populated only for vintage data
    PRIMARY KEY (series_id, obs_date)
);

CREATE INDEX idx_obs_series_date ON fred_observations(series_id, obs_date DESC);
```

### Parquet / Columnar Storage

```python
import pandas as pd

def cache_series(series_id: str, df: pd.DataFrame, cache_dir: str = './fred_cache'):
    path = f'{cache_dir}/{series_id}.parquet'
    df.to_parquet(path, engine='pyarrow', compression='snappy')

def load_cached(series_id: str, cache_dir: str = './fred_cache') -> pd.DataFrame | None:
    path = f'{cache_dir}/{series_id}.parquet'
    try:
        return pd.read_parquet(path)
    except FileNotFoundError:
        return None
```

### Cache-Aside Pattern with Staleness Check

```python
import os
import time
from fredapi import Fred
import pandas as pd

fred = Fred(api_key='your_api_key')
CACHE_TTL_SECONDS = 86400  # 1 day

def get_series_cached(series_id: str, cache_dir: str = './fred_cache') -> pd.DataFrame:
    path = f'{cache_dir}/{series_id}.parquet'

    if os.path.exists(path):
        age = time.time() - os.path.getmtime(path)
        if age < CACHE_TTL_SECONDS:
            return pd.read_parquet(path)

    series = fred.get_series(series_id)
    df = series.to_frame(name='value')
    os.makedirs(cache_dir, exist_ok=True)
    df.to_parquet(path)
    return df
```

### Update Frequency Recommendations

| Series Frequency | Suggested Refresh |
|---|---|
| Daily (market data) | Daily, after 5 PM ET |
| Weekly | Weekly, Monday morning |
| Monthly | Monthly, after BLS/BEA release dates |
| Quarterly | Quarterly |
| Annual | Annual |

Use `fred/series` metadata to read `last_updated` and skip fetching if nothing has changed since your last pull.

---

## 7. Gotchas and Limitations

### Missing Values as `"."`
FRED returns `"."` (a period string) for missing observations — not `null`, not `NaN`. Always use `pd.to_numeric(..., errors='coerce')`.

### Date Alignment Across Frequencies
When joining series of different frequencies, the date index will not naturally align. A monthly series uses the first of the month; a quarterly series uses the first day of the quarter. Use `pd.DataFrame.resample()` or `pd.merge_asof()` deliberately.

### Seasonal Adjustment Variants
Many series exist in both SA and NSA variants with similar but different IDs (e.g., `UNRATE` vs. `UNRATENSA`, `CPIAUCSL` vs. `CPIAUCNS`). Confirm which variant you need before building pipelines.

### Revisions (Vintage Data)
FRED always returns the **most recent vintage** by default. Economic data is frequently revised. For backtesting, use `realtime_start`/`realtime_end` or ALFRED to get point-in-time accurate data.

### Units and Transformations
FRED can return pre-transformed data via the `units` parameter. If you apply your own transformations downstream, set `units=lin` (raw) to avoid double-transforming.

### Pagination
The default `limit` is 100,000 observations per request, which covers most series entirely. Some very long daily series may need pagination via `offset`. Always check the `count` field in the response.

### API Key Security
Never hardcode the API key. Use environment variables:

```python
import os
from fredapi import Fred

fred = Fred(api_key=os.environ['FRED_API_KEY'])
```

### FRED-MD Transformation Codes
The FRED-MD bulk file's first row contains transformation codes that must be applied before use in models:

| Code | Transformation |
|---|---|
| 1 | No transformation |
| 2 | First difference: `x_t - x_{t-1}` |
| 3 | Second difference |
| 4 | Log |
| 5 | First difference of log |
| 6 | Second difference of log |
| 7 | First difference of percent change |

```python
import numpy as np

def apply_fred_md_transform(series: pd.Series, code: int) -> pd.Series:
    if code == 1:   return series
    elif code == 2: return series.diff()
    elif code == 3: return series.diff().diff()
    elif code == 4: return np.log(series)
    elif code == 5: return np.log(series).diff()
    elif code == 6: return np.log(series).diff().diff()
    elif code == 7: return series.pct_change().diff()
    else: raise ValueError(f"Unknown transform code: {code}")
```

### No Streaming
FRED is a REST API with no streaming or push notifications. The closest substitute is polling `fred/series/updates` or the FRED release calendar (`fred/release/dates`).

---

## 8. Summary: Recommended Stack

| Concern | Recommendation |
|---|---|
| Python client | `fredapi` |
| API key management | Environment variable `FRED_API_KEY` |
| Data format | JSON → `pd.DataFrame` |
| Missing values | `pd.to_numeric(..., errors='coerce')` |
| Local storage | Parquet files (per-series) or SQLite/PostgreSQL |
| Refresh strategy | Cache-aside with staleness check per series frequency |
| Large-scale ingestion | FRED-MD/FRED-QD bulk CSVs or direct bulk download |
| Backtesting | Use ALFRED vintage data via `realtime_start`/`realtime_end` |
| Rate limiting | 0.5s sleep between calls; stay under 120 req/min |

---

## 9. Reference Series IDs

Commonly ingested macro series:

| Series ID | Title | Frequency |
|---|---|---|
| `GDPC1` | Real GDP | Quarterly |
| `UNRATE` | Civilian Unemployment Rate | Monthly |
| `CPIAUCSL` | CPI All Urban Consumers | Monthly |
| `PCEPI` | PCE Price Index | Monthly |
| `FEDFUNDS` | Effective Federal Funds Rate | Monthly |
| `DFF` | Federal Funds Rate (daily) | Daily |
| `GS10` | 10-Year Treasury Constant Maturity | Monthly |
| `DGS10` | 10-Year Treasury (daily) | Daily |
| `T10Y2Y` | 10Y-2Y Treasury Spread | Daily |
| `MORTGAGE30US` | 30-Year Fixed Mortgage Rate | Weekly |
| `PAYEMS` | Nonfarm Payrolls | Monthly |
| `INDPRO` | Industrial Production Index | Monthly |
| `HOUST` | Housing Starts | Monthly |
| `RETAILSL` | Retail Sales | Monthly |
| `M2SL` | M2 Money Supply | Monthly |
| `DEXUSEU` | USD/EUR Exchange Rate | Daily |
| `VIXCLS` | CBOE VIX | Daily |
| `SP500` | S&P 500 Index | Daily |
| `BAMLH0A0HYM2` | ICE BofA HY Spread | Daily |
