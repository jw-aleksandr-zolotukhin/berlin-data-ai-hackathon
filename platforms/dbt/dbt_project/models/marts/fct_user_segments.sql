-- Grain: one row per user_id
-- Assigns each user to a behavioural segment and computes normalised intent scores.
-- Segment logic is rule-based (proxy for K-means clustering):
--
--   whale       → top-quartile TVOD intent (high rent/buy clickouts per day)
--   binger      → top-quartile AVOD intent (high page views / watchlist / free clickouts)
--   churn_risk  → previously active, recent engagement dropped >50%
--   casual      → occasional user, below top-quartile on both intent types
--   dormant     → fewer than 2 total events
--
-- Segments are used in fct_segment_title_demand and fct_title_acquisition_priority
-- to connect content licensing decisions to the users they serve.
{{ config(materialized='table') }}

with users as (
    select * from {{ ref('int_user_activity') }}
),

scored as (
    select
        *,

        -- ── Raw intent scores (per-active-day to normalise for session length) ──────
        (title_page_views * 1.0 + watchlist_adds * 5 + avod_clickouts * 10)
            / nullif(active_days, 0)                            as avod_intent_raw,

        (rent_clickouts * 10.0 + buy_clickouts * 8 + cinema_clickouts * 6)
            / nullif(active_days, 0)                            as tvod_intent_raw,

        -- ── Churn risk flag ────────────────────────────────────────────────────────
        -- Compare daily rates across two ~equal December halves (14 vs 17 days).
        -- Flag if recent daily rate < 50% of early daily rate AND user was meaningfully
        -- active in the early period (≥3 events avoids tagging low-signal users).
        (recent_period_events::float / 17.0) < (early_period_events::float / 14.0) * 0.5
            and early_period_events >= 3                        as churn_risk_flag

    from users
),

-- Top-quartile detection: ntile(4) partitioned by whether signal exists
-- ensures users with zero signal aren't misclassified as quartile-1
ranked as (
    select
        *,
        ntile(4) over (
            partition by (avod_intent_raw > 0)
            order by avod_intent_raw desc
        )                                                       as avod_quartile,

        ntile(4) over (
            partition by (tvod_intent_raw > 0)
            order by tvod_intent_raw desc
        )                                                       as tvod_quartile

    from scored
),

-- Single-row max values for 0–100 normalisation
score_max as (
    select
        nullif(max(avod_intent_raw), 0) as avod_max,
        nullif(max(tvod_intent_raw), 0) as tvod_max
    from scored
)

select
    r.user_id,
    r.login_id,
    r.primary_market,
    r.first_seen_date,
    r.last_seen_date,
    r.active_days,
    r.total_sessions,
    r.total_events,
    r.unique_titles_engaged,

    -- raw signal counts (useful for ML feature export)
    r.title_page_views,
    r.watchlist_adds,
    r.avod_clickouts,
    r.rent_clickouts,
    r.buy_clickouts,
    r.svod_clickouts,
    r.early_period_events,
    r.recent_period_events,

    -- churn flag
    r.churn_risk_flag,

    -- normalised intent scores (0–100)
    least(r.avod_intent_raw / m.avod_max * 100, 100)            as avod_intent_score,
    least(r.tvod_intent_raw / m.tvod_max * 100, 100)            as tvod_intent_score,

    -- ── User segment ──────────────────────────────────────────────────────────────
    -- churn_risk overrides other positive signals — retention beats acquisition
    case
        when r.churn_risk_flag and r.early_period_events >= 3   then 'churn_risk'
        when r.tvod_quartile = 1 and r.tvod_intent_raw > 0      then 'whale'
        when r.avod_quartile = 1 and r.avod_intent_raw > 0      then 'binger'
        when r.total_events >= 2                                 then 'casual'
        else 'dormant'
    end                                                         as user_segment

from ranked r
cross join score_max m
