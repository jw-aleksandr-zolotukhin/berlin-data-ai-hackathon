# Berlin Analytics & AI Hackathon

March 23, 2026 · Snowflake Office Berlin

A one-day hackathon exploring real-world streaming data with modern analytics tools. Build something meaningful from millions of real user interactions on the JustWatch platform.

## Getting Started

**Fork this repo** to your own GitHub account (or your team's). You'll be adding queries, dbt models, and analysis throughout the day — having your own copy lets you commit, collaborate, and keep your work after the hackathon.

```bash
# After forking on GitHub:
git clone https://github.com/<your-username>/berlin-data-ai-hackathon.git
cd berlin-data-ai-hackathon
```

## AI-Agent Friendly

This repo is designed to work with **AI coding assistants** — particularly [Claude Code](https://docs.anthropic.com/en/docs/claude-code). The repo includes:

- **`CLAUDE.md`** — project context, data architecture, SQL patterns, and query conventions that Claude Code loads automatically
- **Lightdash skill** (`.claude/skills/developing-in-lightdash/`) — generates Lightdash explores, charts, and dashboards from plain-language descriptions
- **dbt skills** (`.claude/skills/`) — builds dbt models, runs commands, writes tests, and answers data questions — sourced from [dbt-labs/dbt-agent-skills](https://github.com/dbt-labs/dbt-agent-skills)
- **Collate MCP server** — connect your AI tools to the data catalog to search metadata, look up column descriptions, and create glossary terms. See [platforms/collate/](platforms/collate/) for setup

**How to use:** Open the repo in Claude Code (or an IDE with Claude Code integration) and start asking questions. The AI assistant understands the data schema, knows the SQL patterns for this dataset, and can generate dbt models and Lightdash dashboards for you. Describe what you want to analyse, and it will write the queries and configurations.

You don't need to learn the full syntax of every tool — the AI skills handle that. Focus on the analysis and storytelling.

---

## The Partners

**[JustWatch](https://www.justwatch.com/)** — The world's leading streaming guide, helping 70M+ users discover where to watch movies and shows across 130+ streaming services. JustWatch provides the challenge dataset: real anonymised behavioural data from the platform.

**[Snowflake](https://www.snowflake.com/)** — Cloud data platform where all hackathon data lives. Each team gets a dedicated Snowflake environment with compute resources and shared access to the challenge data.

**[Lightdash](https://www.lightdash.com/)** — Open-source BI tool connected to your Snowflake data. Build dashboards and visualisations for your analysis and final presentation.

**[Collate](https://www.getcollate.io/)** — Data catalog and governance platform (powered by OpenMetadata). Browse table schemas, column descriptions, data profiles, and sample data. Document your findings, build a shared glossary, and set up data quality tests. Includes a Chrome extension for metadata inside Snowflake, an AI assistant (AskCollate), and an MCP server for AI coding tools.

---

## Repo Structure

### Platforms

How to connect to and use each platform.

| Platform | Guide |
| -------- | ----- |
| [platforms/snowflake/](platforms/snowflake/) | Snowflake — credentials, warehouses, CLI setup |
| [platforms/lightdash/](platforms/lightdash/) | Lightdash — BI dashboards, AI-assisted development, CLI |
| [platforms/collate/](platforms/collate/) | Collate — data catalog, schema exploration, profiler, Chrome extension, AskCollate AI, MCP server |
| [platforms/dbt/](platforms/dbt/) | dbt — data transformations, bootstrap project, AI skills |

### Data

Everything about the challenge dataset — table schemas, tracking framework, event reference, and example queries.

| Doc | What it covers |
| --- | -------------- |
| [data/tables/events.md](data/tables/events.md) | Event table columns (shared by T1–T4) |
| [data/tables/objects.md](data/tables/objects.md) | Title/content metadata columns |
| [data/tables/packages.md](data/tables/packages.md) | Streaming service lookup columns |
| [data/events_library.md](data/events_library.md) | All event types — what each se_category/se_action means |
| [data/tracking-framework.md](data/tracking-framework.md) | Snowplow 101 — how the tracking pipeline works |
| [data/snowplow_schemas/](data/snowplow_schemas/) | JSON schemas for context columns (cc_title, cc_clickout, cc_page_type, cc_search) |
| [data/examples/](data/examples/) | Starter queries and reusable SQL patterns |

### Challenge

| Doc | What it covers |
| --- | -------------- |
| [challenge_ideas.md](challenge_ideas.md) | 6 challenge directions + tips |


## Setup env

SNOWLFAKE_API_KEY=asdpofijaspoidfjiosadf

**Setup**

```
open -e ~/.zshrc
```

**Apply**

```
source ~/.zshrc
```

**Check**

```
printenv | grep SNOWLFAKE_API_KEY
```


