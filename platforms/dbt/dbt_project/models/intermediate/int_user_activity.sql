-- Grain: one row per user_id
-- Per-user behavioral feature matrix. Source of truth for customer segmentation.
-- Splits December 2025 activity into early (Dec 1–14) vs recent (Dec 15–31) periods
-- so that engagement drop can be detected for churn risk scoring.
--
-- Used by: fct_user_segments
{{ config(materialized='table') }}

with events as (
    select *
    from {{ ref('base_events_t1') }}
    where user_id is not null
),

user_totals as (
    select
        user_id,
        -- keep any non-null login_id across events for this device
        max(login_id)                                                           as login_id,

        -- activity span
        min(collector_tstamp::date)                                             as first_seen_date,
        max(collector_tstamp::date)                                             as last_seen_date,
        count(distinct collector_tstamp::date)                                  as active_days,
        count(distinct session_id)                                              as total_sessions,
        count(*)                                                                as total_events,
        count_if(title_entity_id is not null)                                   as content_events,
        count(distinct title_entity_id)                                         as unique_titles_engaged,

        -- ── AVOD intent signals ───────────────────────────────────────────────────
        count_if(event = 'page_view' and title_entity_id is not null)           as title_page_views,
        count_if(se_category = 'watchlist_add')                                 as watchlist_adds,
        count_if(se_category = 'seenlist_add')                                  as seenlist_adds,
        count_if(se_category = 'likelist_add')                                  as likes,
        count_if(se_category = 'clickout' and se_action in ('free', 'ads'))     as avod_clickouts,

        -- ── TVOD intent signals ───────────────────────────────────────────────────
        count_if(se_category = 'clickout' and se_action = 'rent')               as rent_clickouts,
        count_if(se_category = 'clickout' and se_action = 'buy')                as buy_clickouts,
        count_if(se_category = 'clickout' and se_action = 'cinema')             as cinema_clickouts,

        -- ── Subscription signals ──────────────────────────────────────────────────
        count_if(se_category = 'clickout' and se_action in ('flatrate','sports')) as svod_clickouts,

        -- ── Churn risk signals ────────────────────────────────────────────────────
        -- T1 = Germany, December 2025. Split into two ~equal halves.
        -- Drop-off in the second half signals potential churn.
        count_if(
            collector_tstamp::date between '2025-12-01' and '2025-12-14'
        )                                                                       as early_period_events,
        count_if(
            collector_tstamp::date between '2025-12-15' and '2025-12-31'
        )                                                                       as recent_period_events

    from events
    group by 1
),

-- Primary market: most-used app_locale for this user
user_primary_market as (
    select user_id, app_locale as primary_market
    from (
        select user_id, app_locale, count(*) as locale_events
        from events
        where app_locale is not null
        group by 1, 2
    )
    qualify row_number() over (partition by user_id order by locale_events desc) = 1
)

select
    t.*,
    m.primary_market
from user_totals t
left join user_primary_market m on t.user_id = m.user_id
