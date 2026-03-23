-- Grain: one row per (title_entity_id, week_start)
-- Tracks weekly demand trends across the Nov 2025 – Jan 2026 window (T3 data).
-- Use to identify holiday demand spikes and inform seasonal licensing decisions.
--
-- Requires T3 (3-month window). T1 covers Dec only so seasonal patterns are not visible there.
-- Recommended warehouse: WH_TEAM_<N>_S or larger.
{{ config(materialized='table') }}

with events as (
    select *
    from {{ ref('base_events_t3') }}
    where title_entity_id is not null
),

weekly as (
    select
        title_entity_id,
        date_trunc('week', collector_tstamp)::date                              as week_start,

        count_if(event = 'page_view')                                           as page_views,
        count_if(se_category = 'watchlist_add')                                 as watchlist_adds,
        count_if(se_category = 'clickout' and se_action in ('free', 'ads'))     as avod_clickouts,
        count_if(se_category = 'clickout' and se_action = 'rent')               as rent_clickouts,
        count_if(se_category = 'clickout' and se_action in ('buy', 'cinema'))   as buy_clickouts,
        count_if(se_category = 'clickout' and se_action in ('rent','buy','cinema')) as tvod_clickouts,
        count_if(se_category = 'clickout' and se_action in ('flatrate','sports')) as svod_clickouts,
        count(distinct user_id)                                                 as unique_users,
        count(distinct app_locale)                                              as market_count,

        -- Weekly scoring (same weights as fct_title_licensing_score)
        (
            count_if(event = 'page_view')                                 * 1
            + count_if(se_category = 'watchlist_add')                     * 5
            + count_if(se_category = 'clickout' and se_action in ('free','ads')) * 10
        )                                                                       as weekly_avod_score,
        (
            count_if(se_category = 'clickout' and se_action = 'rent')     * 10
            + count_if(se_category = 'clickout' and se_action in ('buy','cinema')) * 8
        )                                                                       as weekly_tvod_score

    from events
    group by 1, 2
),

objects as (
    select object_id, title, object_type, release_year, original_language, genre_tmdb
    from {{ ref('base_objects') }}
    where title_id = object_id      -- top-level titles only
)

select
    w.title_entity_id,
    w.week_start,

    -- content metadata
    o.title,
    o.object_type,
    o.release_year,
    o.original_language,
    o.genre_tmdb,

    -- weekly signals
    w.page_views,
    w.watchlist_adds,
    w.avod_clickouts,
    w.rent_clickouts,
    w.buy_clickouts,
    w.tvod_clickouts,
    w.svod_clickouts,
    w.unique_users,
    w.market_count,
    w.weekly_avod_score,
    w.weekly_tvod_score,

    -- holiday flag: Christmas/New Year window (Dec 20 – Jan 6)
    week_start between '2025-12-20' and '2026-01-06'    as is_holiday_window,

    -- week-over-week change (use in Lightdash with LAG or as a Snowflake window function)
    w.weekly_avod_score - lag(w.weekly_avod_score) over (
        partition by w.title_entity_id order by w.week_start
    )                                                   as avod_score_wow_change

from weekly w
left join objects o on w.title_entity_id = o.object_id
