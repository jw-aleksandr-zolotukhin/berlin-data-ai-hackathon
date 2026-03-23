-- Grain: one row per app_locale (user's chosen market)
-- Market entry scorecard: which market has the strongest demand-to-supply gap?
-- A high avod_gap_ratio means lots of titles have user interest but no free/ads supply —
-- the best candidate for JustWatch AVOD launch.
--
-- Supply is inferred globally from clickout behaviour (not market-specific),
-- so a "gap" = title has demand in this market AND no free/ads offer observed anywhere.
{{ config(materialized='table') }}

with supply_by_title as (
    -- Aggregate supply flags to title level (global, not per-market)
    select
        title_entity_id,
        count_if(monetization_type in ('free', 'ads'))          > 0  as has_avod_supply,
        count_if(monetization_type in ('rent', 'buy', 'cinema')) > 0  as has_tvod_supply,
        count_if(monetization_type in ('flatrate', 'sports'))    > 0  as has_svod_supply,
        count(distinct provider_id)                                   as total_provider_count
    from {{ ref('int_title_provider_supply') }}
    group by 1
),

market_title_detail as (
    -- Join market demand with global supply info per title
    select
        m.app_locale,
        m.title_entity_id,
        m.avod_demand,
        m.tvod_demand,
        m.unique_users,
        coalesce(s.has_avod_supply, false)  as has_avod_supply,
        coalesce(s.has_tvod_supply, false)  as has_tvod_supply,
        coalesce(s.has_svod_supply, false)  as has_svod_supply
    from {{ ref('int_title_market_demand') }} m
    left join supply_by_title s on m.title_entity_id = s.title_entity_id
),

aggregated as (
    select
        app_locale,

        -- ── demand ───────────────────────────────────────────────────────────────
        sum(avod_demand)                                                        as total_avod_demand,
        sum(tvod_demand)                                                        as total_tvod_demand,
        sum(unique_users)                                                       as total_unique_users,
        count(distinct title_entity_id)                                         as titles_with_demand,

        -- titles with specific demand types
        count(distinct case when avod_demand > 0 then title_entity_id end)      as titles_with_avod_demand,
        count(distinct case when tvod_demand > 0 then title_entity_id end)      as titles_with_tvod_demand,

        -- ── supply coverage ───────────────────────────────────────────────────────
        count(distinct case when has_avod_supply then title_entity_id end)      as titles_with_avod_supply,
        count(distinct case when has_tvod_supply then title_entity_id end)      as titles_with_tvod_supply,

        -- ── gaps: demand with no supply ───────────────────────────────────────────
        count(distinct case
            when avod_demand > 0 and not has_avod_supply
            then title_entity_id end)                                           as avod_gap_titles,
        count(distinct case
            when tvod_demand > 0 and not has_tvod_supply
            then title_entity_id end)                                           as tvod_gap_titles,

        -- total demand for titles with no AVOD supply (volume of unmet demand)
        sum(case when not has_avod_supply then avod_demand else 0 end)          as avod_unmet_demand,
        sum(case when not has_tvod_supply then tvod_demand else 0 end)          as tvod_unmet_demand

    from market_title_detail
    group by 1
)

select
    *,

    -- Gap ratios: share of demand-bearing titles that lack supply (0 = fully covered, 1 = no supply)
    avod_gap_titles / nullif(titles_with_avod_demand, 0)    as avod_gap_ratio,
    tvod_gap_titles / nullif(titles_with_tvod_demand, 0)    as tvod_gap_ratio,

    -- Supply coverage rates
    titles_with_avod_supply / nullif(titles_with_avod_demand, 0)  as avod_supply_coverage,
    titles_with_tvod_supply / nullif(titles_with_tvod_demand, 0)  as tvod_supply_coverage,

    -- Market entry opportunity score: total demand × gap ratio
    -- Higher = larger untapped AVOD audience in this market
    total_avod_demand * (avod_gap_titles / nullif(titles_with_avod_demand, 0))  as avod_opportunity_score,
    total_tvod_demand * (tvod_gap_titles / nullif(titles_with_tvod_demand, 0))  as tvod_opportunity_score

from aggregated
order by avod_opportunity_score desc nulls last
