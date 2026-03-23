-- Grain: one row per (title_entity_id, app_locale)
-- Breaks demand signals out by the user's CHOSEN market (app_locale), not physical location.
-- This is the correct dimension for cross-market licensing ROI analysis.
--
-- IMPORTANT: app_locale is the market the user selected in JustWatch (e.g. 'de_DE').
-- geo_country is where the request came from (e.g. 'FR' for a German expat in France).
-- Always use app_locale for market demand analysis.
--
-- Used by: fct_market_demand_gap (market entry scorecard)
{{ config(materialized='table') }}

with events as (
    select *
    from {{ ref('base_events_t1') }}
    where title_entity_id is not null
      and app_locale is not null      -- exclude events with no market signal
)

select
    title_entity_id,
    app_locale,

    -- raw signal counts
    count_if(event = 'page_view')                                                       as page_views,
    count_if(se_category = 'watchlist_add')                                             as watchlist_adds,
    count_if(se_category = 'clickout' and se_action in ('free', 'ads'))                 as avod_clickouts,
    count_if(se_category = 'clickout' and se_action in ('rent', 'buy', 'cinema'))       as tvod_clickouts,
    count_if(se_category = 'clickout')                                                  as total_clickouts,
    count(distinct user_id)                                                             as unique_users,

    -- weighted demand scores (same formula as fct_title_licensing_score for consistency)
    (
        count_if(event = 'page_view')                                        * 1
        + count_if(se_category = 'watchlist_add')                            * 5
        + count_if(se_category = 'clickout' and se_action in ('free','ads')) * 10
    )                                                                                   as avod_demand,

    count_if(se_category = 'clickout' and se_action in ('rent','buy','cinema'))
        * 10                                                                            as tvod_demand

from events
group by 1, 2
