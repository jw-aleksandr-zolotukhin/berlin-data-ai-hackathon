# LightDash: Getting Started

> Reference documentation for AI coding agents working with LightDash BI.
> Sources: LightDash official documentation (https://docs.lightdash.com), fetched March 2026.
> Covers project setup, data exploration, dashboards, sharing, and core concepts.

---

## Overview

LightDash is a BI tool built on top of dbt. It reads metrics, dimensions, and model metadata directly from your dbt project's YAML files, creating an explorable semantic layer over your data warehouse. There is no separate metric definition layer — everything is defined in dbt and surfaced in LightDash.

**Core architecture:**

```
Data Warehouse (BigQuery, Postgres, Snowflake, etc.)
        ↓
dbt project (.sql models + .yml definitions)
        ↓
LightDash (reads dbt metadata, generates SQL, renders charts)
```

**Primary workflow:**

1. Define dbt models with column-level YAML documentation
2. Run `lightdash dbt run` to generate Tables and Dimensions from those models
3. Add Metrics to the YAML manually or via CLI generation
4. Deploy to LightDash with `lightdash deploy`
5. Explore data using the Explore view, build charts, and organize into Dashboards

---

## Project Setup

### Prerequisites

- An existing dbt project with at least one model
- NodeJS and NPM installed (`node -v; npm -v` to verify)
- An active LightDash instance (cloud at `app.lightdash.cloud` or self-hosted)
- dbt familiarity — complete dbt's own getting started guide first
- dbt Cloud users must clone their repository locally before using the LightDash CLI

### Step 1: Install the LightDash CLI

```bash
npm install -g @lightdash/cli
```

If you encounter npm permission errors, follow the EACCES resolution guide for your OS, or use NVM (Node Version Manager) as an alternative.

### Step 2: Authenticate the CLI

Run the auto-generated login command shown in your LightDash instance:

```bash
lightdash login https://{{ lightdash_domain }} --token [your_token]
```

For LightDash Cloud, the domain is `app.lightdash.cloud`.

### Step 3: Generate Tables and Dimensions

From within your dbt project directory (the one containing `dbt_project.yml`):

```bash
lightdash dbt run
```

This documents all columns in your dbt models as explorable Dimensions and creates Tables for each model. To limit to specific models using dbt tags:

```bash
lightdash dbt run -s tag:lightdash
```

**dbt selection syntax supported:**

| Command | Effect |
|---------|--------|
| `lightdash dbt run` | All models |
| `lightdash dbt run -s my_model` | Specific model |
| `lightdash dbt run -s my_model+` | Model and its children |
| `lightdash dbt run -s +my_model` | Model and its parents |
| `lightdash dbt run -s tag:lightdash` | Models tagged `lightdash` |

### Step 4: Deploy the Project

```bash
lightdash deploy --create
```

This creates your first LightDash project using the local `profiles.yml` credentials and deploys all generated Tables.

For subsequent deploys to production:

```bash
lightdash deploy --target prod
```

### Step 5: Preview Before Deploying (Development Workflow)

Always test changes in an isolated environment before affecting production:

```bash
lightdash preview
```

This launches a temporary LightDash project scoped to your current branch. When done, destroy it and deploy the reviewed changes with `lightdash deploy`.

### Step 6: Post-Setup Configuration

After initial setup, complete these two steps:

1. **Replace personal credentials with a service account** — LightDash should connect to your warehouse via a dedicated service account, not a developer's personal login. Configure this in Project Settings.
2. **Set up automated deployment** — Replace manual `lightdash deploy` calls with a CI/CD workflow (e.g., GitHub Actions) that deploys on merge to the main branch.

---

## Connecting to a Data Warehouse

Access **Project Settings → Warehouse & dbt connection** to update connections, or **Organization Settings → All Projects → Create new** for a new project.

### Security Best Practice

Always grant LightDash **read-only** permissions on your warehouse. LightDash only reads data; write access creates unnecessary risk.

### LightDash Cloud IP Allowlisting

If your warehouse requires IP allowlisting:

| Instance | IP Address |
|----------|-----------|
| app.lightdash.cloud | 35.245.81.252 |
| eu1.lightdash.cloud | 34.79.239.130 |

### Supported Warehouses

| Warehouse | Authentication Methods | Notes |
|-----------|----------------------|-------|
| **BigQuery** | User account (Google OAuth) or service account (JSON key) | Requires `roles/bigquery.dataViewer` + `roles/bigquery.jobUser`. Default timeout: 300s, retries: 3. |
| **PostgreSQL** | Username/password | SSL modes supported. SSH tunnel available. |
| **Redshift** | Username/password | SSH tunnel available. Extended SSL options. |
| **Snowflake** | Snowflake OAuth, private key, or password | Account identifier must include org ID and account ID separated by a hyphen. Session keepalive available. |
| **Databricks** | OAuth or personal access token | Requires server hostname and HTTP path. |
| **Trino** | LDAP only | Hostname without `http://` prefix. Catalog name required. |
| **ClickHouse** | Username/password | Default port 8123. HTTPS/SSL option. |
| **Athena** | AWS access key ID + secret | Requires S3 staging directory. Workgroup optional. |

### Connecting to the dbt Project

LightDash needs access to your dbt project source to read model definitions. Four connection methods are available:

| Method | Best For | Limitations |
|--------|----------|-------------|
| **GitHub** (OAuth recommended) | Most teams | Requires OAuth app or personal access token |
| **GitLab** | GitLab users | Personal access token with `read_repository` scope |
| **Azure DevOps** | Azure users | Personal access token with Repo:Read scope |
| **Bitbucket** | Bitbucket users | HTTP access token or App Password |
| **dbt Cloud** | dbt Cloud users | Missing: write-back features, branch preview environments, auto-refresh on commit |
| **CLI** | Teams using `lightdash deploy` manually | Default for CLI-created projects |

**Git connection required fields:**

- Repository: `organization/repository` format
- Target branch (default: `main`)
- Project directory path (`/` for root, `/subfolder` for nested dbt projects)

---

## Controlling Which Tables Appear in LightDash

Navigate to **Settings → Project settings → Tables configuration** to control which dbt models are exposed as Tables.

| Option | Effect |
|--------|--------|
| Show entire project | All models with YAML documentation appear |
| Show models with these tags | Filter by dbt tags |
| Show models in this list | Manually curate which models appear |

**Adding tags to models (dbt v1.9 and earlier):**

```yaml
models:
  - name: model_name
    tags: ['lightdash']
```

**Adding tags to models (dbt v1.10+):**

```yaml
models:
  - name: model_name
    config:
      tags: ['lightdash']
```

**In the SQL file itself:**

```sql
{{ config(tags=["lightdash"]) }}
```

---

## Inviting Users

Navigate to **Organization Settings → Users & groups → Add user**. Enter the user's email and assign an organization role. The system sends an invite link via email.

**Domain-based automatic access:** Configure allowed email domains in Organization Settings to let users with matching domains join automatically without explicit invites. Generic domains (Gmail, Hotmail, etc.) are excluded.

**Default project:** Set a default project in Organization Settings. New users land here first; if they lack access, the system shows their next available project.

For detailed role definitions and permission matrices, see the [Roles & Permissions reference](https://docs.lightdash.com/references/workspace/roles).

---

## Exploring Data

### What Is an Explore?

An Explore is LightDash's primary query interface. Users open an Explore by selecting a **Table** (which maps to a dbt model), then choose Dimensions and Metrics to query. LightDash generates SQL, executes it against the warehouse, and displays results as a chart and a results table.

### The Explore Interface

The Explore view has five panels:

| Panel | Purpose |
|-------|---------|
| **Metrics and Dimensions** | Left sidebar listing all available fields from the selected Table and any joined Tables |
| **Filters** | Active filter conditions restricting the query |
| **Chart** | The rendered visualization |
| **Results** | Raw query results in tabular form |
| **SQL** | The generated SQL query for transparency and debugging |

### Running a Query: Step-by-Step

1. Select a Table from the Explore menu
2. Click a Metric (e.g., `Order count`) — this defines what to measure
3. Click one or more Dimensions (e.g., `Order month`, `Partner name`) — these define how to group results
4. Click **Run query**
5. LightDash generates and executes SQL, displays results in the Results panel and renders a chart

**Example:** To find "number of orders per month split by partner," select `Order count` (metric), `Order month` (dimension), `Partner name` (dimension), then run.

### Filtering Results

Three ways to add a filter:

1. Click **+ Add filter** in the Filters panel
2. Click the column header menu in the Results table
3. Hover over a Metric or Dimension in the sidebar and click the filter icon

Filters stack using AND logic. Empty-value filters let dashboard viewers supply their own values at view time.

### Sorting Results

- Click column header arrows for single-column sort
- Click the blue sort pill in the column header to add additional sort levels
- Drag sort pills to reorder priority
- Configure NULL placement: first, last, or database default

### Saving Charts

Charts can be saved in two locations:

| Storage Location | Behavior | Use When |
|-----------------|----------|----------|
| **Space** | Chart is independent, shareable, reusable across dashboards | Default choice. Required for pinning to project home page. Enables version history, scheduled deliveries, Google Sheets sync, and alerts. |
| **Dashboard** | Chart exists only within that dashboard | Keeping dashboards self-contained and avoiding space clutter. Cannot be reused elsewhere. |

Saved charts always re-run their query when accessed, so they always show current data.

**Saved chart features (Space-stored only):**

- Version history tracking
- Scheduled deliveries (email/Slack)
- Google Sheets synchronization
- Alert configuration

---

## Defining Tables, Dimensions, and Metrics

### Tables

Tables in LightDash map directly to dbt models. A model becomes a Table when it has a `.yml` file with column definitions. The LightDash CLI generates this YAML automatically.

**File structure (recommended):** One `.sql` file and one `.yml` file per model.

**Minimal YAML to create a Table:**

```yaml
models:
  - name: orders
    columns:
      - name: order_id
      - name: status
      - name: created_at
      - name: total_amount
```

Once deployed, this model appears as a Table in LightDash with `order_id`, `status`, `created_at`, and `total_amount` as Dimensions.

### Dimensions

Dimensions are the columns of a Table — the attributes used to segment, group, and filter data. They must correspond to actual columns in the database.

**YAML syntax (dbt v1.9 and earlier):**

```yaml
models:
  - name: orders
    columns:
      - name: status
        description: "Current order status"
        meta:
          dimension:
            label: "Order Status"
            type: string
            hidden: false
```

**YAML syntax (dbt v1.10+ / Fusion):**

```yaml
models:
  - name: orders
    columns:
      - name: status
        config:
          meta:
            dimension:
              label: "Order Status"
              type: string
```

**Native LightDash YAML:**

```yaml
type: model
name: orders
dimensions:
  - name: status
    label: "Order Status"
    description: "Current order status"
    type: string
```

#### Dimension Types

| Type | Use For |
|------|---------|
| `string` | Text values |
| `number` | Numeric values |
| `boolean` | True/false values |
| `date` | Date-only values (auto-creates day/week/month/quarter/year intervals) |
| `timestamp` | Date + time values (auto-creates raw/day/week/month/quarter/year intervals) |

#### Key Dimension Properties

| Property | Type | Purpose |
|----------|------|---------|
| `label` | string | Display name shown in the UI |
| `description` | string | Tooltip documentation |
| `type` | string | Data type (auto-detected if omitted) |
| `sql` | string | Custom SQL expression at query time |
| `hidden` | boolean | Hides from UI when `true` |
| `format` | string | Spreadsheet-style number/currency formatting |
| `compact` | string | Abbreviate values (thousands, millions) |
| `groups` | string/array | Organizes into sidebar category folders |
| `tags` | array | Programmatic categorization for API/AI filtering |
| `time_intervals` | array or `OFF` | Override default date/timestamp intervals |
| `required_attributes` | object | AND-logic access control by user attribute |
| `any_attributes` | object | OR-logic access control by user attribute |
| `colors` | object | Predefined chart colors for string values |
| `case_sensitive` | boolean | Filter case sensitivity (default: `true`) |
| `richText` | string | HTML/Markdown template with Liquid syntax |

#### Format Expression Examples

| Format | Example Output |
|--------|---------------|
| `[$]#,##0.00` | $1,427.20 |
| `#,##0.00%` | 67.89% |
| `[$]#,##0," K"` | $15 K |
| `#,##0.00" km"` | 100,000.00 km |

#### Time Interval Configuration

Date and timestamp dimensions automatically generate grouped variants. Override defaults:

```yaml
meta:
  dimension:
    type: date
    time_intervals: ['DAY', 'MONTH', 'YEAR']   # Override defaults
    # time_intervals: OFF                        # Disable all intervals
```

**Default intervals:**
- `date` type: `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`
- `timestamp` type: `RAW`, `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`

#### Additional Dimensions

Create multiple dimensions from a single column without modifying the warehouse:

```yaml
meta:
  dimension:
    type: timestamp
  additional_dimensions:
    created_at_eastern:
      type: timestamp
      sql: "CONVERT_TIMEZONE('UTC', 'America/New_York', ${created_at})"
      label: "Created At (Eastern)"
```

Use cases: different timezones, different formatting, computed columns, JSON parsing.

### Metrics

Metrics are calculations performed on Table data. They aggregate dimension values using SQL aggregate functions. Unlike dimensions (which exist per-row), metrics compute across groups of rows defined by the selected dimensions.

**YAML syntax (dbt v1.9 and earlier):**

```yaml
models:
  - name: orders
    columns:
      - name: order_id
        meta:
          metrics:
            order_count:
              type: count_distinct
              label: "Number of Orders"
              description: "Count of unique order IDs"
```

**Native LightDash YAML:**

```yaml
type: model
name: orders
metrics:
  - name: order_count
    type: count_distinct
    sql: "${order_id}"
    label: "Number of Orders"
```

#### Metric Types

**Aggregate metrics** (operate on dimension columns):

| Type | Description |
|------|-------------|
| `count` | Count of all values in the dimension |
| `count_distinct` | Count of unique values |
| `sum` | Sum of all values |
| `average` | Mean of all values |
| `median` | 50th percentile using `PERCENTILE_CONT(0.5)` |
| `percentile` | Custom percentile (requires `percentile` parameter) |
| `min` | Minimum value |
| `max` | Maximum value |
| `sum_distinct` (Beta) | Sum with deduplication by key fields |
| `average_distinct` (Beta) | Average with deduplication by key fields |

**Non-aggregate metrics** (operate on other metrics, no aggregation):

| Type | Description |
|------|-------------|
| `number` | Arithmetic calculation on one or more metrics |
| `boolean` | Returns TRUE/FALSE from metric comparison |
| `date` | Returns a date value |
| `string` | Returns a string value |

**Post-calculation metrics** (experimental, computed after aggregations):

| Type | Description |
|------|-------------|
| `percent_of_previous` | Current row value as % of prior row |
| `percent_of_total` | Value as % of total result set |
| `running_total` | Cumulative aggregation down the result set |

#### Key Metric Properties

| Property | Required | Purpose |
|----------|----------|---------|
| `type` | Yes | Metric category (see types above) |
| `sql` | No | Custom SQL; reference dimensions as `${dimension_name}` |
| `label` | No | Display name |
| `description` | No | Tooltip documentation |
| `format` | No | Spreadsheet-style formatting |
| `compact` | No | Value abbreviation |
| `hidden` | No | Hide from UI |
| `filters` | No | Automatically applied WHERE conditions |
| `groups` | No | Sidebar organization |
| `tags` | No | Programmatic categorization |
| `show_underlying_values` | No | Limit drill-down fields |
| `richText` | No | HTML/Markdown display template |

#### Metric Filters

Filters defined on a metric apply automatically in SQL and cannot be removed by users in the UI. They use AND logic.

```yaml
metrics:
  paid_order_count:
    type: count_distinct
    filters:
      - status: "paid"
      - amount: "> 0"
```

**Filter operator reference:**

| Syntax | Meaning |
|--------|---------|
| `field: "value"` | Equals |
| `field: "!value"` | Not equals |
| `field: "%value%"` | Contains |
| `field: "value%"` | Starts with |
| `field: "> 4"` | Greater than |
| `field: ">= 4"` | Greater than or equal |
| `field: "< 4"` | Less than |
| `field: "<= 4"` | Less than or equal |
| `field: "inThePast 30 days"` | Relative date (past) |
| `field: "inTheNext 14 months"` | Relative date (future) |
| `field: "null"` | Is null |
| `field: "!null"` | Is not null |
| `field: "true"` | Is true |
| `field: [a, b, c]` | In list (OR conditions) |

---

## Explores (Advanced Table Configuration)

Explores allow a single dbt model to appear as multiple distinct Tables in LightDash, each with different joins, fields, filters, or access controls. This lets you serve different audiences (teams, roles, use cases) from the same underlying data without duplicating dbt models.

### Use Cases

- Present a `deals` model as "Deals (Basic)" to SDRs and "Deals + Full Account Data" to executives
- Hide PII fields from some users via `required_attributes`
- Create team-specific table views with pre-configured joins

### YAML Structure

```yaml
models:
  - name: deals
    meta:
      explores:
        deals_basic:
          label: "Deals (Basic)"
          description: "Standard deals view for SDRs"

        deals_with_accounts:
          label: "Deals w/ Accounts"
          description: "Deals joined with account data"
          joins:
            - join: accounts
              relationship: many_to_one
              sql_on: "${deals.account_id} = ${accounts.account_id}"
              fields: [account_name, account_tier]

        deals_exec:
          label: "Deals (Executive View)"
          description: "Full account data, restricted to executives"
          joins:
            - join: accounts
              relationship: many_to_one
              sql_on: "${deals.account_id} = ${accounts.account_id}"
          required_attributes:
            role: "executive"
```

### Explore-Scoped Additional Dimensions

Define fields that only exist within a specific Explore, useful for combining base and joined table data:

```yaml
explores:
  deals_with_accounts:
    additional_dimensions:
      combined_region:
        type: string
        sql: "COALESCE(${deals.region}, ${accounts.region})"
        label: "Effective Region"
```

Supported properties for additional dimensions: `type`, `sql`, `label`, `description`, `hidden`, `format`, `time_intervals`, `groups`, `required_attributes`.

---

## Dashboards

### What Is a Dashboard?

A Dashboard consolidates multiple related charts and supporting content into a unified view. Dashboards are built from **Tiles**, which can contain charts, text, or embedded media.

### Creating a Dashboard

1. Click **New** in the navigation bar
2. Enter a name, optionally add a description, and click **Create**
3. Click **Add tile** to add content
4. Drag and resize tiles to arrange the layout
5. Click **Save**

### Tile Types

| Tile Type | Content |
|-----------|---------|
| **Chart** | A new chart (saved to this dashboard only) or an existing saved chart from a Space |
| **Markdown** | Text with formatting, code blocks, headers, images. Supports iframes for embedding external content (Notion, CRM, etc.) |
| **Loom video** | Embedded Loom video for instructional content |

**Responsive image handling in Markdown tiles:**

```html
<img src="your-image-url" style="max-width:100%;height:auto;" />
```

### Dashboard Filters

Filters on a dashboard restrict data across all tiles simultaneously. Filter options:

- **Standard filters**: Users can modify values at view time
- **Empty-value filters**: Viewers must select a value before any data loads
- **Required filters**: Dashboard will not execute queries until a value is set

Multiple filters stack with AND logic.

### Dashboard Tabs

Tabs segment a single dashboard into themed sections. Use tabs to:
- Separate revenue analytics from retention metrics
- Create an executive summary tab alongside a detailed operations tab
- Organize by team or audience

Tab management: rename, remove, and move content between tabs from the tab menu.

### Sharing Dashboards

Dashboards are shared via URL (copy from the browser) or via the **Share** button in the dashboard header. Shared links preserve the active tab state. Embedded dashboards include all tabs as a single consolidated view.

### Tile Display Options

- Hide tile headers for a cleaner, presentation-style layout
- Apply background colors to Markdown tiles for visual structure

---

## Sharing and Collaboration

### Three Sharing Methods

#### 1. Draft URL (Live Explore State)

While exploring data, copy the browser URL. Anyone with access to the same LightDash project can open that URL and see the identical Explore view state (same fields, filters, chart type).

A built-in link shortener is available for lengthy URLs.

#### 2. Saved Charts

Save a chart to a Space to make it persistently accessible to all project members with Space access. Saved charts:
- Are browsable via **Browse → All saved charts**
- Can be shared via direct URL
- Re-run their query on each access (always current data)
- Support version history, scheduled deliveries, Google Sheets sync, and alerts (Space-stored only)

#### 3. Results Download and Export

From any chart or results table, use the export icon to download:

**Chart export formats:** JPEG, PNG, SVG, PDF, JSON (opaque or transparent backgrounds)

**Data export formats:** CSV, Excel spreadsheet, Google Sheets (if configured in project settings)

Both file download and clipboard copy are supported.

### Spaces

Spaces are containers for organizing saved charts and dashboards. Access control operates at the Space level — users with access to a Space can view all charts and dashboards within it.

---

## Key Concepts Glossary

| Term | Definition |
|------|-----------|
| **Table** | A queryable entity in LightDash corresponding to a dbt model with YAML documentation. Contains Dimensions and Metrics. |
| **Dimension** | A column-level field used to segment, filter, and group data. Defined in dbt `.yml` files under the `meta.dimension` block. |
| **Metric** | A calculated aggregate field (count, sum, average, etc.) defined in dbt `.yml` files under `meta.metrics`. Cannot exist without a dimension to aggregate. |
| **Explore** | The LightDash query interface built around a Table. Also refers to a named variation of a Table (with specific joins, fields, and access rules). |
| **Chart** | A saved visualization created in the Explore view. Saved to either a Space (reusable) or a Dashboard (exclusive). |
| **Dashboard** | A collection of Tiles (charts, text, media) organized into a unified view. Supports tabs, filters, and sharing. |
| **Tile** | A building block of a Dashboard. Can be a chart, Markdown content, or an embedded Loom video. |
| **Space** | An organizational container for saved charts and dashboards. Access control is applied at the Space level. |
| **dbt project** | The upstream source of truth. LightDash reads model SQL, column YAML definitions, and metadata from here. |
| **Semantic Layer** | The set of Tables, Dimensions, Metrics, and Explores that LightDash exposes to users. Defined entirely in dbt YAML. |
| **LightDash CLI** | The `@lightdash/cli` npm package. Used to generate YAML, preview changes, and deploy projects. |
| **`lightdash dbt run`** | CLI command that generates YAML documentation for dbt model columns and creates Tables/Dimensions in LightDash. |
| **`lightdash preview`** | CLI command that spins up a temporary LightDash project from the current branch for safe testing. |
| **`lightdash deploy`** | CLI command that deploys the current dbt project state to a LightDash project. Use `--create` for the first deploy. |
| **Additional Dimensions** | Derived dimensions created from a single column without modifying the warehouse (e.g., timezone conversions, computed fields). |
| **Post-calculation metric** | An experimental metric type (`percent_of_previous`, `percent_of_total`, `running_total`) computed after all aggregations complete. |
| **`required_attributes`** | Access control property on dimensions, metrics, and explores. Uses AND logic — all specified user attributes must match. |
| **`any_attributes`** | Access control property using OR logic — at least one specified user attribute must match. |
| **Time intervals** | Auto-generated grouped variants of date/timestamp dimensions (DAY, WEEK, MONTH, QUARTER, YEAR, RAW). Configurable per dimension. |

---

## Quick Reference: CLI Commands

| Command | Purpose |
|---------|---------|
| `npm install -g @lightdash/cli` | Install the CLI |
| `lightdash login <url> --token <token>` | Authenticate |
| `lightdash dbt run` | Generate YAML for all models and sync to LightDash |
| `lightdash dbt run -s <model>` | Generate YAML for a specific model |
| `lightdash dbt run -s tag:<tag>` | Generate YAML for tagged models |
| `lightdash preview` | Start a temporary development environment |
| `lightdash deploy --create` | Create and deploy the first project |
| `lightdash deploy` | Deploy to an existing project |
| `lightdash deploy --target prod` | Deploy to a specific dbt target |

---

## Quick Reference: YAML Structure (Complete Example)

```yaml
# dbt v1.9 and earlier syntax
models:
  - name: orders
    description: "Order-level data from the orders table"
    meta:
      explores:
        orders_by_status:
          label: "Orders by Status"
          joins:
            - join: customers
              relationship: many_to_one
              sql_on: "${orders.customer_id} = ${customers.customer_id}"
              fields: [customer_name, customer_segment]

    columns:
      - name: order_id
        description: "Unique identifier for each order"
        meta:
          dimension:
            hidden: true
          metrics:
            order_count:
              type: count_distinct
              label: "Number of Orders"

      - name: status
        description: "Current order status"
        meta:
          dimension:
            label: "Order Status"
            type: string
            groups: "Order Details"
          metrics:
            paid_order_count:
              type: count_distinct
              label: "Paid Orders"
              filters:
                - status: "paid"

      - name: created_at
        description: "Timestamp when the order was placed"
        meta:
          dimension:
            label: "Order Date"
            type: timestamp
            time_intervals: ['DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']

      - name: total_amount
        description: "Total order value in USD"
        meta:
          dimension:
            label: "Order Total"
            type: number
            format: "[$]#,##0.00"
          metrics:
            total_revenue:
              type: sum
              label: "Total Revenue"
              format: "[$]#,##0.00"
            average_order_value:
              type: average
              label: "Average Order Value"
              format: "[$]#,##0.00"
```

---

## Cross-References

- LightDash documentation index: https://docs.lightdash.com/llms.txt
- Dimensions reference: https://docs.lightdash.com/references/dimensions.md
- Metrics reference: https://docs.lightdash.com/references/metrics.md
- Tables reference: https://docs.lightdash.com/references/tables.md
- Joins reference: https://docs.lightdash.com/references/joins.md
- Explores guide: https://docs.lightdash.com/guides/developer/explores.md
- Roles and permissions: https://docs.lightdash.com/references/workspace/roles
- Semantic layer guide: https://docs.lightdash.com/guides/lightdash-semantic-layer.md
