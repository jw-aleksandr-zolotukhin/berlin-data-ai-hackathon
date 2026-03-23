-- Grain: one row per top-level title (movie or show)
-- The main licensing intelligence output.
-- Ranks titles by AVOD and TVOD revenue potential relative to estimated licensing cost,
-- and flags titles with unmet demand (high interest, no current supply).
--
-- Key outputs:
--   avod_roi_score / tvod_roi_score  — demand ÷ cost, use to rank candidates
--   is_avod_underserved              — high AVOD demand, zero free/ads supply observed
--   is_tvod_underserved              — high TVOD demand, zero rent/buy supply observed
--   licensing_recommendation         — avod_priority / tvod_priority / low_priority
--   demand_rank                      — overall rank across all titles
{{ config(materialized='table') }}

with demand as (
    -- Roll up daily signals to title totals
    select
        title_entity_id,
        sum(page_views)         as total_page_views,
        sum(title_clicks)       as total_title_clicks,
        sum(watchlist_adds)     as total_watchlist_adds,
        sum(seenlist_adds)      as total_seenlist_adds,
        sum(likes)              as total_likes,
        sum(trailer_plays)      as total_trailer_plays,
        sum(avod_clickouts)     as total_avod_clickouts,
        sum(rent_clickouts)     as total_rent_clickouts,
        sum(buy_clickouts)      as total_buy_clickouts,
        sum(cinema_clickouts)   as total_cinema_clickouts,
        sum(tvod_clickouts)     as total_tvod_clickouts,
        sum(svod_clickouts)     as total_svod_clickouts,
        sum(total_clickouts)    as total_clickouts,
        -- NOTE: sum of daily unique_users double-counts cross-day users;
        -- treat as engagement-days, not true unique users
        sum(unique_users)       as total_user_engagements,
        count(distinct event_date) as active_days,
        max(market_count)       as max_daily_market_count
    from {{ ref('int_title_demand_signals') }}
    group by 1
),

supply as (
    -- Aggregate provider supply per title across all monetization types
    select
        title_entity_id,
        count_if(monetization_type in ('free', 'ads'))          > 0  as has_avod_supply,
        count_if(monetization_type in ('rent', 'buy', 'cinema')) > 0  as has_tvod_supply,
        count_if(monetization_type in ('flatrate', 'sports'))    > 0  as has_svod_supply,
        count(distinct case
            when monetization_type in ('free', 'ads')
            then provider_id end)                                      as avod_provider_count,
        count(distinct case
            when monetization_type in ('rent', 'buy', 'cinema')
            then provider_id end)                                      as tvod_provider_count,
        count(distinct case
            when monetization_type in ('flatrate', 'sports')
            then provider_id end)                                      as svod_provider_count,
        count(distinct provider_id)                                    as total_provider_count
    from {{ ref('int_title_provider_supply') }}
    group by 1
),

market_breadth as (
    -- Count distinct markets with any demand signal per title
    select
        title_entity_id,
        count(distinct app_locale)  as market_count
    from {{ ref('int_title_market_demand') }}
    where avod_demand + tvod_demand > 0
    group by 1
),

objects as (
    -- Top-level titles only: title_id = object_id is true for movies and shows
    select
        object_id,
        object_type,
        title,
        original_title,
        release_year,
        release_date,
        runtime,
        original_language,
        imdb_score,
        imdb_votes,
        genre_tmdb,
        poster_jw
    from {{ ref('base_objects') }}
    where title_id = object_id
),

scored as (
    select
        d.title_entity_id,

        -- content metadata
        o.title,
        o.original_title,
        o.object_type,
        o.release_year,
        o.release_date,
        o.runtime,
        o.original_language,
        o.imdb_score,
        o.imdb_votes,
        o.genre_tmdb,
        o.poster_jw,

        -- raw demand signals
        d.total_page_views,
        d.total_title_clicks,
        d.total_watchlist_adds,
        d.total_seenlist_adds,
        d.total_likes,
        d.total_trailer_plays,
        d.total_avod_clickouts,
        d.total_rent_clickouts,
        d.total_buy_clickouts,
        d.total_cinema_clickouts,
        d.total_tvod_clickouts,
        d.total_svod_clickouts,
        d.total_user_engagements,
        d.active_days,

        -- market breadth
        coalesce(mb.market_count, 1)    as market_count,

        -- supply coverage
        coalesce(s.has_avod_supply, false)      as has_avod_supply,
        coalesce(s.has_tvod_supply, false)      as has_tvod_supply,
        coalesce(s.has_svod_supply, false)      as has_svod_supply,
        coalesce(s.avod_provider_count, 0)      as avod_provider_count,
        coalesce(s.tvod_provider_count, 0)      as tvod_provider_count,
        coalesce(s.svod_provider_count, 0)      as svod_provider_count,
        coalesce(s.total_provider_count, 0)     as total_provider_count,

        -- ── AVOD demand score ─────────────────────────────────────────────────────
        -- Weighted engagement signals (tunable weights)
        (
            d.total_page_views      * 1
            + d.total_title_clicks  * 2
            + d.total_watchlist_adds * 5
            + d.total_seenlist_adds * 3
            + d.total_likes         * 4
            + d.total_trailer_plays * 2
            + d.total_avod_clickouts * 10
        )                                       as avod_raw_score,

        -- ── TVOD demand score ─────────────────────────────────────────────────────
        -- Direct transactional intent signals (tunable weights)
        (
            d.total_rent_clickouts   * 10
            + d.total_buy_clickouts  * 8
            + d.total_cinema_clickouts * 6
        )                                       as tvod_raw_score,

        -- ── Licensing cost proxy ──────────────────────────────────────────────────
        -- Approximates relative licensing cost using recency and popularity.
        -- Higher = more expensive. Tune thresholds based on domain knowledge.
        case
            when o.release_year >= 2024 and coalesce(o.imdb_votes, 0) > 100000 then 'premium'
            when o.release_year >= 2021 and coalesce(o.imdb_votes, 0) > 50000  then 'mid_tier'
            when coalesce(o.imdb_votes, 0) > 10000                             then 'catalog'
            else 'low_cost'
        end                                     as cost_tier,

        -- Numeric multiplier for ROI division (movies cost more per title than shows)
        case
            when o.release_year >= 2024 and coalesce(o.imdb_votes, 0) > 100000 then 4.0
            when o.release_year >= 2021 and coalesce(o.imdb_votes, 0) > 50000  then 2.0
            when coalesce(o.imdb_votes, 0) > 10000                             then 1.5
            else 1.0
        end
        * case when o.object_type = 'movie' then 1.5 else 1.0 end
                                                as cost_multiplier

    from demand d
    left join objects o         on d.title_entity_id = o.object_id
    left join supply s          on d.title_entity_id = s.title_entity_id
    left join market_breadth mb on d.title_entity_id = mb.title_entity_id
)

select
    *,

    -- ── ROI scores ────────────────────────────────────────────────────────────────
    avod_raw_score / cost_multiplier            as avod_roi_score,
    tvod_raw_score / cost_multiplier            as tvod_roi_score,

    -- Cross-market bonus: titles with demand in 3+ markets offer better licensing ROI
    avod_raw_score * (1 + greatest(market_count - 1, 0) * 0.1) as avod_score_market_adjusted,

    -- ── Underserved demand flags ──────────────────────────────────────────────────
    -- Title has AVOD engagement but no observed free/ads supply → licensing gap
    avod_raw_score > 0 and not has_avod_supply  as is_avod_underserved,
    -- Title has TVOD intent but no observed rent/buy supply → licensing gap
    tvod_raw_score > 0 and not has_tvod_supply  as is_tvod_underserved,

    -- ── Licensing recommendation ──────────────────────────────────────────────────
    case
        when avod_roi_score > 0 and tvod_roi_score > 0 then
            case when avod_roi_score >= tvod_roi_score then 'avod_priority' else 'tvod_priority' end
        when avod_roi_score > 0 then 'avod_priority'
        when tvod_roi_score > 0 then 'tvod_priority'
        else 'low_priority'
    end                                         as licensing_recommendation,

    -- ── Overall demand rank ───────────────────────────────────────────────────────
    row_number() over (
        order by avod_raw_score + tvod_raw_score desc
    )                                           as demand_rank,

    row_number() over (
        order by avod_roi_score desc
    )                                           as avod_roi_rank,

    row_number() over (
        order by tvod_roi_score desc
    )                                           as tvod_roi_rank

from scored
