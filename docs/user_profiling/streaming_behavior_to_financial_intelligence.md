# User Segmentation & Financial Intelligence — Session Summary

**Date:** 2026-03-23
**Team:** Team 3
**Snowflake Account:** `OHHGHHL-ZM06890`
**Team Database:** `DB_TEAM_3`
**Shared Data:** `DB_JW_SHARED.CHALLENGE`

---

## What We Built

### Goal
Build a rich user segmentation model from JustWatch behavioral data (Germany, Dec 2025, 9.15M events, 1.58M users), assign financial profiles to each user, and generate per-user financial advice using Snowflake Cortex AI.

---

## Data Exploration Findings

- **9,150,282 events** | **1,583,510 unique users** | **2,531,417 sessions** | Full December 2025
- No bot traffic detected (`Robot`, `Spy`, `Hacker` device classes absent)
- **Event mix:** 47% page views, 30% title clicks, 8% clickouts, 4% watchlist/seenlist
- **Device split:** Phone 58%, Desktop 31%, Mobile (app) 7%, Tablet 3%
- **Activity distribution:** 37% one-shot visitors, 48% 2–5 events, 12% engaged (6–20), 3% power users
- **Content:** Movies dominate (65% of events, 93K unique titles vs. 30K shows)
- **Only 4.5% of users are logged in** — most are anonymous

---

## Tables Built

All tables live in `DB_TEAM_3.analysis`.

### Layer 1 — Base Features

#### `user_profiles` *(superseded by v2)*
First-pass per-user aggregation from T1 events only. 43 columns.

#### `user_profiles_v2` — **MASTER TABLE**
**1,583,510 rows | 80 columns**
One row per user. Merges all three enrichment tables below.

```sql
SELECT * FROM DB_TEAM_3.analysis.user_profiles_v2 LIMIT 10;
```

---

### Layer 2 — Enrichment Tables (inputs to v2)

#### `user_content_features`
**1,583,510 rows | 23 columns**
Joins T1 events → OBJECTS table. Per-user content quality and format signals.

| Column | Description |
|---|---|
| `avg_imdb_score` | Mean IMDB score of titles engaged with |
| `median_imdb_score` | Median IMDB score |
| `events_high_rated` | Events on titles with IMDB ≥ 8.0 |
| `events_low_rated` | Events on titles with IMDB < 5.0 |
| `avg_imdb_votes` | Mean IMDB vote count (mainstream vs. niche) |
| `avg_tmdb_popularity` | TMDB popularity score |
| `avg_rt_score` | Rotten Tomatoes score |
| `avg_release_year` | Mean release year of engaged content |
| `new_release_ratio` | % of events on titles released 2024+ |
| `classic_content_events` | Events on titles released before 2010 |
| `fav_content_language` | Most common content language (ISO code) |
| `english_content_ratio` | % of events on English-language content |
| `german_content_events` | Events on German-language content |
| `foreign_language_events` | Events on non-English, non-German content |
| `avg_content_runtime_mins` | Mean runtime of engaged content |
| `short_content_events` | Events on content < 90 minutes |
| `medium_content_events` | Events on content 90–150 minutes |
| `long_content_events` | Events on content > 150 minutes |
| `avg_production_budget` | Mean production budget of engaged titles |
| `blockbuster_events` | Events on titles with budget > $50M |
| `indie_events` | Events on titles with budget $0–$5M |

---

#### `user_genre_features`
**~1,575,000 rows | 17 columns**
Joins T1 → OBJECTS with `LATERAL FLATTEN` on `genre_tmdb` array.

| Column | Description |
|---|---|
| `top_genre_1/2/3` | Top 3 genres by event count |
| `top_genre_1_pct` | % of genre events accounted for by top genre |
| `genre_concentration_hhi` | Herfindahl index: 0 = max diversity, 1 = mono-genre |
| `distinct_genres_engaged` | Count of unique genres interacted with |
| `genre_action/comedy/drama/thriller/horror/romance/documentary/animation/crime/scifi/family` | Raw event counts per genre |

---

#### `user_behavioral_features`
**1,583,510 rows | 18 columns**
Purely from T1 events — temporal patterns, provider loyalty, watchlist funnel.

| Column | Description |
|---|---|
| `morning/afternoon/evening/late_night_events` | Event counts by time-of-day bucket |
| `peak_hour` | Most common activity hour (0–23) |
| `weekend_events` / `weekday_events` | Events on weekends vs. weekdays |
| `weekend_ratio` | % of events on weekends |
| `days_inactive_end_of_month` | Days since last event (recency) |
| `active_day_span` | Days between first and last event |
| `distinct_platforms` | Number of distinct platforms used (web/mob) |
| `distinct_device_classes` | Number of distinct device classes |
| `search_ratio` | % of events that are search actions |
| `wl_unique_titles` | Unique titles added to watchlist |
| `wl_converted_to_clickout` | Watchlist titles that were later clicked out |
| `watchlist_conversion_rate` | wl_converted / wl_unique (funnel metric) |
| `top_provider` | Most clicked-out streaming provider |
| `second_provider` | Second most clicked-out provider |
| `unique_providers_used` | Count of distinct providers clicked |
| `is_subscription_stacker` | TRUE if user clicked out to 3+ providers |

---

### Layer 3 — Segmentation

#### `user_segments`
**1,583,510 rows**
One segment label + financial score per user, assigned by priority rules.

**Segment Logic (priority order):**

| Segment | Rule | Users | % |
|---|---|---|---|
| One-Shot Visitor | total_events = 1 | 587K | 37.1% |
| Premium Buyer | TVOD or cinema clickout + 3+ events | 61K | 3.8% |
| Subscription Stacker | 3+ distinct providers + 3+ events | 8K | 0.5% |
| Curator & Planner | curation score ≥ 5 + 5+ events | 13K | 0.8% |
| Binge Watcher | show-heavy + movie_ratio < 35% + 2+ sessions | 28K | 1.8% |
| Deal Hunter | AVOD only, zero SVOD/TVOD | 215K | 13.6% |
| Subscription Loyalist | SVOD only, zero TVOD | 77K | 4.8% |
| Casual Browser | 2–9 events, zero clickouts | 510K | 32.2% |
| Active Explorer | 10+ events, zero clickouts | 46K | 2.9% |
| General User | everything else | 39K | 2.5% |

**Financial Score formula (0–100):**
```
clickout_tvod × 15
+ clickout_cinema × 12
+ clickout_svod × 8
+ clickout_avod × 3
+ watchlist_adds × 2
+ (is_subscription_stacker → +20)
+ (total_events ≥ 20 → +10)
+ (primary_os = 'iOS' → +5)
```

---

#### `segment_intelligence`
**10 rows**
Segment-level aggregates + Cortex LLM narrative per segment.
One AI-generated profile, financial insight, and product recommendation per segment bucket.
**Note:** This is aggregated — everyone in a segment gets the same text.

```sql
SELECT segment, users, avg_financial_score, ai_insight
FROM DB_TEAM_3.analysis.segment_intelligence
ORDER BY users DESC;
```

---

### Layer 4 — Per-User Financial Assessment

#### `user_financial_profiles`
**1,583,510 rows**
Every user gets their own individual signals across 12 dimensions — not their segment's average.

| Dimension | Values |
|---|---|
| `tvod_propensity` | none / medium / high |
| `svod_tier` | none / single / committed / stacker |
| `is_cinema_goer` | TRUE / FALSE |
| `is_free_only` | TRUE / FALSE |
| `engagement_tier` | low / casual / engaged / power |
| `loyalty_tier` | new / returning / veteran (from max_session_idx) |
| `planning_behavior` | impulse / planner / heavy_planner |
| `content_quality_tier` | low_bar / mainstream / quality_seeker |
| `budget_content_pref` | indie_fan / blockbuster_fan / mixed |
| `recency_preference` | catalog_diver / balanced / trend_chaser |
| `language_preference` | english_dominant / local_content_fan / international_viewer |
| `device_ecosystem` | apple_native / apple_web / android_native / desktop_user / other |
| `viewing_time_profile` | night_owl / early_bird / evening_viewer / daytime_viewer |
| `schedule_type` | weekday_commuter / balanced_viewer / weekend_binger |

Also includes raw signals: `top_genre_1/2/3`, `top_provider`, `second_provider`, `primary_city`, `avg_imdb_score`, raw clickout counts, `max_session_idx`, `is_logged_in_user`.

---

#### `user_financial_advice`
**50,527 rows** (users with financial_score > 25)
Per-user Cortex LLM financial assessment using `llama3.1-70b`.
Each user receives a 3-line response built from their actual individual data:
- **WHO** — who this person is in real life
- **MONEY SIGNAL** — what their streaming behavior reveals about their finances
- **ADVICE** — a specific financial product or action recommendation

Example: Two `Premium Buyers` in different cities get different advice:
- Frankfurt / Drama / Videoload / desktop → Amex Platinum recommendation
- Frankfurt / Drama+Romance / Amazon Prime / Apple native / night owl → consolidate subscriptions + redirect savings to high-yield account
- Kassel / Drama / WOW / desktop / planner → Riester pension (Germany-specific)

```sql
SELECT user_id, segment, financial_score, top_genre_1, top_provider,
       primary_city, device_ecosystem, financial_advice
FROM DB_TEAM_3.analysis.user_financial_advice
ORDER BY financial_score DESC
LIMIT 20;
```

---

## Data Lineage

```
DB_JW_SHARED.CHALLENGE.T1 (9.15M events)
    │
    ├── [aggregate per user_id]
    │       │
    │       └── user_profiles (43 cols, base)
    │
    ├── [join OBJECTS → IMDB, language, runtime, budget]
    │       └── user_content_features (23 cols)
    │
    ├── [join OBJECTS + LATERAL FLATTEN genre_tmdb]
    │       └── user_genre_features (17 cols)
    │
    └── [temporal, session, provider, watchlist funnel]
            └── user_behavioral_features (18 cols)
                        │
                        └── user_profiles_v2 (80 cols) ← MASTER
                                    │
                            user_segments (segment + financial_score)
                                    │
                        ┌───────────┴───────────┐
                segment_intelligence        user_financial_profiles
                (10 rows, LLM per           (1.58M rows, 12 per-user
                 segment bucket)             dimensional signals)
                                                        │
                                            user_financial_advice
                                            (50,527 rows, per-user
                                             Cortex LLM advice)
```

---

## Warehouse Used

- Exploration: `WH_TEAM_3_XS`
- Heavy joins (OBJECTS, genre FLATTEN): `WH_TEAM_3_XS` (sufficient for T1)
- Cortex LLM (50K rows): `WH_TEAM_3_M`

---

## What Could Be Added Next

- **Lightdash dashboard** — visualise segment sizes, financial scores, top providers per segment
- **Production country features** — domestic (DE) vs. international content ratio per user
- **Session duration metrics** — avg/median session length per user
- **Talent affinity** — favourite actors/directors per user (LATERAL FLATTEN on talent_cast)
- **Cortex embeddings** — `EMBED_TEXT_768` on user genre+provider combination for vector similarity clustering
- **Scale to T2/T3/T4** — extend analysis to 8 EU markets and 3-month window
