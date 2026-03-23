-- 8 EU markets | Dec 2025 | ~40M rows | 5.7 GB
-- Scale up from T1 once query logic is validated.
{{ config(materialized='view') }}

{{ base_events('T2') }}
