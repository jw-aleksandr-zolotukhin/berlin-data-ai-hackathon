-- Grain: one row per genre
-- Answers: which genres perform best for AVOD (high volume, rewatchable)
-- vs TVOD (premium, event-driven)?
-- Uses LATERAL FLATTEN to expand the genre_tmdb array from base_objects.
-- Titles appear once per genre they belong to (e.g. a Drama/Thriller counts for both).
{{ config(materialized='table') }}

with title_totals as (
    -- Aggregate daily demand signals to title level, using same weights as fct_title_licensing_score
    select
        title_entity_id,
        sum(
            page_views      * 1
            + title_clicks  * 2
            + watchlist_adds * 5
            + seenlist_adds * 3
            + likes         * 4
            + trailer_plays * 2
            + avod_clickouts * 10
        )                       as avod_raw_score,
        sum(
            rent_clickouts   * 10
            + buy_clickouts  * 8
            + cinema_clickouts * 6
        )                       as tvod_raw_score,
        sum(total_clickouts)    as total_clickouts,
        sum(unique_users)       as total_user_engagements
    from {{ ref('int_title_demand_signals') }}
    group by 1
),

title_genre_expanded as (
    -- One row per (title, genre) — titles with multiple genres appear multiple times
    select
        o.object_id     as title_entity_id,
        o.object_type,
        o.release_year,
        o.imdb_score,
        o.imdb_votes,
        g.value::text   as genre
    from {{ ref('base_objects') }} o,
         lateral flatten(input => o.genre_tmdb) as g
    where o.title_id = o.object_id      -- top-level titles only
      and o.genre_tmdb is not null
      and g.value::text is not null
)

select
    tge.genre,

    -- inventory
    count(distinct tge.title_entity_id)                                     as title_count,
    count(distinct case when tge.object_type = 'movie' then tge.title_entity_id end) as movie_count,
    count(distinct case when tge.object_type = 'show'  then tge.title_entity_id end) as show_count,

    -- demand volumes
    sum(coalesce(tt.avod_raw_score, 0))                                     as total_avod_demand,
    sum(coalesce(tt.tvod_raw_score, 0))                                     as total_tvod_demand,
    sum(coalesce(tt.avod_raw_score + tt.tvod_raw_score, 0))                 as total_demand,
    sum(coalesce(tt.total_user_engagements, 0))                             as total_user_engagements,

    -- AVOD vs TVOD split (0 = pure TVOD, 1 = pure AVOD)
    sum(coalesce(tt.avod_raw_score, 0))
        / nullif(sum(coalesce(tt.avod_raw_score + tt.tvod_raw_score, 0)), 0) as avod_share,

    -- quality proxies
    avg(tge.imdb_score)                                                     as avg_imdb_score,
    avg(tge.release_year)                                                   as avg_release_year,

    -- demand per title (intensity, not just volume)
    sum(coalesce(tt.avod_raw_score, 0))
        / nullif(count(distinct tge.title_entity_id), 0)                    as avod_demand_per_title,
    sum(coalesce(tt.tvod_raw_score, 0))
        / nullif(count(distinct tge.title_entity_id), 0)                    as tvod_demand_per_title

from title_genre_expanded tge
left join title_totals tt on tge.title_entity_id = tt.title_entity_id
group by 1
order by total_demand desc
