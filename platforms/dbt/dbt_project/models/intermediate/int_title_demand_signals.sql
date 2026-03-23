-- Grain: one row per (title_entity_id, event_date)
-- Aggregates all demand signals from events into daily counts per top-level title.
-- Used by: fct_title_licensing_score (rolled up to title total)
--          fct_title_seasonality (rolled up to weekly)
--
-- Source: base_events_t1 (prototype — change to t2/t3 to scale)
{{ config(materialized='table') }}

with events as (
    select *
    from {{ ref('base_events_t1') }}
    where title_entity_id is not null
)

select
    title_entity_id,
    date_trunc('day', collector_tstamp)::date                                           as event_date,

    -- ── AVOD demand signals ──────────────────────────────────────────────────────
    -- Engagement depth proxies for ad-supported viewing demand
    count_if(event = 'page_view')                                                       as page_views,
    count_if(se_category = 'userinteraction' and se_action = 'title_clicked')           as title_clicks,
    count_if(se_category = 'watchlist_add')                                             as watchlist_adds,
    count_if(se_category = 'seenlist_add')                                              as seenlist_adds,
    count_if(se_category = 'likelist_add')                                              as likes,
    count_if(se_category = 'youtube_started')                                           as trailer_plays,
    -- Direct AVOD intent: user clicked out to a free / ad-supported offer
    count_if(se_category = 'clickout' and se_action in ('free', 'ads'))                 as avod_clickouts,

    -- ── TVOD demand signals ──────────────────────────────────────────────────────
    -- Strongest transactional intent signals in the dataset
    count_if(se_category = 'clickout' and se_action = 'rent')                          as rent_clickouts,
    count_if(se_category = 'clickout' and se_action = 'buy')                           as buy_clickouts,
    count_if(se_category = 'clickout' and se_action = 'cinema')                        as cinema_clickouts,
    count_if(se_category = 'clickout' and se_action in ('rent', 'buy', 'cinema'))      as tvod_clickouts,

    -- ── Competitor / subscription signals ────────────────────────────────────────
    count_if(se_category = 'clickout' and se_action in ('flatrate', 'sports'))         as svod_clickouts,

    -- ── Totals ───────────────────────────────────────────────────────────────────
    count_if(se_category = 'clickout')                                                  as total_clickouts,
    count(distinct user_id)                                                             as unique_users,
    count(distinct session_id)                                                          as unique_sessions,
    -- Use app_locale (user's chosen market), NOT geo_country (physical location)
    count(distinct app_locale)                                                          as market_count

from events
group by 1, 2
