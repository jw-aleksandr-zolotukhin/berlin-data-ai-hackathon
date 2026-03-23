# Economic Data to Snowflake Pipeline: Implementation Plan

> **For agentic workers:** This plan has DAG annotations (depends_on fields) -- use executing-dag-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a config-driven Python pipeline that incrementally ingests economic time series from FRED, ECB, Eurostat, Bundesbank, Destatis, OECD, and BIS into Snowflake using an adapter pattern.

**Architecture:** A BaseAdapter ABC defines the fetch interface; one adapter per source translates source-specific APIs into a unified FetchResult (SeriesMetadata + DataFrame). A SnowflakeWriter handles DDL and idempotent MERGE upserts. A Pipeline orchestrator wires config to adapters to writer and tracks incremental state via MAX(obs_date) per series.

**Tech Stack:** Python 3.11+, fredapi, sdmx1, wiesbaden, snowflake-connector-python, pyyaml, pandas, pytest

---

## File Structure

```
econ_pipeline/
  __init__.py
  models.py              # SeriesMetadata, FetchResult dataclasses
  config.py              # PipelineConfig, SourceConfig loaded from YAML
  adapters/
    __init__.py
    base.py              # BaseAdapter ABC
    fred.py              # FredAdapter
    sdmx.py              # SdmxAdapter (ECB, Eurostat, Bundesbank, OECD, BIS)
    destatis.py          # DestatisAdapter
  writer.py              # SnowflakeWriter: DDL + MERGE upserts
  pipeline.py            # Pipeline orchestrator: config -> adapters -> writer
  cli.py                 # CLI entry point
  __main__.py            # python -m econ_pipeline support
config/
  series.yaml            # Example: which series per source
tests/
  __init__.py
  conftest.py
  test_models.py
  test_config.py
  test_fred_adapter.py
  test_sdmx_adapter.py
  test_destatis_adapter.py
  test_writer.py
  test_pipeline.py
pyproject.toml
```

---

## Chunk 1: Foundation (Tasks t1-t4)

### Task 1: Data Models

```yaml
- id: t1
  title: "Define SeriesMetadata and FetchResult dataclasses"
  agent: architect
  depends_on: []
  output: "econ_pipeline/models.py, tests/test_models.py"
  files: ["econ_pipeline/__init__.py", "econ_pipeline/models.py", "tests/__init__.py", "tests/test_models.py", "pyproject.toml"]
```

**Files:**
- Create: `pyproject.toml`
- Create: `econ_pipeline/__init__.py`
- Create: `econ_pipeline/models.py`
- Create: `tests/__init__.py`
- Create: `tests/test_models.py`

- [ ] **Step 1: Create project scaffolding**

Create `pyproject.toml`:

```toml
[project]
name = "econ-pipeline"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "pandas>=2.0",
    "pyyaml>=6.0",
    "fredapi>=0.5",
    "sdmx1>=2.10",
    "wiesbaden>=0.4",
    "snowflake-connector-python>=3.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "pytest-cov>=4.0",
]

[project.scripts]
econ-pipeline = "econ_pipeline.cli:main"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

Create `econ_pipeline/__init__.py`:

```python
"""Economic data ingestion pipeline."""
```

Create `tests/__init__.py`:

```python
```

- [ ] **Step 2: Write failing tests for models**

Create `tests/test_models.py`:

```python
"""Tests for econ_pipeline.models."""

from datetime import date, datetime

import pandas as pd
import pytest

from econ_pipeline.models import FetchResult, SeriesMetadata


class TestSeriesMetadata:
    """Tests for SeriesMetadata dataclass."""

    def test_create_with_all_fields(self) -> None:
        meta = SeriesMetadata(
            source="fred",
            series_id="GDPC1",
            title="Real GDP",
            units="Billions of Chained 2017 Dollars",
            frequency="Quarterly",
            seasonal_adj="Seasonally Adjusted Annual Rate",
            obs_start=date(1947, 1, 1),
            obs_end=date(2024, 1, 1),
            last_updated=datetime(2024, 1, 25, 13, 36, 2),
        )
        assert meta.source == "fred"
        assert meta.series_id == "GDPC1"
        assert meta.title == "Real GDP"
        assert meta.units == "Billions of Chained 2017 Dollars"
        assert meta.frequency == "Quarterly"
        assert meta.seasonal_adj == "Seasonally Adjusted Annual Rate"
        assert meta.obs_start == date(1947, 1, 1)
        assert meta.obs_end == date(2024, 1, 1)
        assert meta.last_updated == datetime(2024, 1, 25, 13, 36, 2)

    def test_create_with_optional_fields_none(self) -> None:
        meta = SeriesMetadata(
            source="ecb",
            series_id="EXR.D.USD.EUR.SP00.A",
        )
        assert meta.source == "ecb"
        assert meta.series_id == "EXR.D.USD.EUR.SP00.A"
        assert meta.title is None
        assert meta.units is None
        assert meta.frequency is None
        assert meta.seasonal_adj is None
        assert meta.obs_start is None
        assert meta.obs_end is None
        assert meta.last_updated is None

    def test_source_cannot_be_empty(self) -> None:
        with pytest.raises(ValueError, match="source must not be empty"):
            SeriesMetadata(source="", series_id="GDPC1")

    def test_series_id_cannot_be_empty(self) -> None:
        with pytest.raises(ValueError, match="series_id must not be empty"):
            SeriesMetadata(source="fred", series_id="")


class TestFetchResult:
    """Tests for FetchResult dataclass."""

    def test_create_with_metadata_and_dataframe(self) -> None:
        meta = SeriesMetadata(source="fred", series_id="UNRATE")
        df = pd.DataFrame(
            {"obs_date": [date(2024, 1, 1), date(2024, 2, 1)], "value": [3.7, 3.9]}
        )
        result = FetchResult(metadata=meta, observations=df)
        assert result.metadata.series_id == "UNRATE"
        assert len(result.observations) == 2

    def test_create_with_empty_dataframe(self) -> None:
        meta = SeriesMetadata(source="fred", series_id="EMPTY")
        df = pd.DataFrame(columns=["obs_date", "value"])
        result = FetchResult(metadata=meta, observations=df)
        assert result.is_empty

    def test_is_empty_false_when_data_present(self) -> None:
        meta = SeriesMetadata(source="fred", series_id="UNRATE")
        df = pd.DataFrame(
            {"obs_date": [date(2024, 1, 1)], "value": [3.7]}
        )
        result = FetchResult(metadata=meta, observations=df)
        assert not result.is_empty

    def test_observations_must_have_obs_date_column(self) -> None:
        meta = SeriesMetadata(source="fred", series_id="UNRATE")
        df = pd.DataFrame({"date": [date(2024, 1, 1)], "value": [3.7]})
        with pytest.raises(ValueError, match="observations must have 'obs_date' column"):
            FetchResult(metadata=meta, observations=df)

    def test_observations_must_have_value_column(self) -> None:
        meta = SeriesMetadata(source="fred", series_id="UNRATE")
        df = pd.DataFrame({"obs_date": [date(2024, 1, 1)], "amount": [3.7]})
        with pytest.raises(ValueError, match="observations must have 'value' column"):
            FetchResult(metadata=meta, observations=df)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `python -m pytest tests/test_models.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.models'`

- [ ] **Step 4: Implement models**

Create `econ_pipeline/models.py`:

```python
"""Unified data models for the economic data pipeline."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

import pandas as pd


@dataclass(frozen=True)
class SeriesMetadata:
    """Metadata describing an economic time series.

    Required fields: source, series_id.
    All other fields are optional and may not be available from every source.
    """

    source: str
    series_id: str
    title: str | None = None
    units: str | None = None
    frequency: str | None = None
    seasonal_adj: str | None = None
    obs_start: date | None = None
    obs_end: date | None = None
    last_updated: datetime | None = None

    def __post_init__(self) -> None:
        if not self.source:
            raise ValueError("source must not be empty")
        if not self.series_id:
            raise ValueError("series_id must not be empty")


@dataclass(frozen=True)
class FetchResult:
    """Result of fetching a single time series from a source.

    Contains metadata about the series and a DataFrame of observations.
    The observations DataFrame must have columns: obs_date (date), value (float).
    """

    metadata: SeriesMetadata
    observations: pd.DataFrame

    def __post_init__(self) -> None:
        if "obs_date" not in self.observations.columns:
            raise ValueError("observations must have 'obs_date' column")
        if "value" not in self.observations.columns:
            raise ValueError("observations must have 'value' column")

    @property
    def is_empty(self) -> bool:
        """Return True if the observations DataFrame has no rows."""
        return len(self.observations) == 0
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `python -m pytest tests/test_models.py -v`
Expected: All 7 tests PASS

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml econ_pipeline/__init__.py econ_pipeline/models.py tests/__init__.py tests/test_models.py
git commit -m "feat: add SeriesMetadata and FetchResult data models with validation"
```

---

### Task 2: Config Loading

```yaml
- id: t2
  title: "Implement YAML config loading with PipelineConfig and SourceConfig"
  agent: developer
  depends_on: [t1]
  output: "econ_pipeline/config.py, tests/test_config.py, tests/conftest.py"
  files: ["econ_pipeline/config.py", "tests/test_config.py", "tests/conftest.py"]
```

**Files:**
- Create: `econ_pipeline/config.py`
- Create: `tests/conftest.py`
- Create: `tests/test_config.py`

- [ ] **Step 1: Write failing tests for config**

Create `tests/conftest.py`:

```python
"""Shared fixtures for the test suite."""

from __future__ import annotations

import textwrap
from pathlib import Path
from typing import Generator

import pytest


@pytest.fixture()
def tmp_yaml(tmp_path: Path) -> Generator[Path, None, None]:
    """Provide a temporary directory for YAML config files."""
    yield tmp_path


@pytest.fixture()
def sample_config_path(tmp_yaml: Path) -> Path:
    """Write a sample series.yaml and return its path."""
    content = textwrap.dedent("""\
        sources:
          fred:
            adapter: fred
            series:
              - id: GDPC1
                title: Real GDP
              - id: UNRATE
                title: Unemployment Rate

          ecb:
            adapter: sdmx
            provider: ECB
            series:
              - flow_ref: EXR
                key: D.USD.EUR.SP00.A
                id: EXR.D.USD.EUR.SP00.A
                title: EUR/USD Daily

          destatis:
            adapter: destatis
            series:
              - table_code: "61111-0001"
                id: "61111-0001"
                title: German CPI
    """)
    path = tmp_yaml / "series.yaml"
    path.write_text(content)
    return path
```

Create `tests/test_config.py`:

```python
"""Tests for econ_pipeline.config."""

from __future__ import annotations

import textwrap
from pathlib import Path

import pytest

from econ_pipeline.config import PipelineConfig, SeriesConfig, SourceConfig


class TestPipelineConfig:
    """Tests for loading pipeline configuration from YAML."""

    def test_load_from_yaml(self, sample_config_path: Path) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        assert len(config.sources) == 3

    def test_source_names(self, sample_config_path: Path) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        names = {s.name for s in config.sources}
        assert names == {"fred", "ecb", "destatis"}

    def test_fred_source_config(self, sample_config_path: Path) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        fred = config.get_source("fred")
        assert fred is not None
        assert fred.adapter == "fred"
        assert len(fred.series) == 2
        assert fred.series[0].id == "GDPC1"
        assert fred.series[0].title == "Real GDP"

    def test_sdmx_source_config(self, sample_config_path: Path) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        ecb = config.get_source("ecb")
        assert ecb is not None
        assert ecb.adapter == "sdmx"
        assert ecb.provider == "ECB"
        assert ecb.series[0].extra["flow_ref"] == "EXR"
        assert ecb.series[0].extra["key"] == "D.USD.EUR.SP00.A"

    def test_destatis_source_config(self, sample_config_path: Path) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        destatis = config.get_source("destatis")
        assert destatis is not None
        assert destatis.adapter == "destatis"
        assert destatis.series[0].extra["table_code"] == "61111-0001"

    def test_get_source_returns_none_for_unknown(
        self, sample_config_path: Path
    ) -> None:
        config = PipelineConfig.from_yaml(sample_config_path)
        assert config.get_source("nonexistent") is None

    def test_load_missing_file_raises(self, tmp_yaml: Path) -> None:
        with pytest.raises(FileNotFoundError):
            PipelineConfig.from_yaml(tmp_yaml / "does_not_exist.yaml")

    def test_load_invalid_yaml_raises(self, tmp_yaml: Path) -> None:
        path = tmp_yaml / "bad.yaml"
        path.write_text(":::not yaml:::")
        with pytest.raises(ValueError, match="Invalid config"):
            PipelineConfig.from_yaml(path)

    def test_load_missing_sources_key_raises(self, tmp_yaml: Path) -> None:
        path = tmp_yaml / "empty.yaml"
        path.write_text("other_key: true\n")
        with pytest.raises(ValueError, match="missing 'sources'"):
            PipelineConfig.from_yaml(path)


class TestSeriesConfig:
    """Tests for individual series configuration."""

    def test_series_config_stores_extra_fields(self) -> None:
        sc = SeriesConfig(
            id="EXR.D.USD.EUR.SP00.A",
            title="EUR/USD",
            extra={"flow_ref": "EXR", "key": "D.USD.EUR.SP00.A"},
        )
        assert sc.extra["flow_ref"] == "EXR"
        assert sc.extra["key"] == "D.USD.EUR.SP00.A"

    def test_series_config_empty_extra(self) -> None:
        sc = SeriesConfig(id="GDPC1", title="Real GDP")
        assert sc.extra == {}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_config.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.config'`

- [ ] **Step 3: Implement config module**

Create `econ_pipeline/config.py`:

```python
"""YAML-based pipeline configuration."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml


@dataclass(frozen=True)
class SeriesConfig:
    """Configuration for a single series to ingest.

    Fields beyond id and title are source-specific and stored in 'extra'.
    """

    id: str
    title: str | None = None
    extra: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class SourceConfig:
    """Configuration for one data source."""

    name: str
    adapter: str
    series: list[SeriesConfig]
    provider: str | None = None


@dataclass(frozen=True)
class PipelineConfig:
    """Top-level pipeline configuration loaded from YAML."""

    sources: list[SourceConfig]

    def get_source(self, name: str) -> SourceConfig | None:
        """Return the SourceConfig with the given name, or None."""
        for src in self.sources:
            if src.name == name:
                return src
        return None

    @classmethod
    def from_yaml(cls, path: Path) -> PipelineConfig:
        """Load pipeline configuration from a YAML file.

        Raises:
            FileNotFoundError: If the file does not exist.
            ValueError: If the YAML is invalid or missing required keys.
        """
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")

        with open(path) as f:
            try:
                raw = yaml.safe_load(f)
            except yaml.YAMLError as exc:
                raise ValueError(f"Invalid config YAML: {exc}") from exc

        if not isinstance(raw, dict) or "sources" not in raw:
            raise ValueError(f"Config file {path} missing 'sources' key")

        sources: list[SourceConfig] = []
        for source_name, source_raw in raw["sources"].items():
            adapter = source_raw.get("adapter", source_name)
            provider = source_raw.get("provider")

            series_list: list[SeriesConfig] = []
            for s in source_raw.get("series", []):
                # 'id' and 'title' are standard; everything else goes to extra
                series_id = s.pop("id")
                series_title = s.pop("title", None)
                extra = dict(s)  # remaining keys are source-specific
                series_list.append(
                    SeriesConfig(id=series_id, title=series_title, extra=extra)
                )

            sources.append(
                SourceConfig(
                    name=source_name,
                    adapter=adapter,
                    series=series_list,
                    provider=provider,
                )
            )

        return cls(sources=sources)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_config.py -v`
Expected: All 11 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/config.py tests/conftest.py tests/test_config.py
git commit -m "feat: add YAML config loading with PipelineConfig and SourceConfig"
```

---

### Task 3: Base Adapter ABC

```yaml
- id: t3
  title: "Define BaseAdapter abstract base class"
  agent: architect
  depends_on: [t1]
  output: "econ_pipeline/adapters/base.py, econ_pipeline/adapters/__init__.py"
  files: ["econ_pipeline/adapters/__init__.py", "econ_pipeline/adapters/base.py"]
```

**Files:**
- Create: `econ_pipeline/adapters/__init__.py`
- Create: `econ_pipeline/adapters/base.py`

- [ ] **Step 1: Create adapters package and base ABC**

Create `econ_pipeline/adapters/__init__.py`:

```python
"""Data source adapters."""

from econ_pipeline.adapters.base import BaseAdapter

__all__ = ["BaseAdapter"]
```

Create `econ_pipeline/adapters/base.py`:

```python
"""Abstract base class for all data source adapters."""

from __future__ import annotations

import abc
from datetime import date

from econ_pipeline.config import SeriesConfig, SourceConfig
from econ_pipeline.models import FetchResult


class BaseAdapter(abc.ABC):
    """Base class for economic data source adapters.

    Each adapter translates a source-specific API into the unified FetchResult
    format. Subclasses must implement fetch_series().

    Usage:
        adapter = SomeAdapter(source_config)
        for series_cfg in source_config.series:
            result = adapter.fetch_series(series_cfg)
    """

    def __init__(self, source_config: SourceConfig) -> None:
        self.source_config = source_config

    @property
    def source_name(self) -> str:
        """Return the source name from config."""
        return self.source_config.name

    @abc.abstractmethod
    def fetch_series(
        self, series_config: SeriesConfig, since: date | None = None
    ) -> FetchResult:
        """Fetch observations for a single series.

        Args:
            series_config: Configuration for the series to fetch.
            since: If provided, only fetch observations after this date.
                   Used for incremental loading.

        Returns:
            FetchResult containing metadata and a DataFrame with columns
            obs_date (date) and value (float). NaN for missing values.

        Raises:
            ConnectionError: If the source API is unreachable.
            ValueError: If the series configuration is invalid.
        """

    def fetch_all(
        self, since_map: dict[str, date] | None = None
    ) -> list[FetchResult]:
        """Fetch all series configured for this source.

        Args:
            since_map: Optional dict mapping series_id -> last known obs_date.
                       Series not in the map are fetched in full.

        Returns:
            List of FetchResult, one per series. Failed series are skipped
            with a logged warning.
        """
        if since_map is None:
            since_map = {}

        results: list[FetchResult] = []
        for series_cfg in self.source_config.series:
            since = since_map.get(series_cfg.id)
            try:
                result = self.fetch_series(series_cfg, since=since)
                results.append(result)
            except Exception as exc:
                import logging

                logging.getLogger(__name__).warning(
                    "Failed to fetch %s/%s: %s",
                    self.source_name,
                    series_cfg.id,
                    exc,
                )
        return results
```

- [ ] **Step 2: Verify import works**

Run: `python -c "from econ_pipeline.adapters.base import BaseAdapter; print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add econ_pipeline/adapters/__init__.py econ_pipeline/adapters/base.py
git commit -m "feat: add BaseAdapter ABC with fetch_series and fetch_all interface"
```

---

### Task 4: Snowflake Writer

```yaml
- id: t4
  title: "Implement SnowflakeWriter with DDL and MERGE upserts"
  agent: developer
  depends_on: [t1]
  output: "econ_pipeline/writer.py, tests/test_writer.py"
  files: ["econ_pipeline/writer.py", "tests/test_writer.py"]
```

**Files:**
- Create: `econ_pipeline/writer.py`
- Create: `tests/test_writer.py`

- [ ] **Step 1: Write failing tests for writer**

Create `tests/test_writer.py`:

```python
"""Tests for econ_pipeline.writer.

All tests use a FakeConnection to avoid real Snowflake calls.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any
from unittest.mock import MagicMock, call

import pandas as pd
import pytest

from econ_pipeline.models import FetchResult, SeriesMetadata
from econ_pipeline.writer import SnowflakeWriter


class FakeCursor:
    """Minimal fake cursor recording executed SQL."""

    def __init__(self) -> None:
        self.executed: list[tuple[str, tuple[Any, ...] | None]] = []
        self._fetchone_results: list[Any] = []
        self._fetchall_results: list[list[Any]] = []

    def execute(self, sql: str, params: tuple[Any, ...] | None = None) -> FakeCursor:
        self.executed.append((sql, params))
        return self

    def fetchone(self) -> Any:
        if self._fetchone_results:
            return self._fetchone_results.pop(0)
        return None

    def fetchall(self) -> list[Any]:
        if self._fetchall_results:
            return self._fetchall_results.pop(0)
        return []

    def close(self) -> None:
        pass


class FakeConnection:
    """Minimal fake Snowflake connection."""

    def __init__(self) -> None:
        self.cursor_instance = FakeCursor()
        self._closed = False

    def cursor(self) -> FakeCursor:
        return self.cursor_instance

    def close(self) -> None:
        self._closed = True


def _make_fetch_result(
    source: str = "fred",
    series_id: str = "UNRATE",
    obs_data: list[tuple[date, float]] | None = None,
) -> FetchResult:
    """Helper to create a FetchResult for tests."""
    meta = SeriesMetadata(
        source=source,
        series_id=series_id,
        title="Test Series",
        units="Percent",
        frequency="Monthly",
        seasonal_adj="SA",
        obs_start=date(2024, 1, 1),
        obs_end=date(2024, 3, 1),
        last_updated=datetime(2024, 3, 15, 10, 0, 0),
    )
    if obs_data is None:
        obs_data = [
            (date(2024, 1, 1), 3.7),
            (date(2024, 2, 1), 3.9),
            (date(2024, 3, 1), 3.8),
        ]
    df = pd.DataFrame(obs_data, columns=["obs_date", "value"])
    return FetchResult(metadata=meta, observations=df)


class TestSnowflakeWriterDDL:
    """Tests for DDL table creation."""

    def test_ensure_tables_executes_create_statements(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        writer.ensure_tables()
        sqls = [sql for sql, _ in conn.cursor_instance.executed]
        assert any("CREATE TABLE IF NOT EXISTS" in s and "series_metadata" in s for s in sqls)
        assert any("CREATE TABLE IF NOT EXISTS" in s and "observations" in s for s in sqls)

    def test_ensure_tables_creates_schema(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn, schema="econ")
        writer.ensure_tables()
        sqls = [sql for sql, _ in conn.cursor_instance.executed]
        assert any("CREATE SCHEMA IF NOT EXISTS" in s and "econ" in s for s in sqls)


class TestSnowflakeWriterMetadata:
    """Tests for metadata upsert."""

    def test_write_metadata_uses_merge(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result()
        writer.write_metadata(result.metadata)
        sqls = [sql for sql, _ in conn.cursor_instance.executed]
        assert any("MERGE INTO" in s and "series_metadata" in s for s in sqls)

    def test_write_metadata_passes_correct_params(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result(source="fred", series_id="GDPC1")
        writer.write_metadata(result.metadata)
        params_list = [p for _, p in conn.cursor_instance.executed if p is not None]
        # At least one call should have the source and series_id
        flat = str(params_list)
        assert "fred" in flat
        assert "GDPC1" in flat


class TestSnowflakeWriterObservations:
    """Tests for observation upsert."""

    def test_write_observations_uses_merge(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result()
        writer.write_observations(result)
        sqls = [sql for sql, _ in conn.cursor_instance.executed]
        assert any("MERGE INTO" in s and "observations" in s for s in sqls)

    def test_write_observations_writes_all_rows(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result()
        writer.write_observations(result)
        # 3 observations should produce 3 MERGE executions
        merge_calls = [
            (sql, p)
            for sql, p in conn.cursor_instance.executed
            if "MERGE INTO" in sql and "observations" in sql
        ]
        assert len(merge_calls) == 3

    def test_write_skips_empty_result(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result(obs_data=[])
        writer.write_observations(result)
        merge_calls = [
            sql
            for sql, _ in conn.cursor_instance.executed
            if "MERGE INTO" in sql and "observations" in sql
        ]
        assert len(merge_calls) == 0


class TestSnowflakeWriterIncremental:
    """Tests for incremental load support."""

    def test_get_last_obs_date_returns_date(self) -> None:
        conn = FakeConnection()
        conn.cursor_instance._fetchone_results = [(date(2024, 2, 1),)]
        writer = SnowflakeWriter(conn)
        result = writer.get_last_obs_date("fred", "UNRATE")
        assert result == date(2024, 2, 1)

    def test_get_last_obs_date_returns_none_when_no_data(self) -> None:
        conn = FakeConnection()
        conn.cursor_instance._fetchone_results = [(None,)]
        writer = SnowflakeWriter(conn)
        result = writer.get_last_obs_date("fred", "UNRATE")
        assert result is None

    def test_get_since_map_returns_dict(self) -> None:
        conn = FakeConnection()
        conn.cursor_instance._fetchall_results = [
            [("GDPC1", date(2024, 1, 1)), ("UNRATE", date(2024, 2, 1))]
        ]
        writer = SnowflakeWriter(conn)
        since_map = writer.get_since_map("fred")
        assert since_map == {"GDPC1": date(2024, 1, 1), "UNRATE": date(2024, 2, 1)}


class TestSnowflakeWriterWrite:
    """Tests for the combined write method."""

    def test_write_calls_metadata_and_observations(self) -> None:
        conn = FakeConnection()
        writer = SnowflakeWriter(conn)
        result = _make_fetch_result()
        writer.write(result)
        sqls = [sql for sql, _ in conn.cursor_instance.executed]
        has_meta_merge = any(
            "MERGE INTO" in s and "series_metadata" in s for s in sqls
        )
        has_obs_merge = any(
            "MERGE INTO" in s and "observations" in s for s in sqls
        )
        assert has_meta_merge
        assert has_obs_merge
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_writer.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.writer'`

- [ ] **Step 3: Implement writer**

Create `econ_pipeline/writer.py`:

```python
"""Snowflake writer with DDL management and idempotent MERGE upserts."""

from __future__ import annotations

import logging
import math
from datetime import date
from typing import Any, Protocol

from econ_pipeline.models import FetchResult, SeriesMetadata

logger = logging.getLogger(__name__)


class SnowflakeConnection(Protocol):
    """Protocol for a Snowflake-like connection (enables testing with fakes)."""

    def cursor(self) -> Any: ...
    def close(self) -> None: ...


class SnowflakeWriter:
    """Writes FetchResult data to Snowflake using MERGE for idempotent upserts.

    Usage:
        conn = snowflake.connector.connect(...)
        writer = SnowflakeWriter(conn, schema="econ")
        writer.ensure_tables()
        writer.write(fetch_result)
    """

    def __init__(
        self, conn: SnowflakeConnection, schema: str = "econ"
    ) -> None:
        self._conn = conn
        self._schema = schema

    @property
    def _meta_table(self) -> str:
        return f"{self._schema}.series_metadata"

    @property
    def _obs_table(self) -> str:
        return f"{self._schema}.observations"

    def ensure_tables(self) -> None:
        """Create the schema and tables if they do not exist."""
        cur = self._conn.cursor()
        try:
            cur.execute(f"CREATE SCHEMA IF NOT EXISTS {self._schema}")
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {self._meta_table} (
                    source        VARCHAR   NOT NULL,
                    series_id     VARCHAR   NOT NULL,
                    title         VARCHAR,
                    units         VARCHAR,
                    frequency     VARCHAR,
                    seasonal_adj  VARCHAR,
                    obs_start     DATE,
                    obs_end       DATE,
                    last_updated  TIMESTAMP_NTZ,
                    fetched_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
                    PRIMARY KEY (source, series_id)
                )
            """)
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {self._obs_table} (
                    source        VARCHAR   NOT NULL,
                    series_id     VARCHAR   NOT NULL,
                    obs_date      DATE      NOT NULL,
                    value         FLOAT,
                    PRIMARY KEY (source, series_id, obs_date)
                )
            """)
        finally:
            cur.close()

    def write_metadata(self, meta: SeriesMetadata) -> None:
        """Upsert series metadata using MERGE."""
        sql = f"""
            MERGE INTO {self._meta_table} AS tgt
            USING (SELECT
                %s AS source, %s AS series_id, %s AS title,
                %s AS units, %s AS frequency, %s AS seasonal_adj,
                %s AS obs_start, %s AS obs_end, %s AS last_updated
            ) AS src
            ON tgt.source = src.source AND tgt.series_id = src.series_id
            WHEN MATCHED THEN UPDATE SET
                title = src.title,
                units = src.units,
                frequency = src.frequency,
                seasonal_adj = src.seasonal_adj,
                obs_start = src.obs_start,
                obs_end = src.obs_end,
                last_updated = src.last_updated,
                fetched_at = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN INSERT (
                source, series_id, title, units, frequency,
                seasonal_adj, obs_start, obs_end, last_updated
            ) VALUES (
                src.source, src.series_id, src.title, src.units,
                src.frequency, src.seasonal_adj, src.obs_start,
                src.obs_end, src.last_updated
            )
        """
        cur = self._conn.cursor()
        try:
            cur.execute(
                sql,
                (
                    meta.source,
                    meta.series_id,
                    meta.title,
                    meta.units,
                    meta.frequency,
                    meta.seasonal_adj,
                    meta.obs_start,
                    meta.obs_end,
                    meta.last_updated,
                ),
            )
        finally:
            cur.close()

    def write_observations(self, result: FetchResult) -> None:
        """Upsert observations using per-row MERGE statements."""
        if result.is_empty:
            logger.info(
                "No observations to write for %s/%s",
                result.metadata.source,
                result.metadata.series_id,
            )
            return

        sql = f"""
            MERGE INTO {self._obs_table} AS tgt
            USING (SELECT %s AS source, %s AS series_id, %s AS obs_date, %s AS value) AS src
            ON tgt.source = src.source
               AND tgt.series_id = src.series_id
               AND tgt.obs_date = src.obs_date
            WHEN MATCHED THEN UPDATE SET value = src.value
            WHEN NOT MATCHED THEN INSERT (source, series_id, obs_date, value)
                VALUES (src.source, src.series_id, src.obs_date, src.value)
        """
        source = result.metadata.source
        series_id = result.metadata.series_id
        cur = self._conn.cursor()
        try:
            for _, row in result.observations.iterrows():
                value = None if (row["value"] is None or (isinstance(row["value"], float) and math.isnan(row["value"]))) else float(row["value"])
                cur.execute(sql, (source, series_id, row["obs_date"], value))
        finally:
            cur.close()

    def write(self, result: FetchResult) -> None:
        """Write both metadata and observations for a FetchResult."""
        self.write_metadata(result.metadata)
        self.write_observations(result)

    def get_last_obs_date(self, source: str, series_id: str) -> date | None:
        """Return the MAX(obs_date) for a given series, or None."""
        sql = f"""
            SELECT MAX(obs_date) FROM {self._obs_table}
            WHERE source = %s AND series_id = %s
        """
        cur = self._conn.cursor()
        try:
            cur.execute(sql, (source, series_id))
            row = cur.fetchone()
            if row and row[0]:
                return row[0]
            return None
        finally:
            cur.close()

    def get_since_map(self, source: str) -> dict[str, date]:
        """Return a mapping of series_id -> MAX(obs_date) for all series of a source."""
        sql = f"""
            SELECT series_id, MAX(obs_date)
            FROM {self._obs_table}
            WHERE source = %s
            GROUP BY series_id
        """
        cur = self._conn.cursor()
        try:
            cur.execute(sql, (source,))
            rows = cur.fetchall()
            return {row[0]: row[1] for row in rows if row[1] is not None}
        finally:
            cur.close()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_writer.py -v`
Expected: All 12 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/writer.py tests/test_writer.py
git commit -m "feat: add SnowflakeWriter with DDL, MERGE upserts, and incremental load support"
```

---

## Chunk 2: Adapters (Tasks t5-t7)

### Task 5: FRED Adapter

```yaml
- id: t5
  title: "Implement FredAdapter using fredapi"
  agent: developer
  depends_on: [t3]
  output: "econ_pipeline/adapters/fred.py, tests/test_fred_adapter.py"
  files: ["econ_pipeline/adapters/fred.py", "tests/test_fred_adapter.py"]
```

**Files:**
- Create: `econ_pipeline/adapters/fred.py`
- Create: `tests/test_fred_adapter.py`

- [ ] **Step 1: Write failing tests for FRED adapter**

Create `tests/test_fred_adapter.py`:

```python
"""Tests for econ_pipeline.adapters.fred.

Uses a FakeFred stub — no real HTTP calls.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any
from unittest.mock import patch

import pandas as pd
import pytest

from econ_pipeline.adapters.fred import FredAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig


class FakeFred:
    """Stub for fredapi.Fred that returns canned data."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key
        self._series_data: dict[str, pd.Series] = {}
        self._series_info: dict[str, pd.Series] = {}

    def set_series_data(self, series_id: str, data: pd.Series) -> None:
        self._series_data[series_id] = data

    def set_series_info(self, series_id: str, info: dict[str, Any]) -> None:
        self._series_info[series_id] = pd.Series(info)

    def get_series(
        self,
        series_id: str,
        observation_start: str | None = None,
        observation_end: str | None = None,
        **kwargs: Any,
    ) -> pd.Series:
        if series_id not in self._series_data:
            raise ValueError(f"Series not found: {series_id}")
        s = self._series_data[series_id]
        if observation_start:
            s = s[s.index >= pd.Timestamp(observation_start)]
        return s

    def get_series_info(self, series_id: str) -> pd.Series:
        if series_id not in self._series_info:
            return pd.Series(
                {
                    "title": series_id,
                    "units": "",
                    "frequency": "",
                    "seasonal_adjustment": "",
                    "observation_start": "2000-01-01",
                    "observation_end": "2024-01-01",
                    "last_updated": "2024-01-01 00:00:00-06",
                }
            )
        return self._series_info[series_id]


def _make_source_config(series_ids: list[str] | None = None) -> SourceConfig:
    if series_ids is None:
        series_ids = ["GDPC1"]
    return SourceConfig(
        name="fred",
        adapter="fred",
        series=[SeriesConfig(id=sid, title=sid) for sid in series_ids],
    )


class TestFredAdapter:
    """Tests for FredAdapter.fetch_series."""

    def test_fetch_returns_fetch_result(self) -> None:
        fake = FakeFred()
        fake.set_series_data(
            "GDPC1",
            pd.Series(
                [22000.0, 22100.0],
                index=pd.to_datetime(["2024-01-01", "2024-04-01"]),
                name="GDPC1",
            ),
        )
        fake.set_series_info(
            "GDPC1",
            {
                "title": "Real GDP",
                "units": "Billions of Chained 2017 Dollars",
                "frequency": "Quarterly",
                "seasonal_adjustment": "SAAR",
                "observation_start": "1947-01-01",
                "observation_end": "2024-04-01",
                "last_updated": "2024-06-27 07:46:02-05",
            },
        )
        cfg = _make_source_config(["GDPC1"])
        adapter = FredAdapter(cfg, fred_client=fake)
        result = adapter.fetch_series(cfg.series[0])

        assert result.metadata.source == "fred"
        assert result.metadata.series_id == "GDPC1"
        assert result.metadata.title == "Real GDP"
        assert result.metadata.units == "Billions of Chained 2017 Dollars"
        assert len(result.observations) == 2
        assert list(result.observations.columns) == ["obs_date", "value"]

    def test_fetch_coerces_missing_values_to_nan(self) -> None:
        """FRED returns '.' for missing values — adapter must coerce to NaN."""
        fake = FakeFred()
        # Simulate NaN (fredapi converts "." to NaN internally)
        fake.set_series_data(
            "UNRATE",
            pd.Series(
                [3.7, float("nan"), 3.9],
                index=pd.to_datetime(["2024-01-01", "2024-02-01", "2024-03-01"]),
                name="UNRATE",
            ),
        )
        cfg = _make_source_config(["UNRATE"])
        adapter = FredAdapter(cfg, fred_client=fake)
        result = adapter.fetch_series(cfg.series[0])

        assert len(result.observations) == 3
        assert pd.isna(result.observations.iloc[1]["value"])

    def test_fetch_with_since_parameter(self) -> None:
        fake = FakeFred()
        fake.set_series_data(
            "UNRATE",
            pd.Series(
                [3.5, 3.6, 3.7, 3.8],
                index=pd.to_datetime(
                    ["2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01"]
                ),
                name="UNRATE",
            ),
        )
        cfg = _make_source_config(["UNRATE"])
        adapter = FredAdapter(cfg, fred_client=fake)
        result = adapter.fetch_series(cfg.series[0], since=date(2024, 3, 1))

        # Should only include observations from 2024-03-01 onward
        assert len(result.observations) >= 2

    def test_fetch_empty_series(self) -> None:
        fake = FakeFred()
        fake.set_series_data(
            "EMPTY",
            pd.Series([], dtype=float, index=pd.DatetimeIndex([], name="date")),
        )
        cfg = _make_source_config(["EMPTY"])
        adapter = FredAdapter(cfg, fred_client=fake)
        result = adapter.fetch_series(cfg.series[0])
        assert result.is_empty

    @patch("econ_pipeline.adapters.fred.time.sleep")
    def test_fetch_respects_rate_limit(self, mock_sleep: Any) -> None:
        fake = FakeFred()
        fake.set_series_data(
            "A",
            pd.Series([1.0], index=pd.to_datetime(["2024-01-01"]), name="A"),
        )
        fake.set_series_data(
            "B",
            pd.Series([2.0], index=pd.to_datetime(["2024-01-01"]), name="B"),
        )
        cfg = _make_source_config(["A", "B"])
        adapter = FredAdapter(cfg, fred_client=fake)
        adapter.fetch_all()
        # sleep(0.5) should be called between fetches
        assert mock_sleep.call_count >= 1
        mock_sleep.assert_called_with(0.5)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_fred_adapter.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.adapters.fred'`

- [ ] **Step 3: Implement FRED adapter**

Create `econ_pipeline/adapters/fred.py`:

```python
"""FRED (Federal Reserve Economic Data) adapter using fredapi."""

from __future__ import annotations

import logging
import os
import time
from datetime import date, datetime
from typing import Any

import pandas as pd

from econ_pipeline.adapters.base import BaseAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig
from econ_pipeline.models import FetchResult, SeriesMetadata

logger = logging.getLogger(__name__)

# Rate limit: FRED allows 120 requests per 60 seconds.
# 0.5s sleep between calls keeps us well under the limit.
_RATE_LIMIT_SLEEP = 0.5


class FredAdapter(BaseAdapter):
    """Adapter for FRED data via the fredapi package.

    Env var: FRED_API_KEY must be set (or passed to fredapi.Fred directly).
    """

    def __init__(
        self,
        source_config: SourceConfig,
        fred_client: Any | None = None,
    ) -> None:
        super().__init__(source_config)
        if fred_client is not None:
            self._fred = fred_client
        else:
            from fredapi import Fred

            api_key = os.environ.get("FRED_API_KEY")
            if not api_key:
                raise ValueError(
                    "FRED_API_KEY environment variable must be set"
                )
            self._fred = Fred(api_key=api_key)

    def fetch_series(
        self, series_config: SeriesConfig, since: date | None = None
    ) -> FetchResult:
        """Fetch a FRED series.

        Args:
            series_config: Must have id set to a valid FRED series ID.
            since: If set, only observations after this date are fetched.

        Returns:
            FetchResult with metadata and observations DataFrame.
        """
        series_id = series_config.id
        logger.info("Fetching FRED series %s (since=%s)", series_id, since)

        # Fetch metadata
        info = self._fred.get_series_info(series_id)
        metadata = SeriesMetadata(
            source="fred",
            series_id=series_id,
            title=str(info.get("title", "")),
            units=str(info.get("units", "")),
            frequency=str(info.get("frequency", "")),
            seasonal_adj=str(info.get("seasonal_adjustment", "")),
            obs_start=_parse_date(info.get("observation_start")),
            obs_end=_parse_date(info.get("observation_end")),
            last_updated=_parse_datetime(info.get("last_updated")),
        )

        # Fetch observations
        kwargs: dict[str, Any] = {}
        if since is not None:
            kwargs["observation_start"] = since.isoformat()

        raw_series = self._fred.get_series(series_id, **kwargs)

        if raw_series is None or raw_series.empty:
            df = pd.DataFrame(columns=["obs_date", "value"])
        else:
            df = pd.DataFrame(
                {
                    "obs_date": raw_series.index.date,
                    "value": pd.to_numeric(raw_series.values, errors="coerce"),
                }
            )

        return FetchResult(metadata=metadata, observations=df)

    def fetch_all(
        self, since_map: dict[str, date] | None = None
    ) -> list[FetchResult]:
        """Fetch all configured FRED series with rate limiting."""
        if since_map is None:
            since_map = {}

        results: list[FetchResult] = []
        for i, series_cfg in enumerate(self.source_config.series):
            if i > 0:
                time.sleep(_RATE_LIMIT_SLEEP)
            since = since_map.get(series_cfg.id)
            try:
                result = self.fetch_series(series_cfg, since=since)
                results.append(result)
            except Exception as exc:
                logger.warning(
                    "Failed to fetch fred/%s: %s", series_cfg.id, exc
                )
        return results


def _parse_date(val: Any) -> date | None:
    """Parse a date string like '2024-01-01', returning None on failure."""
    if val is None:
        return None
    try:
        return pd.Timestamp(str(val)).date()
    except (ValueError, TypeError):
        return None


def _parse_datetime(val: Any) -> datetime | None:
    """Parse a datetime string, returning None on failure."""
    if val is None:
        return None
    try:
        return pd.Timestamp(str(val)).to_pydatetime().replace(tzinfo=None)
    except (ValueError, TypeError):
        return None
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_fred_adapter.py -v`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/adapters/fred.py tests/test_fred_adapter.py
git commit -m "feat: add FredAdapter with rate limiting and NaN coercion"
```

---

### Task 6: SDMX Adapter

```yaml
- id: t6
  title: "Implement SdmxAdapter for ECB, Eurostat, Bundesbank, OECD, BIS"
  agent: developer
  depends_on: [t3]
  output: "econ_pipeline/adapters/sdmx.py, tests/test_sdmx_adapter.py"
  files: ["econ_pipeline/adapters/sdmx.py", "tests/test_sdmx_adapter.py"]
```

**Files:**
- Create: `econ_pipeline/adapters/sdmx.py`
- Create: `tests/test_sdmx_adapter.py`

- [ ] **Step 1: Write failing tests for SDMX adapter**

Create `tests/test_sdmx_adapter.py`:

```python
"""Tests for econ_pipeline.adapters.sdmx.

Uses a FakeSdmxClient stub — no real HTTP calls.
"""

from __future__ import annotations

from datetime import date
from typing import Any
from unittest.mock import MagicMock

import pandas as pd
import pytest

from econ_pipeline.adapters.sdmx import SdmxAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig


class FakeSdmxMessage:
    """Stub for an sdmx1 DataMessage."""

    def __init__(self, df: pd.DataFrame) -> None:
        self._df = df

    def to_pandas(self) -> pd.DataFrame:
        """Mimic sdmx.to_pandas(message) — called externally."""
        return self._df


class FakeSdmxClient:
    """Stub for sdmx.Client that returns canned data."""

    def __init__(self, source: str) -> None:
        self.source = source
        self._responses: dict[str, pd.DataFrame] = {}

    def set_response(self, flow_ref: str, df: pd.DataFrame) -> None:
        self._responses[flow_ref] = df

    def data(
        self, flow_ref: str, key: dict[str, str] | str = "", params: dict[str, str] | None = None
    ) -> FakeSdmxMessage:
        if flow_ref not in self._responses:
            raise ValueError(f"No data for flow_ref: {flow_ref}")
        return FakeSdmxMessage(self._responses[flow_ref])


def _make_ecb_config() -> SourceConfig:
    return SourceConfig(
        name="ecb",
        adapter="sdmx",
        provider="ECB",
        series=[
            SeriesConfig(
                id="EXR.D.USD.EUR.SP00.A",
                title="EUR/USD Daily",
                extra={"flow_ref": "EXR", "key": "D.USD.EUR.SP00.A"},
            ),
        ],
    )


def _make_oecd_config() -> SourceConfig:
    return SourceConfig(
        name="oecd",
        adapter="sdmx",
        provider="OECD",
        series=[
            SeriesConfig(
                id="QNA.DEU.B1_GE.GPSA.Q",
                title="German GDP",
                extra={"flow_ref": "QNA", "key": "DEU.B1_GE.GPSA.Q"},
            ),
        ],
    )


def _make_timeseries_df(
    dates: list[str], values: list[float]
) -> pd.DataFrame:
    """Create a DataFrame mimicking sdmx.to_pandas output.

    sdmx1 typically returns a Series with a PeriodIndex or MultiIndex.
    For testing we use a simple DataFrame structure that the adapter
    will normalize.
    """
    idx = pd.PeriodIndex(dates, freq="D")
    return pd.DataFrame({"value": values}, index=idx)


class TestSdmxAdapter:
    """Tests for SdmxAdapter.fetch_series."""

    def test_fetch_returns_fetch_result(self) -> None:
        fake_client = FakeSdmxClient("ECB")
        fake_client.set_response(
            "EXR",
            _make_timeseries_df(
                ["2024-01-02", "2024-01-03"], [1.0950, 1.0980]
            ),
        )
        cfg = _make_ecb_config()
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        result = adapter.fetch_series(cfg.series[0])

        assert result.metadata.source == "ecb"
        assert result.metadata.series_id == "EXR.D.USD.EUR.SP00.A"
        assert len(result.observations) == 2
        assert list(result.observations.columns) == ["obs_date", "value"]

    def test_fetch_with_different_provider(self) -> None:
        fake_client = FakeSdmxClient("OECD")
        fake_client.set_response(
            "QNA",
            _make_timeseries_df(["2024-01", "2024-04"], [50000.0, 51000.0]),
        )
        cfg = _make_oecd_config()
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        result = adapter.fetch_series(cfg.series[0])

        assert result.metadata.source == "oecd"
        assert len(result.observations) == 2

    def test_fetch_with_since_parameter(self) -> None:
        fake_client = FakeSdmxClient("ECB")
        fake_client.set_response(
            "EXR",
            _make_timeseries_df(
                ["2024-01-02", "2024-01-03", "2024-02-01", "2024-03-01"],
                [1.09, 1.10, 1.11, 1.12],
            ),
        )
        cfg = _make_ecb_config()
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        result = adapter.fetch_series(cfg.series[0], since=date(2024, 2, 1))

        # Should filter to observations on or after 2024-02-01
        assert len(result.observations) >= 2
        earliest = result.observations["obs_date"].min()
        assert earliest >= date(2024, 2, 1)

    def test_fetch_empty_response(self) -> None:
        fake_client = FakeSdmxClient("ECB")
        fake_client.set_response(
            "EXR",
            pd.DataFrame({"value": []}, index=pd.PeriodIndex([], freq="D")),
        )
        cfg = _make_ecb_config()
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        result = adapter.fetch_series(cfg.series[0])
        assert result.is_empty

    def test_fetch_missing_flow_ref_raises(self) -> None:
        cfg = SourceConfig(
            name="ecb",
            adapter="sdmx",
            provider="ECB",
            series=[
                SeriesConfig(
                    id="BAD",
                    title="Bad",
                    extra={"key": "something"},
                    # missing flow_ref
                ),
            ],
        )
        fake_client = FakeSdmxClient("ECB")
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        with pytest.raises(ValueError, match="flow_ref"):
            adapter.fetch_series(cfg.series[0])

    def test_fetch_missing_key_raises(self) -> None:
        cfg = SourceConfig(
            name="ecb",
            adapter="sdmx",
            provider="ECB",
            series=[
                SeriesConfig(
                    id="BAD",
                    title="Bad",
                    extra={"flow_ref": "EXR"},
                    # missing key
                ),
            ],
        )
        fake_client = FakeSdmxClient("ECB")
        adapter = SdmxAdapter(cfg, sdmx_client=fake_client)
        with pytest.raises(ValueError, match="key"):
            adapter.fetch_series(cfg.series[0])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_sdmx_adapter.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.adapters.sdmx'`

- [ ] **Step 3: Implement SDMX adapter**

Create `econ_pipeline/adapters/sdmx.py`:

```python
"""SDMX adapter for ECB, Eurostat, Bundesbank, OECD, and BIS.

All five sources expose SDMX REST APIs. This adapter uses sdmx1 (pandaSDMX)
to fetch data. The source-specific differences (provider name, key format)
are driven by config — no source-specific code needed.
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any

import pandas as pd

from econ_pipeline.adapters.base import BaseAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig
from econ_pipeline.models import FetchResult, SeriesMetadata

logger = logging.getLogger(__name__)

# Mapping from our config provider names to sdmx1 source identifiers.
_PROVIDER_MAP: dict[str, str] = {
    "ECB": "ECB",
    "ESTAT": "ESTAT",
    "EUROSTAT": "ESTAT",
    "BBK": "BBK",
    "BUNDESBANK": "BBK",
    "OECD": "OECD",
    "BIS": "BIS",
}


class SdmxAdapter(BaseAdapter):
    """Adapter for SDMX-based data sources.

    Supports: ECB, Eurostat, Bundesbank, OECD, BIS.
    No authentication required for any of these sources.

    Config requirements per series:
        extra.flow_ref: The SDMX dataflow reference (e.g., "EXR", "QNA")
        extra.key: The SDMX key string (e.g., "D.USD.EUR.SP00.A")
    """

    def __init__(
        self,
        source_config: SourceConfig,
        sdmx_client: Any | None = None,
    ) -> None:
        super().__init__(source_config)
        if sdmx_client is not None:
            self._client = sdmx_client
        else:
            import sdmx

            provider = source_config.provider or source_config.name.upper()
            sdmx_source = _PROVIDER_MAP.get(provider.upper(), provider)
            self._client = sdmx.Client(sdmx_source)

    def fetch_series(
        self, series_config: SeriesConfig, since: date | None = None
    ) -> FetchResult:
        """Fetch a single SDMX series.

        Args:
            series_config: Must have extra["flow_ref"] and extra["key"].
            since: If set, only observations on or after this date are returned.
        """
        flow_ref = series_config.extra.get("flow_ref")
        key = series_config.extra.get("key")

        if not flow_ref:
            raise ValueError(
                f"Series {series_config.id} missing required 'flow_ref' in config extra"
            )
        if not key:
            raise ValueError(
                f"Series {series_config.id} missing required 'key' in config extra"
            )

        logger.info(
            "Fetching SDMX %s/%s (flow=%s, key=%s, since=%s)",
            self.source_name,
            series_config.id,
            flow_ref,
            key,
            since,
        )

        params: dict[str, str] = {}
        if since is not None:
            params["startPeriod"] = since.isoformat()

        message = self._client.data(flow_ref, key=key, params=params if params else None)

        # Convert to DataFrame
        if hasattr(message, "to_pandas"):
            raw_df = message.to_pandas()
        else:
            import sdmx

            raw_df = sdmx.to_pandas(message)

        # Normalize to our standard format: obs_date, value
        df = self._normalize_dataframe(raw_df, since)

        metadata = SeriesMetadata(
            source=self.source_name,
            series_id=series_config.id,
            title=series_config.title,
        )

        return FetchResult(metadata=metadata, observations=df)

    def _normalize_dataframe(
        self, raw_df: pd.DataFrame | pd.Series, since: date | None = None
    ) -> pd.DataFrame:
        """Normalize sdmx1 output to a DataFrame with obs_date and value columns."""
        if isinstance(raw_df, pd.Series):
            raw_df = raw_df.to_frame(name="value")

        if raw_df.empty:
            return pd.DataFrame(columns=["obs_date", "value"])

        # The index from sdmx1 is usually a PeriodIndex or MultiIndex.
        # Convert to dates.
        if isinstance(raw_df.index, pd.PeriodIndex):
            dates = raw_df.index.to_timestamp().date
        elif isinstance(raw_df.index, pd.DatetimeIndex):
            dates = raw_df.index.date
        else:
            # MultiIndex or other — try to extract the time dimension
            try:
                dates = pd.PeriodIndex(raw_df.index.get_level_values(-1)).to_timestamp().date
            except Exception:
                dates = [date(2000, 1, 1)] * len(raw_df)
                logger.warning("Could not parse index dates, defaulting")

        # Get the value column
        if "value" in raw_df.columns:
            values = pd.to_numeric(raw_df["value"], errors="coerce")
        elif len(raw_df.columns) == 1:
            values = pd.to_numeric(raw_df.iloc[:, 0], errors="coerce")
        else:
            values = pd.to_numeric(raw_df.iloc[:, 0], errors="coerce")

        df = pd.DataFrame({"obs_date": dates, "value": values.values})

        # Apply since filter (in case the API didn't fully filter)
        if since is not None:
            df = df[df["obs_date"] >= since].reset_index(drop=True)

        return df
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_sdmx_adapter.py -v`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/adapters/sdmx.py tests/test_sdmx_adapter.py
git commit -m "feat: add SdmxAdapter for ECB, Eurostat, Bundesbank, OECD, BIS"
```

---

### Task 7: Destatis Adapter

```yaml
- id: t7
  title: "Implement DestatisAdapter using wiesbaden package"
  agent: developer
  depends_on: [t3]
  output: "econ_pipeline/adapters/destatis.py, tests/test_destatis_adapter.py"
  files: ["econ_pipeline/adapters/destatis.py", "tests/test_destatis_adapter.py"]
```

**Files:**
- Create: `econ_pipeline/adapters/destatis.py`
- Create: `tests/test_destatis_adapter.py`

- [ ] **Step 1: Write failing tests for Destatis adapter**

Create `tests/test_destatis_adapter.py`:

```python
"""Tests for econ_pipeline.adapters.destatis.

Uses monkeypatching to replace wiesbaden.retrieve_data — no real HTTP calls.
"""

from __future__ import annotations

from datetime import date
from typing import Any
from unittest.mock import patch

import pandas as pd
import pytest

from econ_pipeline.adapters.destatis import DestatisAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig


def _make_destatis_config() -> SourceConfig:
    return SourceConfig(
        name="destatis",
        adapter="destatis",
        series=[
            SeriesConfig(
                id="61111-0001",
                title="German CPI",
                extra={"table_code": "61111-0001"},
            ),
        ],
    )


def _make_cpi_dataframe() -> pd.DataFrame:
    """Simulate wiesbaden.retrieve_data output for CPI.

    wiesbaden returns a DataFrame with columns like:
    time, value, plus various dimension columns.
    """
    return pd.DataFrame(
        {
            "time": ["2024-01", "2024-02", "2024-03"],
            "val1": ["118.5", "119.1", "119.8"],
        }
    )


def _make_empty_dataframe() -> pd.DataFrame:
    return pd.DataFrame(columns=["time", "val1"])


class TestDestatisAdapter:
    """Tests for DestatisAdapter.fetch_series."""

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_returns_fetch_result(
        self, mock_retrieve: Any
    ) -> None:
        mock_retrieve.return_value = _make_cpi_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        result = adapter.fetch_series(cfg.series[0])

        assert result.metadata.source == "destatis"
        assert result.metadata.series_id == "61111-0001"
        assert result.metadata.title == "German CPI"
        assert len(result.observations) == 3
        assert list(result.observations.columns) == ["obs_date", "value"]

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_converts_time_to_dates(
        self, mock_retrieve: Any
    ) -> None:
        mock_retrieve.return_value = _make_cpi_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        result = adapter.fetch_series(cfg.series[0])

        first_date = result.observations.iloc[0]["obs_date"]
        assert isinstance(first_date, date)
        assert first_date == date(2024, 1, 1)

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_coerces_values_to_float(
        self, mock_retrieve: Any
    ) -> None:
        mock_retrieve.return_value = _make_cpi_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        result = adapter.fetch_series(cfg.series[0])

        assert result.observations.iloc[0]["value"] == pytest.approx(118.5)

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_with_since_filters(
        self, mock_retrieve: Any
    ) -> None:
        mock_retrieve.return_value = _make_cpi_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        result = adapter.fetch_series(cfg.series[0], since=date(2024, 2, 1))

        assert len(result.observations) == 2
        assert result.observations.iloc[0]["obs_date"] >= date(2024, 2, 1)

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_empty_result(self, mock_retrieve: Any) -> None:
        mock_retrieve.return_value = _make_empty_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        result = adapter.fetch_series(cfg.series[0])
        assert result.is_empty

    @patch("econ_pipeline.adapters.destatis.retrieve_data")
    def test_fetch_passes_table_code_to_wiesbaden(
        self, mock_retrieve: Any
    ) -> None:
        mock_retrieve.return_value = _make_cpi_dataframe()
        cfg = _make_destatis_config()
        adapter = DestatisAdapter(cfg)
        adapter.fetch_series(cfg.series[0])

        mock_retrieve.assert_called_once()
        call_kwargs = mock_retrieve.call_args
        assert call_kwargs[1]["tablename"] == "61111-0001"

    def test_missing_table_code_raises(self) -> None:
        cfg = SourceConfig(
            name="destatis",
            adapter="destatis",
            series=[
                SeriesConfig(id="BAD", title="Bad", extra={}),
            ],
        )
        adapter = DestatisAdapter(cfg)
        with pytest.raises(ValueError, match="table_code"):
            adapter.fetch_series(cfg.series[0])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_destatis_adapter.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.adapters.destatis'`

- [ ] **Step 3: Implement Destatis adapter**

Create `econ_pipeline/adapters/destatis.py`:

```python
"""Destatis (German Federal Statistical Office) adapter using the wiesbaden package.

Destatis exposes the GENESIS REST API. The wiesbaden package wraps it.
Default credentials: GUEST/GUEST (sufficient for public data).
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any

import pandas as pd
from wiesbaden import retrieve_data

from econ_pipeline.adapters.base import BaseAdapter
from econ_pipeline.config import SeriesConfig, SourceConfig
from econ_pipeline.models import FetchResult, SeriesMetadata

logger = logging.getLogger(__name__)

_DATENBANK = "destatis"


class DestatisAdapter(BaseAdapter):
    """Adapter for Destatis GENESIS data via wiesbaden.

    Config requirements per series:
        extra.table_code: The Destatis table code (e.g., "61111-0001")
    """

    def __init__(self, source_config: SourceConfig) -> None:
        super().__init__(source_config)

    def fetch_series(
        self, series_config: SeriesConfig, since: date | None = None
    ) -> FetchResult:
        """Fetch a Destatis table.

        Args:
            series_config: Must have extra["table_code"] set.
            since: If set, observations before this date are filtered out.
        """
        table_code = series_config.extra.get("table_code")
        if not table_code:
            raise ValueError(
                f"Series {series_config.id} missing required 'table_code' in config extra"
            )

        logger.info(
            "Fetching Destatis table %s (since=%s)", table_code, since
        )

        raw_df = retrieve_data(tablename=table_code, datenbank=_DATENBANK)

        df = self._normalize_dataframe(raw_df, since)

        metadata = SeriesMetadata(
            source="destatis",
            series_id=series_config.id,
            title=series_config.title,
        )

        return FetchResult(metadata=metadata, observations=df)

    def _normalize_dataframe(
        self, raw_df: pd.DataFrame, since: date | None = None
    ) -> pd.DataFrame:
        """Normalize wiesbaden output to obs_date + value columns.

        wiesbaden returns a DataFrame with a 'time' column (string like
        '2024-01' or '2024') and one or more value columns (val1, val2, ...).
        We take the first value column.
        """
        if raw_df.empty or "time" not in raw_df.columns:
            return pd.DataFrame(columns=["obs_date", "value"])

        # Find the value column — wiesbaden uses val1, val2, etc.
        value_cols = [c for c in raw_df.columns if c.startswith("val")]
        if not value_cols:
            return pd.DataFrame(columns=["obs_date", "value"])

        value_col = value_cols[0]

        # Parse time strings to dates
        dates = pd.to_datetime(raw_df["time"], format="mixed", dayfirst=False)
        values = pd.to_numeric(raw_df[value_col], errors="coerce")

        df = pd.DataFrame(
            {"obs_date": dates.dt.date, "value": values.values}
        )

        # Filter by since
        if since is not None:
            df = df[df["obs_date"] >= since].reset_index(drop=True)

        return df
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_destatis_adapter.py -v`
Expected: All 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/adapters/destatis.py tests/test_destatis_adapter.py
git commit -m "feat: add DestatisAdapter using wiesbaden for GENESIS API"
```

---

## Chunk 3: Orchestration (Tasks t8-t10)

### Task 8: Pipeline Orchestrator

```yaml
- id: t8
  title: "Implement Pipeline orchestrator wiring config to adapters to writer"
  agent: developer
  depends_on: [t2, t4, t5, t6, t7]
  output: "econ_pipeline/pipeline.py, tests/test_pipeline.py"
  files: ["econ_pipeline/pipeline.py", "tests/test_pipeline.py"]
```

**Files:**
- Create: `econ_pipeline/pipeline.py`
- Create: `tests/test_pipeline.py`

- [ ] **Step 1: Write failing tests for pipeline orchestrator**

Create `tests/test_pipeline.py`:

```python
"""Tests for econ_pipeline.pipeline.

Uses fake adapters and a fake writer — no real API or Snowflake calls.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

import pandas as pd
import pytest

from econ_pipeline.adapters.base import BaseAdapter
from econ_pipeline.config import PipelineConfig, SeriesConfig, SourceConfig
from econ_pipeline.models import FetchResult, SeriesMetadata
from econ_pipeline.pipeline import Pipeline


class FakeAdapter(BaseAdapter):
    """Fake adapter that returns canned results."""

    def __init__(
        self,
        source_config: SourceConfig,
        results: list[FetchResult] | None = None,
    ) -> None:
        super().__init__(source_config)
        self._results = results or []

    def fetch_series(
        self, series_config: SeriesConfig, since: date | None = None
    ) -> FetchResult:
        for r in self._results:
            if r.metadata.series_id == series_config.id:
                return r
        return FetchResult(
            metadata=SeriesMetadata(
                source=self.source_name, series_id=series_config.id
            ),
            observations=pd.DataFrame(columns=["obs_date", "value"]),
        )


class FakeWriter:
    """Fake writer that records what was written."""

    def __init__(self) -> None:
        self.written: list[FetchResult] = []
        self.tables_ensured = False
        self._since_maps: dict[str, dict[str, date]] = {}

    def ensure_tables(self) -> None:
        self.tables_ensured = True

    def write(self, result: FetchResult) -> None:
        self.written.append(result)

    def get_since_map(self, source: str) -> dict[str, date]:
        return self._since_maps.get(source, {})

    def set_since_map(self, source: str, since_map: dict[str, date]) -> None:
        self._since_maps[source] = since_map


def _make_result(
    source: str, series_id: str, n_obs: int = 2
) -> FetchResult:
    meta = SeriesMetadata(source=source, series_id=series_id, title=series_id)
    dates = [date(2024, i + 1, 1) for i in range(n_obs)]
    values = [float(i + 100) for i in range(n_obs)]
    df = pd.DataFrame({"obs_date": dates, "value": values})
    return FetchResult(metadata=meta, observations=df)


def _make_config() -> PipelineConfig:
    return PipelineConfig(
        sources=[
            SourceConfig(
                name="fred",
                adapter="fred",
                series=[
                    SeriesConfig(id="GDPC1", title="Real GDP"),
                    SeriesConfig(id="UNRATE", title="Unemployment"),
                ],
            ),
            SourceConfig(
                name="ecb",
                adapter="sdmx",
                provider="ECB",
                series=[
                    SeriesConfig(
                        id="EXR.D.USD.EUR.SP00.A",
                        title="EUR/USD",
                        extra={"flow_ref": "EXR", "key": "D.USD.EUR.SP00.A"},
                    ),
                ],
            ),
        ]
    )


class TestPipeline:
    """Tests for Pipeline orchestration."""

    def test_run_ensures_tables(self) -> None:
        config = _make_config()
        writer = FakeWriter()
        adapters = {
            "fred": FakeAdapter(config.sources[0]),
            "ecb": FakeAdapter(config.sources[1]),
        }
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()
        assert writer.tables_ensured

    def test_run_writes_results_for_all_sources(self) -> None:
        config = _make_config()
        writer = FakeWriter()
        fred_results = [
            _make_result("fred", "GDPC1"),
            _make_result("fred", "UNRATE"),
        ]
        ecb_results = [
            _make_result("ecb", "EXR.D.USD.EUR.SP00.A"),
        ]
        adapters = {
            "fred": FakeAdapter(config.sources[0], fred_results),
            "ecb": FakeAdapter(config.sources[1], ecb_results),
        }
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()

        written_ids = {r.metadata.series_id for r in writer.written}
        assert written_ids == {"GDPC1", "UNRATE", "EXR.D.USD.EUR.SP00.A"}

    def test_run_uses_since_map_for_incremental(self) -> None:
        config = _make_config()
        writer = FakeWriter()
        writer.set_since_map("fred", {"GDPC1": date(2024, 6, 1)})

        fetch_calls: list[tuple[str, date | None]] = []

        class TrackingAdapter(FakeAdapter):
            def fetch_series(
                self, series_config: SeriesConfig, since: date | None = None
            ) -> FetchResult:
                fetch_calls.append((series_config.id, since))
                return super().fetch_series(series_config, since)

        adapters = {
            "fred": TrackingAdapter(config.sources[0]),
            "ecb": FakeAdapter(config.sources[1]),
        }
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()

        # GDPC1 should have been called with since=2024-06-01
        gdpc1_call = next(c for c in fetch_calls if c[0] == "GDPC1")
        assert gdpc1_call[1] == date(2024, 6, 1)

        # UNRATE should have been called with since=None (not in since_map)
        unrate_call = next(c for c in fetch_calls if c[0] == "UNRATE")
        assert unrate_call[1] is None

    def test_run_skips_empty_results(self) -> None:
        config = _make_config()
        writer = FakeWriter()
        # FakeAdapter returns empty results by default
        adapters = {
            "fred": FakeAdapter(config.sources[0]),
            "ecb": FakeAdapter(config.sources[1]),
        }
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()
        # Empty results should still be written (metadata is still useful)
        # but we verify no crash occurs
        assert writer.tables_ensured

    def test_run_continues_on_adapter_error(self) -> None:
        config = _make_config()
        writer = FakeWriter()

        class FailingAdapter(BaseAdapter):
            def fetch_series(
                self, series_config: SeriesConfig, since: date | None = None
            ) -> FetchResult:
                raise ConnectionError("API down")

        ecb_results = [_make_result("ecb", "EXR.D.USD.EUR.SP00.A")]
        adapters = {
            "fred": FailingAdapter(config.sources[0]),
            "ecb": FakeAdapter(config.sources[1], ecb_results),
        }
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()

        # ECB results should still be written despite FRED failing
        written_ids = {r.metadata.series_id for r in writer.written}
        assert "EXR.D.USD.EUR.SP00.A" in written_ids

    def test_create_adapters_factory(self) -> None:
        """Test the static adapter factory method."""
        config = _make_config()
        adapters = Pipeline.create_adapters(config)
        assert "fred" in adapters
        assert "ecb" in adapters
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_pipeline.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'econ_pipeline.pipeline'`

- [ ] **Step 3: Implement pipeline orchestrator**

Create `econ_pipeline/pipeline.py`:

```python
"""Pipeline orchestrator: config -> adapters -> writer."""

from __future__ import annotations

import logging
from typing import Any

from econ_pipeline.adapters.base import BaseAdapter
from econ_pipeline.config import PipelineConfig, SourceConfig
from econ_pipeline.models import FetchResult

logger = logging.getLogger(__name__)


class Pipeline:
    """Orchestrates fetching from all configured sources and writing to Snowflake.

    Usage:
        config = PipelineConfig.from_yaml("config/series.yaml")
        conn = snowflake.connector.connect(...)
        writer = SnowflakeWriter(conn)
        adapters = Pipeline.create_adapters(config)
        pipeline = Pipeline(config, writer, adapters)
        pipeline.run()
    """

    def __init__(
        self,
        config: PipelineConfig,
        writer: Any,
        adapters: dict[str, BaseAdapter],
    ) -> None:
        self._config = config
        self._writer = writer
        self._adapters = adapters

    def run(self) -> None:
        """Execute the full pipeline: ensure tables, fetch all, write all."""
        self._writer.ensure_tables()

        for source_config in self._config.sources:
            source_name = source_config.name
            adapter = self._adapters.get(source_name)
            if adapter is None:
                logger.warning(
                    "No adapter registered for source '%s', skipping",
                    source_name,
                )
                continue

            logger.info("Processing source: %s", source_name)

            # Get incremental state
            since_map = self._writer.get_since_map(source_name)

            # Fetch all series for this source
            results = adapter.fetch_all(since_map=since_map)

            # Write results
            for result in results:
                try:
                    self._writer.write(result)
                    logger.info(
                        "Wrote %s/%s: %d observations",
                        result.metadata.source,
                        result.metadata.series_id,
                        len(result.observations),
                    )
                except Exception as exc:
                    logger.error(
                        "Failed to write %s/%s: %s",
                        result.metadata.source,
                        result.metadata.series_id,
                        exc,
                    )

    @staticmethod
    def create_adapters(config: PipelineConfig) -> dict[str, BaseAdapter]:
        """Create adapter instances for all configured sources.

        Maps the adapter name from config to the appropriate class:
            "fred" -> FredAdapter
            "sdmx" -> SdmxAdapter
            "destatis" -> DestatisAdapter

        Returns:
            Dict mapping source name to adapter instance.
        """
        from econ_pipeline.adapters.destatis import DestatisAdapter
        from econ_pipeline.adapters.fred import FredAdapter
        from econ_pipeline.adapters.sdmx import SdmxAdapter

        adapter_classes: dict[str, type[BaseAdapter]] = {
            "fred": FredAdapter,
            "sdmx": SdmxAdapter,
            "destatis": DestatisAdapter,
        }

        adapters: dict[str, BaseAdapter] = {}
        for source_config in config.sources:
            adapter_type = source_config.adapter
            cls = adapter_classes.get(adapter_type)
            if cls is None:
                logger.warning(
                    "Unknown adapter type '%s' for source '%s'",
                    adapter_type,
                    source_config.name,
                )
                continue
            try:
                adapters[source_config.name] = cls(source_config)
            except Exception as exc:
                logger.error(
                    "Failed to create adapter for '%s': %s",
                    source_config.name,
                    exc,
                )

        return adapters
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_pipeline.py -v`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add econ_pipeline/pipeline.py tests/test_pipeline.py
git commit -m "feat: add Pipeline orchestrator with incremental load and error resilience"
```

---

### Task 9: CLI Entry Point and Example Config

```yaml
- id: t9
  title: "Create CLI entry point, __main__.py, and example series.yaml"
  agent: developer
  depends_on: [t8]
  output: "econ_pipeline/cli.py, econ_pipeline/__main__.py, config/series.yaml"
  files: ["econ_pipeline/cli.py", "econ_pipeline/__main__.py", "config/series.yaml"]
```

**Files:**
- Create: `econ_pipeline/cli.py`
- Create: `econ_pipeline/__main__.py`
- Create: `config/series.yaml`

- [ ] **Step 1: Create CLI module**

Create `econ_pipeline/cli.py`:

```python
"""CLI entry point for the economic data pipeline.

Usage:
    python -m econ_pipeline --config config/series.yaml

All secrets via environment variables:
    FRED_API_KEY          - FRED API key
    SNOWFLAKE_ACCOUNT     - Snowflake account identifier
    SNOWFLAKE_USER        - Snowflake username
    SNOWFLAKE_PASSWORD    - Snowflake password
    SNOWFLAKE_DATABASE    - Snowflake database name
    SNOWFLAKE_WAREHOUSE   - Snowflake warehouse name
    SNOWFLAKE_SCHEMA      - Snowflake schema (default: econ)
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path


def main(argv: list[str] | None = None) -> int:
    """Run the economic data pipeline.

    Returns:
        0 on success, 1 on failure.
    """
    parser = argparse.ArgumentParser(
        prog="econ-pipeline",
        description="Ingest economic time series into Snowflake.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config/series.yaml"),
        help="Path to the series configuration YAML file (default: config/series.yaml)",
    )
    parser.add_argument(
        "--schema",
        type=str,
        default=os.environ.get("SNOWFLAKE_SCHEMA", "econ"),
        help="Snowflake schema name (default: econ)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Load config and create adapters but do not fetch or write.",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose (DEBUG) logging.",
    )
    args = parser.parse_args(argv)

    # Configure logging
    level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    logger = logging.getLogger("econ_pipeline")

    try:
        # Load config
        from econ_pipeline.config import PipelineConfig

        logger.info("Loading config from %s", args.config)
        config = PipelineConfig.from_yaml(args.config)
        logger.info(
            "Loaded %d sources with %d total series",
            len(config.sources),
            sum(len(s.series) for s in config.sources),
        )

        if args.dry_run:
            logger.info("Dry run — creating adapters only, no fetch/write.")
            from econ_pipeline.pipeline import Pipeline

            adapters = Pipeline.create_adapters(config)
            logger.info("Created adapters: %s", list(adapters.keys()))
            logger.info("Dry run complete.")
            return 0

        # Connect to Snowflake
        import snowflake.connector

        sf_conn = snowflake.connector.connect(
            account=os.environ["SNOWFLAKE_ACCOUNT"],
            user=os.environ["SNOWFLAKE_USER"],
            password=os.environ["SNOWFLAKE_PASSWORD"],
            database=os.environ["SNOWFLAKE_DATABASE"],
            warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        )

        try:
            from econ_pipeline.pipeline import Pipeline
            from econ_pipeline.writer import SnowflakeWriter

            writer = SnowflakeWriter(sf_conn, schema=args.schema)
            adapters = Pipeline.create_adapters(config)
            pipeline = Pipeline(config, writer, adapters)

            logger.info("Starting pipeline run...")
            pipeline.run()
            logger.info("Pipeline run complete.")
        finally:
            sf_conn.close()

        return 0

    except FileNotFoundError as exc:
        logger.error("Config file not found: %s", exc)
        return 1
    except KeyError as exc:
        logger.error("Missing environment variable: %s", exc)
        return 1
    except Exception as exc:
        logger.error("Pipeline failed: %s", exc, exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Create __main__.py**

Create `econ_pipeline/__main__.py`:

```python
"""Support for `python -m econ_pipeline`."""

from econ_pipeline.cli import main

raise SystemExit(main())
```

- [ ] **Step 3: Create example config**

Create `config/series.yaml`:

```yaml
# Economic Data Pipeline — Series Configuration
#
# Each source maps to an adapter type. Series listed here will be
# fetched and written to Snowflake on each pipeline run.
#
# Secrets are NOT stored here — use environment variables:
#   FRED_API_KEY, SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, etc.

sources:
  # ---------- FRED (Federal Reserve Economic Data) ----------
  fred:
    adapter: fred
    series:
      - id: GDPC1
        title: Real Gross Domestic Product
      - id: UNRATE
        title: Civilian Unemployment Rate
      - id: CPIAUCSL
        title: CPI All Urban Consumers
      - id: FEDFUNDS
        title: Effective Federal Funds Rate
      - id: GS10
        title: 10-Year Treasury Constant Maturity Rate
      - id: T10Y2Y
        title: 10Y-2Y Treasury Spread
      - id: PAYEMS
        title: Total Nonfarm Payrolls

  # ---------- ECB Statistical Data Warehouse ----------
  ecb:
    adapter: sdmx
    provider: ECB
    series:
      - id: EXR.D.USD.EUR.SP00.A
        title: EUR/USD Exchange Rate (Daily)
        flow_ref: EXR
        key: D.USD.EUR.SP00.A
      - id: FM.M.U2.EUR.4F.KR.MRR_FR.LEV
        title: ECB Main Refinancing Rate
        flow_ref: FM
        key: M.U2.EUR.4F.KR.MRR_FR.LEV

  # ---------- Eurostat ----------
  eurostat:
    adapter: sdmx
    provider: ESTAT
    series:
      - id: prc_hicp_manr.DE.CP00
        title: HICP Annual Rate of Change — Germany
        flow_ref: prc_hicp_manr
        key: M.RCH_A.CP00.DE

  # ---------- Deutsche Bundesbank ----------
  bundesbank:
    adapter: sdmx
    provider: BBK
    series:
      - id: BBK01.WT5511
        title: 10-Year Bund Yield
        flow_ref: BBSIS
        key: D.I.ZST.USGB.EUR.RT.B

  # ---------- Destatis ----------
  destatis:
    adapter: destatis
    series:
      - id: "61111-0001"
        title: Consumer Price Index (Germany)
        table_code: "61111-0001"

  # ---------- OECD ----------
  oecd:
    adapter: sdmx
    provider: OECD
    series:
      - id: QNA.DEU.B1_GE.GPSA.Q
        title: German GDP (Quarterly, SA)
        flow_ref: QNA
        key: DEU.B1_GE.GPSA.Q

  # ---------- BIS ----------
  bis:
    adapter: sdmx
    provider: BIS
    series:
      - id: WS_SPP.Q.DE.N.628
        title: Residential Property Prices — Germany
        flow_ref: WS_SPP
        key: Q.DE.N.628
```

- [ ] **Step 4: Verify CLI help works**

Run: `python -m econ_pipeline --help`
Expected output containing:
```
usage: econ-pipeline [-h] [--config CONFIG] [--schema SCHEMA] [--dry-run] [--verbose]
```

- [ ] **Step 5: Verify dry-run with example config**

Run: `python -m econ_pipeline --config config/series.yaml --dry-run -v`
Expected: Logs showing config loaded, adapters created (FRED adapter will fail if FRED_API_KEY not set, which is acceptable in dry-run; other adapters should succeed).

- [ ] **Step 6: Commit**

```bash
git add econ_pipeline/cli.py econ_pipeline/__main__.py config/series.yaml
git commit -m "feat: add CLI entry point with dry-run mode and example series config"
```

---

### Task 10: Final Review

```yaml
- id: t10
  title: "Final review — interface consistency, error handling, idempotency"
  agent: reviewer
  depends_on: [t9]
  output: "Review report with findings"
  files: ["econ_pipeline/", "tests/", "config/"]
```

**Files:**
- Read: all files in `econ_pipeline/`, `tests/`, `config/`

- [ ] **Step 1: Read all source files**

Read every `.py` file in `econ_pipeline/` and `tests/` and the `config/series.yaml`.

- [ ] **Step 2: Check adapter interface consistency**

Verify all three adapters (FredAdapter, SdmxAdapter, DestatisAdapter):
- Inherit from `BaseAdapter`
- Implement `fetch_series(self, series_config: SeriesConfig, since: date | None = None) -> FetchResult`
- Return `FetchResult` with `observations` DataFrame having exactly columns `["obs_date", "value"]`
- Handle empty results by returning `FetchResult` with empty DataFrame (not raising)
- Log warnings on failure, do not crash

- [ ] **Step 3: Check error handling patterns**

Verify:
- `Pipeline.run()` continues when one adapter or one series fails
- `SnowflakeWriter.write_observations()` skips empty results
- `FredAdapter.fetch_all()` sleeps between requests
- Config loading raises clear errors for missing file, invalid YAML, missing keys
- CLI catches all exceptions and returns exit code 1

- [ ] **Step 4: Check idempotency**

Verify:
- `SnowflakeWriter.ensure_tables()` uses `CREATE TABLE IF NOT EXISTS`
- `SnowflakeWriter.write_metadata()` uses MERGE (upsert, not INSERT)
- `SnowflakeWriter.write_observations()` uses MERGE on (source, series_id, obs_date)
- Running the pipeline twice with the same data produces no duplicates

- [ ] **Step 5: Run full test suite**

Run: `python -m pytest tests/ -v --tb=short`
Expected: All tests PASS (approximately 42 tests across 7 test files)

- [ ] **Step 6: Check test isolation**

Verify:
- No test makes real HTTP calls (all use fakes/stubs/mocks)
- No test connects to Snowflake (all use FakeConnection)
- All test files import only from `econ_pipeline` and standard testing libraries
- `conftest.py` fixtures use `tmp_path` for temporary files

- [ ] **Step 7: Report findings and commit if clean**

If all checks pass:
```bash
git add -A
git commit -m "chore: verify full test suite passes — all adapters, writer, pipeline"
```

If issues found: document specific file, line, and fix required.

---

## Execution DAG

```
Wave 0 (parallel): t1 (architect)
Wave 1 (parallel): t2 (developer), t3 (architect), t4 (developer)
Wave 2 (parallel): t5 (developer), t6 (developer), t7 (developer)
Wave 3:            t8 (developer)        <- depends on t2, t4, t5, t6, t7
Wave 4:            t9 (developer)        <- depends on t8
Wave 5:            t10 (reviewer)        <- depends on t9
```

```
Critical path: t1 -> t3 -> t5 -> t8 -> t9 -> t10 (6 of 10 tasks, 60%)
Parallelism benefit: 10/6 = 1.67x
Recommendation: DAG dispatch
```

---

### Critical Files for Implementation
- `/Users/kirill/repo/rune-main/econ_pipeline/models.py` - Core data models (SeriesMetadata, FetchResult) used by all other modules
- `/Users/kirill/repo/rune-main/econ_pipeline/adapters/base.py` - BaseAdapter ABC defining the interface all adapters must implement
- `/Users/kirill/repo/rune-main/econ_pipeline/writer.py` - SnowflakeWriter with DDL and MERGE upsert logic
- `/Users/kirill/repo/rune-main/econ_pipeline/pipeline.py` - Pipeline orchestrator wiring config, adapters, and writer together
- `/Users/kirill/repo/rune-main/econ_pipeline/adapters/sdmx.py` - SdmxAdapter covering 5 of the 7 data sources (ECB, Eurostat, Bundesbank, OECD, BIS)