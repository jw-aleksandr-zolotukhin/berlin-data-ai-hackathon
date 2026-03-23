-- JustWatch content metadata | ~2.3M rows
-- Join to events: title_entity_id = object_id
{{ config(materialized='view') }}

with source as (
    select * from {{ source('jw_shared', 'OBJECTS') }}
),

renamed as (
    select
        -- primary key & hierarchy
        object_id,
        lower(object_type)      as object_type,  -- normalise: rare "MOVIE" -> "movie"
        title_id,
        parent_id,
        show_season_id,

        -- titles & descriptions
        title,
        original_title,
        translated_title,
        short_description,
        object_text_short_description,
        object_text_translated_title,

        -- release info
        release_year,
        release_date,
        runtime,
        original_language,

        -- array columns (use LATERAL FLATTEN downstream)
        genre_tmdb,
        production_countries,
        talent_cast,
        talent_director,
        talent_writer,

        -- financials & ratings
        production_budget,
        imdb_score,
        scoring,
        scoring:score_imdb_votes::number    as imdb_votes,

        -- series structure
        seasons,
        season_number,
        episodes,
        episode_number,
        episodes_per_season,

        -- external ids & urls
        id_imdb,
        id_tmdb,
        url_imdb,
        url_tmdb,

        -- studios (object — use studios:name::TEXT downstream)
        studios,

        -- media
        poster_jw,
        trailers

    from source
)

select * from renamed
