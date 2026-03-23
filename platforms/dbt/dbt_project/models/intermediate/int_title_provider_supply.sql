-- Grain: one row per (title_entity_id, provider_id, monetization_type)
-- Infers what providers a title is currently available on, using clickout events as a
-- supply signal. A clickout to a provider is strong evidence the offer exists.
--
-- NOTE: This is a demand-based supply proxy, not a catalogue feed.
-- A title with zero clickouts to a provider may still be available there — it just had no
-- observed demand. Use alongside demand signals, not as ground truth.
--
-- Used by: fct_title_licensing_score (to detect supply gaps)
--          fct_market_demand_gap (to measure coverage per market)
{{ config(materialized='table') }}

with clickouts as (
    select
        title_entity_id,
        clickout_provider_id                    as provider_id,
        clickout_monetization_type              as monetization_type,
        count(distinct user_id)                 as unique_users_clicking,
        count(*)                                as clickout_count
    from {{ ref('base_events_t1') }}
    where se_category = 'clickout'
      and title_entity_id is not null
      and clickout_provider_id is not null
      and clickout_monetization_type is not null
    group by 1, 2, 3
)

select
    c.title_entity_id,
    c.provider_id,
    c.monetization_type,
    c.unique_users_clicking,
    c.clickout_count,
    p.technical_name            as provider_technical_name,
    p.clear_name                as provider_clear_name,
    -- monetization bucket for easy downstream filtering
    case
        when c.monetization_type in ('free', 'ads')            then 'avod'
        when c.monetization_type in ('rent', 'buy', 'cinema')  then 'tvod'
        when c.monetization_type in ('flatrate', 'sports')     then 'svod'
        else 'other'
    end                         as monetization_bucket

from clickouts c
left join {{ ref('base_packages') }} p
    on c.provider_id = p.provider_id
