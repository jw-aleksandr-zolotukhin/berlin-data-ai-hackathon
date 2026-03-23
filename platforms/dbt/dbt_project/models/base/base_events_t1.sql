-- Germany only | Dec 2025 | ~9.2M rows | 1.3 GB
-- Prototype and validate all query logic on this table first.
{{ config(materialized='view') }}

{{ base_events('T1') }}
