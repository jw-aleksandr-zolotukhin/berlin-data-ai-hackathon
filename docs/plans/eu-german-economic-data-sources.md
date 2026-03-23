# EU & German Economic Data Sources: Research Report

*Research based on training knowledge through August 2025. API endpoint structures and package versions should be verified against current documentation before production use.*

---

## 1. ECB Statistical Data Warehouse (SDW)

### Overview
The European Central Bank's Statistical Data Warehouse is the primary source for euro area monetary, financial, and banking statistics. It is the EU equivalent of FRED for central bank data.

**API base:** `https://data-api.ecb.europa.eu/service/`

### Data Available
- **Monetary & financial statistics:** M1/M2/M3 money supply, credit aggregates
- **Interest rates:** ECB key rates, EURIBOR, government bond yields, OIS rates
- **Exchange rates:** EUR/USD, EUR/GBP, and ~40 other currency pairs (daily, monthly)
- **Balance of payments & international investment position**
- **Banking statistics:** consolidated banking data, supervisory data
- **Inflation:** HICP for euro area and member states
- **GDP, employment** (aggregated from Eurostat)
- **Target2 balances**

### API Access

The ECB SDW exposes a **SDMX REST API**.

```
# Data query
GET https://data-api.ecb.europa.eu/service/data/{flowRef}/{key}?startPeriod=2020-01&format=jsondata

# Example: EUR/USD daily exchange rate
GET https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?startPeriod=2020-01-01&format=jsondata

# List dataflows
GET https://data-api.ecb.europa.eu/service/dataflow/ECB/all/latest
```

**Formats:** JSON (SDMX-JSON), XML (SDMX-ML), CSV
**Authentication:** None required
**Rate limits:** Not formally published; generous for reasonable use.

### Python Access

**`sdmx1` (pandaSDMX):**
```python
import sdmx
ecb = sdmx.Client("ECB")
resp = ecb.data("EXR", key={"CURRENCY": "USD", "FREQ": "D"}, params={"startPeriod": "2020"})
df = sdmx.to_pandas(resp)
```

**`ecbdata` (lightweight wrapper):**
```python
from ecbdata import ecbdata
df = ecbdata.get_series("EXR.D.USD.EUR.SP00.A", start="2020-01-01")
```

**Direct requests:**
```python
import requests
url = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A"
r = requests.get(url, params={"format": "csvdata", "startPeriod": "2020-01-01"})
```

### Quirks & Limitations
- **SDMX key syntax is non-obvious.** Keys follow a positional dot-separated format (e.g., `D.USD.EUR.SP00.A` = daily, USD, EUR base, spot, average). Consult the data structure definition (DSD) to understand positions.
- Metadata queries are necessary before data queries — no single discovery endpoint returns human-readable series IDs.
- The `sdmx1` library handles DSD lookup automatically but has a learning curve.
- JSON response structure is verbose; the CSV format is easier for quick work.
- Data revisions are not flagged; point-in-time historical data is not available.

---

## 2. Eurostat

### Overview
The statistical office of the European Union. Broadest coverage of socioeconomic statistics across all 27 EU member states plus candidate countries. Closest EU equivalent to the US Census Bureau + BLS combined.

**API base:** `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/`

### Data Available

| Theme | Examples |
|---|---|
| Economy & finance | GDP, government debt/deficit, national accounts, HICP |
| Population & social | Population, migration, education, health, poverty |
| Labour market | Employment, unemployment, wages, labour costs |
| Industry & services | Industrial production, trade in services |
| International trade | Imports/exports by product (CN/HS codes) and country |
| Agriculture & environment | Farm structure, energy, emissions, waste |
| Regional statistics (NUTS) | All above broken down to NUTS-2 and NUTS-3 regions |
| Science & technology | R&D spending, patents, digital economy |

### API Access

**Modern SDMX API (v1.0):**
```
GET https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{datasetCode}?{params}

# Example: HICP annual inflation for Germany
GET https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind?geo=DE&unit=RCH_A&coicop=CP00&sinceTimePeriod=2015&format=JSON
```

**Authentication:** None required
**Rate limits:** Not formally documented. Bulk downloads should use delays. Large datasets time out — always filter.

### Python Access

**`eurostat` package (most popular):**
```python
import eurostat

# List available datasets
toc = eurostat.get_toc_df()

# Get a dataset
df = eurostat.get_data_df("prc_hicp_aind")

# With filters
df = eurostat.get_data_df("prc_hicp_aind", filter_pars={"geo": ["DE", "FR"], "unit": "RCH_A"})
```

**`sdmx1`:**
```python
import sdmx
estat = sdmx.Client("ESTAT")
resp = estat.data("prc_hicp_aind", key={"geo": "DE", "unit": "RCH_A"})
df = sdmx.to_pandas(resp)
```

### Quirks & Limitations
- **Dataset size:** Some datasets are enormous. Always filter by `geo`, `time`, and dimensions. Unfiltered requests frequently time out.
- **Dimension codes:** Values use coded labels (e.g., `DE` for Germany, `CP00` for all-items HICP). Look up label dictionaries with `get_dic()`.
- **Missing value flags:** `b` = break in series, `e` = estimated, `p` = provisional. The `eurostat` package preserves these as separate flag columns.
- **NUTS regional data** requires specifying `geo` codes at the right NUTS level (NUTS-0 = country, NUTS-1 = major region, NUTS-2 = standard region, NUTS-3 = sub-region).
- No vintage/point-in-time access — always returns latest revision.

---

## 3. Deutsche Bundesbank

### Overview
The German central bank, member of the European System of Central Banks. Publishes comprehensive German monetary, banking, and balance of payments statistics, often at higher frequency and detail than ECB/Eurostat aggregates.

**SDMX API base:** `https://api.statistiken.bundesbank.de/rest/`

### Data Available

| Category | Details |
|---|---|
| Money & banking | German bank balance sheets, credit to households/corporates, deposit rates |
| Capital markets | German government bond yields (Bunds), corporate bonds |
| Exchange rates | EUR bilateral rates; historical DEM rates |
| Balance of payments | German current account, trade balance, FDI, portfolio flows |
| Banking supervision | MFI statistics for German banks |
| External debt | German external debt by sector |
| Historical series | Pre-euro Deutsche Mark interest rates and monetary aggregates |

### API Access

```
GET https://api.statistiken.bundesbank.de/rest/data/{flowRef}/{key}?startPeriod=2020&format=csv

# Example: 10-year Bund yield (daily)
GET https://api.statistiken.bundesbank.de/rest/data/BBIS1/D.I.ZST.USGB.EUR.RT.B?startPeriod=2020-01-01&format=csv

# List dataflows
GET https://api.statistiken.bundesbank.de/rest/dataflow/BBK/all/latest
```

**Formats:** CSV, XML (SDMX-ML), JSON (SDMX-JSON)
**Authentication:** None required

### Python Access

No dedicated Python package — use `sdmx1` or direct `requests`:
```python
import requests
url = "https://api.statistiken.bundesbank.de/rest/data/BBIS1/D.I.ZST.USGB.EUR.RT.B"
r = requests.get(url, params={"format": "csv", "startPeriod": "2020-01-01"})
```

### Quirks & Limitations
- **Series key discovery is difficult.** The web portal is the easiest way to find series codes.
- German-language documentation is more complete than English.
- Micro/granular banking data (individual bank-level) is not publicly available.
- RDSC microdata (e.g., Securities Holdings Statistics, HFCS) requires registration and data use agreements.
- API occasionally returns errors on large requests — always add `startPeriod`/`endPeriod`.

---

## 4. Destatis (German Federal Statistical Office)

### Overview
Statistisches Bundesamt — Germany's national statistics institute. Primary source for official German GDP, CPI, employment, trade, and population data.

**GENESIS API base:** `https://www-genesis.destatis.de/genesisWS/rest/2020/`

### Data Available

| Category | Examples |
|---|---|
| National accounts (VGR) | GDP (expenditure/income/production), GVA by sector, quarterly flash |
| Prices | CPI (national), PPI, import/export price indices, construction prices |
| Labour market | Employment, unemployment (ILO basis), wages, working hours |
| External trade | Imports/exports by product (CN/HS) and partner country (monthly) |
| Industrial production | Manufacturing output by sector (monthly) |
| Construction | Building permits, construction output |
| Retail & services | Retail sales, turnover in services |
| Population | Census, births, deaths, migration |
| Government finance | Public sector revenue/expenditure |
| Regional (Länder) | Most above broken down by federal state |

### API Access

```
Base URL: https://www-genesis.destatis.de/genesisWS/rest/2020/

# Download a table as CSV
GET /data/tablefile?username=GUEST&password=GUEST&name=61111-0001&area=all&format=ffcsv

# Retrieve a time series
GET /data/timeseries

# Search tables
GET /catalogue/tables
```

**Authentication:** GUEST/GUEST provides read access to most public data. Free registration unlocks full access.
**Rate limits:** GUEST account ~1 request per 5 seconds recommended.

### Python Access

**`wiesbaden` package:**
```python
from wiesbaden import retrieve_data, save_credentials

# Save credentials (one-time)
save_credentials(username="GUEST", password="GUEST", datenbank="destatis")

# Retrieve German CPI
df = retrieve_data(tablename="61111-0001", datenbank="destatis")

# Search for tables
from wiesbaden import retrieve_catalogue
tables = retrieve_catalogue(term="Verbraucherpreisindex", datenbank="destatis")
```

**Direct requests:**
```python
import requests
params = {
    "username": "GUEST",
    "password": "GUEST",
    "name": "61111-0001",
    "area": "all",
    "format": "ffcsv"
}
r = requests.get("https://www-genesis.destatis.de/genesisWS/rest/2020/data/tablefile", params=params)
```

### Quirks & Limitations
- **Table code system:** Data is organized by numeric codes (e.g., `61111-0001` for CPI). Browse via the web interface or `catalogue/tables`.
- GUEST account is rate-limited; register for a free account to avoid throttling.
- Seasonal adjustment and raw series are separate — request the right version explicitly.
- **Use flat CSV format (`ffcsv`)** — much easier to parse than the default XLSX with merged cells.
- Each federal state has its own GENESIS instance for sub-Länder regional data.

---

## 5. OECD Data

### Overview
Internationally comparable statistics for 38 member countries (all major EU economies included). Useful for German/EU data alongside US, Japan, and other OECD members.

**SDMX API base:** `https://sdmx.oecd.org/public/rest/`
**Legacy API base:** `https://stats.oecd.org/SDMX-JSON/data/`

### Data Available — EU/German Relevant

| Category | Dataset Examples |
|---|---|
| National accounts | GDP, GNI, household saving, investment (annual + quarterly) |
| Labour | Employment, unemployment (harmonised), wages, labour productivity |
| Prices | CPI, PPI, GDP deflator, house prices |
| Trade | Imports/exports of goods and services, trade in value added (TiVA) |
| Financial | Interest rates, exchange rates, share prices |
| Fiscal | Government revenue/expenditure/debt |
| Tax | Revenue Statistics, Corporate Tax Statistics |
| Regional | Regional GDP/employment (TL2/TL3, comparable to NUTS) |

### API Access

**Legacy API (simpler, widely documented):**
```
GET https://stats.oecd.org/SDMX-JSON/data/{datasetCode}/{dimensions}/OECD?startTime=2010&endTime=2023&contentType=csv

# Example: German harmonised unemployment
GET https://stats.oecd.org/SDMX-JSON/data/STLABOUR/DEU.LR.ST.Q/OECD?startTime=2015&contentType=csv
```

**Authentication:** None required

### Python Access

**`sdmx1`:**
```python
import sdmx
oecd = sdmx.Client("OECD")
resp = oecd.data("QNA", key={"LOCATION": "DEU", "SUBJECT": "B1_GE", "MEASURE": "GPSA", "FREQUENCY": "Q"})
df = sdmx.to_pandas(resp)
```

### Quirks & Limitations
- **Two APIs in transition:** Old `stats.oecd.org` and new `sdmx.oecd.org` co-exist. Prefer the legacy API for quick work.
- OECD data is internationally harmonised — Germany-specific nuances may be smoothed out versus Destatis/Bundesbank.
- Large datasets (STAN, TiVA) time out without filters.
- `OECD.Stat` (legacy platform) is being deprecated — some datasets have already migrated.

---

## 6. Additional Notable Sources

### BIS (Bank for International Settlements)

**API base:** `https://stats.bis.org/api/v1/`

Key datasets:
- **Locational & consolidated banking statistics** (cross-border lending/borrowing — Germany included)
- **Property prices** (residential real estate, long time series — one of the best available)
- **Credit-to-GDP gaps** (early warning indicator)
- **Total credit to non-financial sector**
- **Effective exchange rates**

```python
import sdmx
bis = sdmx.Client("BIS")
```

**Quirk:** The property price database is uniquely valuable for long-run real estate analysis. Cross-border banking statistics require understanding "reporting country" vs. "counterparty country" dimensions carefully.

---

### EBA (European Banking Authority)

**URL:** `https://www.eba.europa.eu/risk-analysis-and-data`

Key datasets:
- **EU-wide stress test results** (every 2 years, bank-level)
- **Transparency exercise data** (semi-annual, bank-level capital/asset quality)
- **Risk indicators dashboard** (aggregate EU banking KPIs)

**Access:** XLSX/CSV downloads; no REST API. Use `pandas.read_excel()`.

**Quirk:** Bank-level granularity is uniquely valuable for banking research — but only for large institutions in the stress test sample.

---

### ESRB (European Systemic Risk Board)

**URL:** `https://www.esrb.europa.eu/pub/`

Key datasets:
- EU financial stability indicators
- Macro-prudential policy database
- **Risk Dashboard** (quarterly Excel file — structured EU-level banking, market, and macro-prudential indicators)

**Access:** File downloads; no API.

---

### IMF (International Monetary Fund)

**API base:** `https://dataservices.imf.org/REST/SDMX_JSON.svc/`

Key datasets:
- **IFS:** Exchange rates, interest rates, balance of payments for Germany and EU members
- **WEO:** GDP, inflation, current account — semi-annual
- **DOTS:** Bilateral trade flows

```python
import requests
url = "https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/IFS/Q.DE.NGDP_R_PCH"
r = requests.get(url)
```

**Package:** `imfp` simplifies access.

---

### FRED — German/EU Series

FRED itself hosts many German and EU series sourced from the above institutions — a convenient uniform interface for the most common series:

```python
import pandas_datareader as pdr

# German CPI (source: Destatis/Eurostat)
df = pdr.get_data_fred("DEUCPIALLMINMEI", start="2000-01-01")
# EUR/USD
df2 = pdr.get_data_fred("DEXUSEU")
```

**Advantage:** Uniform API, no auth, `pandas_datareader` integration.
**Disadvantage:** Limited subset; revisions lag primary sources.

---

## Summary Comparison Table

| Source | Primary Focus | Best For | API Type | Python Package | Auth Required |
|---|---|---|---|---|---|
| **ECB SDW** | Euro area monetary/financial | Interest rates, exchange rates, banking | SDMX REST | `sdmx1`, `ecbdata` | No |
| **Eurostat** | EU-wide socioeconomic | GDP, HICP, trade, regional (NUTS) | SDMX REST | `eurostat`, `sdmx1` | No |
| **Bundesbank** | German monetary/banking | German rates, BoP, banking details | SDMX REST | `sdmx1`, requests | No |
| **Destatis** | German national statistics | German GDP, CPI, employment, trade | GENESIS REST | `wiesbaden` | GUEST/GUEST |
| **OECD** | Internationally harmonised | Cross-country comparisons | SDMX REST | `sdmx1`, `oecd` | No |
| **BIS** | International banking/finance | Cross-border banking, property prices | SDMX REST | `sdmx1`, requests | No |
| **EBA** | EU banking supervision | Bank stress tests, transparency data | File downloads | pandas + requests | No |
| **IMF** | Global macro | WEO, IFS, trade | SDMX-JSON | `imfp`, requests | No |
| **FRED** | Multi-source aggregator | Convenience layer for key series | REST | `pandas_datareader` | No |

---

## Practical Recommendations

1. **Start with FRED** for quick access to the most common German/EU series — uniform interface, no auth, well-maintained.
2. **Use Eurostat** for EU-wide comparisons or NUTS regional breakdowns. The `eurostat` Python package is the most ergonomic.
3. **Use ECB SDW** for monetary policy variables — EURIBOR, ECB rates, EUR exchange rates, M3. `ecbdata` is simpler than `sdmx1` for quick lookups.
4. **Use Destatis** for official German national statistics at highest detail and frequency. Register for a free account to avoid GUEST throttling.
5. **Use Bundesbank** for German-specific banking and capital markets data not available via ECB aggregates.
6. **Use OECD** when building panels requiring non-EU comparators (US, Japan, etc.) alongside German/EU data.
7. **Use BIS** for cross-border banking flows and long-run property price data.
8. **For all SDMX sources**, `sdmx1` provides a unified interface — invest time upfront in understanding the SDMX key/DSD lookup pattern. One library covers ECB, Eurostat, OECD, BIS, and Bundesbank.
