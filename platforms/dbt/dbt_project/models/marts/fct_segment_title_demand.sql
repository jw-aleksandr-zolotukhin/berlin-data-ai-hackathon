-- Grain: one row per (title_entity_id, user_segment)
-- Breaks title demand signals down by user segment, revealing which audience is
-- driving interest in each title. This bridges customer segmentation and content
-- licensing decisions:
--
--   binger rows   → AVOD acquisition signal (ad-supported audience)
--   whale rows    → TVOD acquisition signal (transactional buyers)
--   churn_risk rows → Retention-driven acquisition signal
--
-- Used by: fct_title_acquisition_priority
{{ config(materialized='table') }}

with user_segments as (
    -- Only non-dormant users carry meaningful segment signal
    select user_id, user_segment
    from {{ ref('fct_user_segments') }}
    where user_segment != 'dormant'
),

events as (
    select *
    from {{ ref('base_events_t1') }}
    where title_entity_id is not null
),

segment_title_events as (
    select
        e.title_entity_id,
        s.user_segment,

        count_if(e.event = 'page_view')                                             as page_views,
        count_if(e.se_category = 'watchlist_add')                                   as watchlist_adds,
        count_if(e.se_category = 'clickout' and e.se_action in ('free', 'ads'))     as avod_clickouts,
        count_if(e.se_category = 'clickout' and e.se_action = 'rent')               as rent_clickouts,
        count_if(e.se_category = 'clickout' and e.se_action in ('buy', 'cinema'))   as buy_clickouts,
        count_if(e.se_category = 'clickout' and e.se_action in ('rent','buy','cinema')) as tvod_clickouts,
        count(distinct e.user_id)                                                   as unique_users

    from events e
    inner join user_segments s on e.user_id = s.user_id
    group by 1, 2
),

objects as (
    select object_id, title, object_type, release_year, imdb_score
    from {{ ref('base_objects') }}
    where title_id = object_id      -- top-level titles only
)

select
    ste.title_entity_id,
    ste.user_segment,

    -- content metadata
    o.title,
    o.object_type,
    o.release_year,
    o.imdb_score,

    -- raw signals
    ste.page_views,
    ste.watchlist_adds,
    ste.avod_clickouts,
    ste.rent_clickouts,
    ste.buy_clickouts,
    ste.tvod_clickouts,
    ste.unique_users,

    -- weighted demand scores (consistent with fct_title_licensing_score weights)
    (ste.page_views * 1 + ste.watchlist_adds * 5 + ste.avod_clickouts * 10)    as avod_demand,
    (ste.rent_clickouts * 10 + ste.buy_clickouts * 8)                          as tvod_demand

from segment_title_events ste
left join objects o on ste.title_entity_id = o.object_id
