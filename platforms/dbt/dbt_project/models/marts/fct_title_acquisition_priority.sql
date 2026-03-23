-- Grain: one row per top-level title
-- The StreamCap "Shopping List" — final ranked content acquisition output.
-- Combines licensing ROI scores with customer segment demand signals to answer:
--   Which titles should JustWatch license, for which audience, and why?
--
-- acquisition_rank is the primary sort column for the dashboard.
-- composite_acquisition_score = ROI base + strategic bonuses (all tunable).
--
-- Strategic bonus structure:
--   +25  cross_market: demanded in 3+ markets (better licensing ROI)
--   +20  avod_underserved: high AVOD demand, no free/ads supply exists
--   +15  tvod_to_avod: users pay to rent/buy but no free option exists → disrupt
--   +15  churn_prevention: at-risk users are specifically requesting this title
--   +10  binger_driven: AVOD demand is primarily from high-volume Binger segment
{{ config(materialized='table') }}

with licensing as (
    select * from {{ ref('fct_title_licensing_score') }}
),

-- Pull segment demand for each title
binger_demand as (
    select
        title_entity_id,
        avod_demand     as binger_avod_demand,
        tvod_demand     as binger_tvod_demand,
        unique_users    as binger_users
    from {{ ref('fct_segment_title_demand') }}
    where user_segment = 'binger'
),

whale_demand as (
    select
        title_entity_id,
        avod_demand     as whale_avod_demand,
        tvod_demand     as whale_tvod_demand,
        unique_users    as whale_users
    from {{ ref('fct_segment_title_demand') }}
    where user_segment = 'whale'
),

churn_demand as (
    select
        title_entity_id,
        avod_demand + tvod_demand   as churn_risk_demand,
        avod_demand                 as churn_risk_avod_demand,
        tvod_demand                 as churn_risk_tvod_demand,
        unique_users                as churn_risk_users
    from {{ ref('fct_segment_title_demand') }}
    where user_segment = 'churn_risk'
),

pre_scored as (
    select
        -- ── Identity & metadata ───────────────────────────────────────────────────
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

        -- ── Cost model ────────────────────────────────────────────────────────────
        l.cost_tier,
        l.cost_multiplier,

        -- ── Base ROI scores ───────────────────────────────────────────────────────
        l.avod_raw_score,
        l.tvod_raw_score,
        l.avod_roi_score,
        l.tvod_roi_score,
        l.market_count,
        l.total_user_engagements,
        l.active_days,
        l.licensing_recommendation,

        -- ── Current supply state ──────────────────────────────────────────────────
        l.has_avod_supply,
        l.has_tvod_supply,
        l.has_svod_supply,
        l.avod_provider_count,
        l.tvod_provider_count,
        l.total_provider_count,
        l.is_avod_underserved,
        l.is_tvod_underserved,

        -- Scarcity index: 1 = no supply anywhere, → 0 = on many platforms
        1.0 / (1.0 + l.total_provider_count)               as scarcity_index,

        -- ── Segment demand breakdown ──────────────────────────────────────────────
        coalesce(bd.binger_avod_demand, 0)                  as binger_avod_demand,
        coalesce(bd.binger_users, 0)                        as binger_user_count,
        coalesce(wd.whale_tvod_demand, 0)                   as whale_tvod_demand,
        coalesce(wd.whale_users, 0)                         as whale_user_count,
        coalesce(cd.churn_risk_demand, 0)                   as churn_risk_demand,
        coalesce(cd.churn_risk_avod_demand, 0)              as churn_risk_avod_demand,
        coalesce(cd.churn_risk_tvod_demand, 0)              as churn_risk_tvod_demand,
        coalesce(cd.churn_risk_users, 0)                    as churn_risk_user_count,

        -- ── Strategic acquisition flags ───────────────────────────────────────────
        -- 1. AVOD gap: bingers want it, nobody offers it free
        l.is_avod_underserved
            and coalesce(bd.binger_avod_demand, 0) > 0      as is_avod_gap_opportunity,

        -- 2. TVOD-to-AVOD pipeline: users pay to watch it — license the free rights
        l.tvod_raw_score > 0 and not l.has_avod_supply      as is_tvod_to_avod_candidate,

        -- 3. Churn prevention: at-risk users are specifically requesting this title
        coalesce(cd.churn_risk_demand, 0) > 0               as is_churn_prevention_title,

        -- 4. Cross-market arbitrage: demanded across 3+ different markets
        l.market_count >= 3                                 as is_cross_market_opportunity,

        -- 5. Binger-driven: majority of AVOD demand comes from high-value Binger segment
        coalesce(bd.binger_avod_demand, 0) >
            coalesce(l.avod_raw_score, 0) * 0.3             as is_binger_driven,

        -- ── Composite acquisition score ───────────────────────────────────────────
        -- Base: AVOD + TVOD ROI scores (demand ÷ estimated cost)
        -- Bonuses: strategic value on top (tune values to business priorities)
        l.avod_roi_score + l.tvod_roi_score
            + case when l.market_count >= 3                             then 25 else 0 end
            + case when l.is_avod_underserved                           then 20 else 0 end
            + case when l.tvod_raw_score > 0 and not l.has_avod_supply  then 15 else 0 end
            + case when coalesce(cd.churn_risk_demand, 0) > 0           then 15 else 0 end
            + case when coalesce(bd.binger_avod_demand, 0) >
                        coalesce(l.avod_raw_score, 0) * 0.3             then 10 else 0 end
                                                            as composite_acquisition_score

    from licensing l
    left join binger_demand bd  on l.title_entity_id = bd.title_entity_id
    left join whale_demand  wd  on l.title_entity_id = wd.title_entity_id
    left join churn_demand  cd  on l.title_entity_id = cd.title_entity_id
)

select
    *,
    -- Final ranked shopping list (rank 1 = highest priority to license)
    row_number() over (
        order by composite_acquisition_score desc
    )                                                       as acquisition_rank,

    -- Segment-specific ranks for filtered views
    row_number() over (
        partition by is_churn_prevention_title
        order by churn_risk_demand desc
    )                                                       as churn_prevention_rank,

    row_number() over (
        partition by is_tvod_to_avod_candidate
        order by tvod_raw_score desc
    )                                                       as tvod_to_avod_rank

from pre_scored
