-- Streaming provider lookup | 1,526 rows
-- Join to events: clickout_provider_id = provider_id
{{ config(materialized='view') }}

with source as (
    select * from {{ source('jw_shared', 'PACKAGES') }}
),

renamed as (
    select
        id              as provider_id,
        technical_name,
        clear_name,
        full_name,
        monetization_types  -- comma-separated: "flatrate,rent,buy" etc.
    from source
)

select * from renamed
