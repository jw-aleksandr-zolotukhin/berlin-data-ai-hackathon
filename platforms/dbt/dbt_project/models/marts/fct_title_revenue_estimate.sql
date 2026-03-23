-- Grain: one row per top-level title
-- Translates demand signals into estimated dollar revenue potential using
-- industry benchmark assumptions from seeds/revenue_benchmarks.csv.
--
-- AVOD revenue logic:
--   avod_clickouts × clickout_to_view_conversion × estimated_view_hours × ecpm_usd / 1000
--   = estimated ad revenue if JustWatch licensed and hosted this title for AVOD
--
-- TVOD revenue logic:
--   rent_clickouts × margin_per_rent_usd  +  buy_clickouts × margin_per_buy_usd
--   = estimated transaction margin if JustWatch offered this title for TVOD
--
-- ROI:
--   (avod_revenue_usd + tvod_revenue_usd) / cost_multiplier
--   Cost multiplier accounts for recency, popularity, content type, supply saturation.
--
-- Key output columns for dashboard:
--   avod_revenue_usd      — estimated AVOD ad revenue
--   tvod_revenue_usd      — estimated TVOD transaction margin
--   total_revenue_usd     — combined estimate
--   roi_usd               — revenue / cost index (higher = better acquisition target)
--   acquisition_tier      — top_10pct / top_25pct / mid / tail
--   monetization_signal   — LICENSE FOR AVOD / LICENSE FOR TVOD / SKIP - ON SVOD / MIXED DEMAND
{{ config(materialized='table') }}

with licensing as (
    select * from {{ ref('fct_title_licensing_score') }}
),

monetization as (
    select * from {{ ref('int_title_monetization_profile') }}
),

-- Pull benchmark values as scalar references
benchmarks as (
    select
        max(case when benchmark_name = 'ecpm_usd'                    then value end) as ecpm_usd,
        max(case when benchmark_name = 'estimated_view_hours_per_clickout' then value end) as view_hours_per_clickout,
        max(case when benchmark_name = 'clickout_to_view_conversion'  then value end) as clickout_to_view_rate,
        max(case when benchmark_name = 'margin_per_rent_usd'          then value end) as margin_per_rent,
        max(case when benchmark_name = 'margin_per_buy_usd'           then value end) as margin_per_buy
    from {{ ref('revenue_benchmarks') }}
),

revenue_calc as (
    select
        l.title_entity_id,
        l.title,
        l.original_title,
        l.object_type,
        l.release_year,
        l.release_date,
        l.runtime,
        l.original_language,
        l.imdb_score,
        l.imdb_votes,
        l.genre_tmdb,
        l.poster_jw,

        -- cost model
        l.cost_tier,
        l.cost_multiplier,

        -- raw demand signals (for reference)
        l.total_avod_clickouts,
        l.total_rent_clickouts,
        l.total_buy_clickouts,
        l.total_watchlist_adds,
        l.avod_raw_score,
        l.tvod_raw_score,
        l.market_count,
        l.total_user_engagements,
        l.active_days,

        -- supply state
        l.has_avod_supply,
        l.has_tvod_supply,
        l.has_svod_supply,
        l.avod_provider_count,
        l.tvod_provider_count,
        l.total_provider_count,
        l.is_avod_underserved,
        l.is_tvod_underserved,
        l.avod_roi_score,
        l.tvod_roi_score,
        l.licensing_recommendation,

        -- monetization profile
        coalesce(m.avod_pct, 0)             as avod_pct,
        coalesce(m.svod_pct, 0)             as svod_pct,
        coalesce(m.tvod_pct, 0)             as tvod_pct,
        coalesce(m.dominant_monetization, 'unknown') as dominant_monetization,
        coalesce(m.monetization_signal, 'NO CLICKOUT DATA') as monetization_signal,
        coalesce(m.is_tvod_only, false)     as is_tvod_only,
        coalesce(m.is_svod_exclusive, false) as is_svod_exclusive,
        coalesce(m.total_clickouts, 0)      as total_clickouts,

        -- ── AVOD revenue estimate ──────────────────────────────────────────────────
        -- Each AVOD clickout that converts to a view generates:
        --   view_hours × (ecpm / 1000) in ad revenue
        round(
            l.total_avod_clickouts
            * b.clickout_to_view_rate
            * b.view_hours_per_clickout
            * b.ecpm_usd / 1000.0
        , 2)                                as avod_revenue_usd,

        -- ── TVOD revenue estimate ──────────────────────────────────────────────────
        -- Direct margin per transaction type
        round(
            l.total_rent_clickouts * b.margin_per_rent
            + l.total_buy_clickouts * b.margin_per_buy
        , 2)                                as tvod_revenue_usd,

        -- ── Combined and ROI ──────────────────────────────────────────────────────
        round(
            l.total_avod_clickouts * b.clickout_to_view_rate * b.view_hours_per_clickout * b.ecpm_usd / 1000.0
            + l.total_rent_clickouts * b.margin_per_rent
            + l.total_buy_clickouts  * b.margin_per_buy
        , 2)                                as total_revenue_usd

    from licensing l
    left join monetization m on l.title_entity_id = m.title_entity_id
    cross join benchmarks b
)

select
    *,

    -- ROI: estimated revenue divided by relative licensing cost
    round(total_revenue_usd / nullif(cost_multiplier, 0), 2)    as roi_usd,

    -- Acquisition tier based on ROI percentile
    case
        when percent_rank() over (order by total_revenue_usd / nullif(cost_multiplier, 0) desc) <= 0.10
            then 'top_10pct'
        when percent_rank() over (order by total_revenue_usd / nullif(cost_multiplier, 0) desc) <= 0.25
            then 'top_25pct'
        when percent_rank() over (order by total_revenue_usd / nullif(cost_multiplier, 0) desc) <= 0.50
            then 'mid'
        else 'tail'
    end                                                          as acquisition_tier,

    -- Final ranked lists for dashboard
    row_number() over (order by total_revenue_usd / nullif(cost_multiplier, 0) desc)   as overall_roi_rank,

    row_number() over (
        partition by (dominant_monetization = 'avod')
        order by avod_revenue_usd / nullif(cost_multiplier, 0) desc
    )                                                            as avod_roi_rank,

    row_number() over (
        partition by (dominant_monetization = 'tvod')
        order by tvod_revenue_usd / nullif(cost_multiplier, 0) desc
    )                                                            as tvod_roi_rank

from revenue_calc
