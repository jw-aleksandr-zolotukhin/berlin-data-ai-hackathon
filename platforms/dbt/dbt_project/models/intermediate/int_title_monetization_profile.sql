-- Grain: one row per title_entity_id
-- Answers: what monetization model do users prefer for this title?
-- Uses clickout events as direct monetization intent signals.
--
-- dominant_monetization logic:
--   avod  → users click to free/ads offers most
--   tvod  → users click to rent/buy most
--   svod  → users click to flatrate/sports most (title already on subscription)
--   mixed → no clear majority (largest bucket < 50% of total clickouts)
--
-- monetization_signal is the business recommendation:
--   LICENSE FOR AVOD  → avod dominant, acquire free/ads rights
--   LICENSE FOR TVOD  → tvod dominant, acquire rent/buy rights
--   SKIP - ON SVOD    → svod dominant, title already on Netflix/Amazon etc.
--   MIXED DEMAND      → no clear signal, review manually
--
-- Used by: fct_title_revenue_estimate, fct_title_acquisition_priority
{{ config(materialized='table') }}

with clickouts as (
    select
        title_entity_id,
        count_if(se_action in ('free', 'ads'))              as avod_clicks,
        count_if(se_action in ('flatrate', 'sports'))       as svod_clicks,
        count_if(se_action in ('rent', 'buy', 'cinema'))    as tvod_clicks,
        count_if(se_action = 'rent')                        as rent_clicks,
        count_if(se_action = 'buy')                         as buy_clicks,
        count_if(se_action = 'cinema')                      as cinema_clicks,
        count(*)                                            as total_clickouts
    from {{ ref('base_events_t1') }}
    where se_category = 'clickout'
      and title_entity_id is not null
    group by 1
    having total_clickouts >= 5   -- filter noise: titles with < 5 clickouts have no reliable signal
),

with_pcts as (
    select
        title_entity_id,
        avod_clicks,
        svod_clicks,
        tvod_clicks,
        rent_clicks,
        buy_clicks,
        cinema_clicks,
        total_clickouts,

        -- percentage split (0-100)
        round(avod_clicks * 100.0 / nullif(total_clickouts, 0), 1)  as avod_pct,
        round(svod_clicks * 100.0 / nullif(total_clickouts, 0), 1)  as svod_pct,
        round(tvod_clicks * 100.0 / nullif(total_clickouts, 0), 1)  as tvod_pct,

        -- dominant monetization: whichever bucket has the most clicks
        case
            when avod_clicks >= svod_clicks and avod_clicks >= tvod_clicks
                 and avod_clicks * 1.0 / nullif(total_clickouts, 0) >= 0.5
                then 'avod'
            when tvod_clicks >= svod_clicks and tvod_clicks >= avod_clicks
                 and tvod_clicks * 1.0 / nullif(total_clickouts, 0) >= 0.5
                then 'tvod'
            when svod_clicks >= avod_clicks and svod_clicks >= tvod_clicks
                 and svod_clicks * 1.0 / nullif(total_clickouts, 0) >= 0.5
                then 'svod'
            else 'mixed'
        end                                                          as dominant_monetization
    from clickouts
)

select
    title_entity_id,
    avod_clicks,
    svod_clicks,
    tvod_clicks,
    rent_clicks,
    buy_clicks,
    cinema_clicks,
    total_clickouts,
    avod_pct,
    svod_pct,
    tvod_pct,
    dominant_monetization,

    -- business recommendation
    case dominant_monetization
        when 'avod'  then 'LICENSE FOR AVOD'
        when 'tvod'  then 'LICENSE FOR TVOD'
        when 'svod'  then 'SKIP - ON SVOD'
        else              'MIXED DEMAND'
    end                                                              as monetization_signal,

    -- TVOD-to-AVOD flag: users pay to watch it but no free option clicked
    -- → good candidate to license AVOD rights and capture the free audience
    tvod_clicks > 0 and avod_clicks = 0                             as is_tvod_only,

    -- Subscription arbitrage flag: only on subscription, no free or pay-per-view
    svod_clicks > 0 and avod_clicks = 0 and tvod_clicks = 0         as is_svod_exclusive

from with_pcts
