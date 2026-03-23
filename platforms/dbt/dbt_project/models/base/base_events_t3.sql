-- 8 EU markets | Nov 2025 – Jan 2026 (3 months) | ~128M rows | 17.9 GB
-- Use for time-series and trend analysis. Recommend WH_TEAM_<N>_S or larger.
{{ config(materialized='view') }}

{{ base_events('T3') }}
