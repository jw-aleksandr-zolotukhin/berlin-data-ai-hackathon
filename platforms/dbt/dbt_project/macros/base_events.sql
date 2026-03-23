{% macro base_events(source_table) %}

with source as (
    select * from {{ source('jw_shared', source_table) }}
),

deduplicated as (
    select *
    from source
    qualify row_number() over (partition by rid order by collector_tstamp) = 1
),

renamed as (
    select
        -- identifiers
        rid,
        event_id,
        session_id,
        user_id,
        login_id,
        session_idx,

        -- timestamps
        collector_tstamp,
        derived_tstamp,

        -- event type
        event,
        app_id,
        platform,

        -- structured event fields
        se_category,
        se_action,
        se_label,
        se_property,
        se_value,

        -- geography
        geo_country,
        geo_region_name,
        geo_city,

        -- raw context columns (kept as-is for downstream flexibility)
        useragent,
        cc_title,
        cc_page_type,
        cc_clickout,
        cc_yauaa,
        cc_search,

        -- extracted: title context
        cc_title:jwEntityId::text           as title_entity_id,
        cc_title:objectType::text           as title_object_type,
        cc_title:seasonNumber::int          as title_season_number,
        cc_title:episodeNumber::int         as title_episode_number,

        -- extracted: page type context
        cc_page_type:pageType::text         as page_type,
        cc_page_type:appLocale::text        as app_locale,

        -- extracted: clickout context
        cc_clickout:providerId::number      as clickout_provider_id,
        cc_clickout:monetizationType::text  as clickout_monetization_type,

        -- extracted: device / bot detection context
        cc_yauaa:deviceClass::text          as device_class,
        cc_yauaa:agentName::text            as agent_name,

        -- extracted: search context
        cc_search:searchEntry::text         as search_entry

    from deduplicated
    where cc_yauaa:deviceClass::text not in ('Robot', 'Spy', 'Hacker')
)

select * from renamed

{% endmacro %}
