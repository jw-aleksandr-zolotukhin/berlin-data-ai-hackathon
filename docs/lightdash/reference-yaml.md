# LightDash: YAML Reference

> Comprehensive YAML configuration reference for LightDash semantic layer definitions.
> Sources: LightDash official documentation — dimensions, metrics, tables, joins, and lightdash.config.yml references (docs.lightdash.com/references/).
> Use when writing or reviewing LightDash YAML configurations for dbt projects or standalone LightDash YAML projects.

---

## Table of Contents

1. [YAML Syntax Variants](#yaml-syntax-variants)
2. [Dimensions](#dimensions)
3. [Metrics](#metrics)
4. [Tables Configuration](#tables-configuration)
5. [Joins](#joins)
6. [lightdash.config.yml](#lightdashdashconfigyml)
7. [Standalone LightDash YAML (No dbt)](#standalone-lightdash-yaml-no-dbt)
8. [Complete YAML Examples](#complete-yaml-examples)

---

## YAML Syntax Variants

LightDash supports three syntaxes depending on your setup. Choose the one that matches your dbt version or project type.

| Variant | When to Use | Meta Location |
|---|---|---|
| **dbt v1.9 and earlier** | dbt projects on v1.9 or below | Under `meta:` directly on column or model |
| **dbt v1.10+ / Fusion** | dbt projects on v1.10+ or Fusion | Under `config.meta:` on column or model |
| **Lightdash YAML** | Standalone (no dbt), or lightdash native files | Top-level fields in `.yml` files under `./lightdash/models/` |

### dbt v1.9 and earlier — skeleton

```yaml
models:
  - name: orders
    meta:
      # table-level config here
    columns:
      - name: user_id
        meta:
          dimension:
            # dimension config here
          metrics:
            my_metric:
              # metric config here
```

### dbt v1.10+ / Fusion — skeleton

```yaml
models:
  - name: orders
    config:
      meta:
        # table-level config here
    columns:
      - name: user_id
        config:
          meta:
            dimension:
              # dimension config here
            metrics:
              my_metric:
                # metric config here
```

### Standalone Lightdash YAML — skeleton

```yaml
type: model
name: orders
sql_from: DATABASE.SCHEMA.ORDERS

# table-level config here

dimensions:
  - name: user_id
    sql: ${TABLE}.USER_ID
    type: string

metrics:
  my_metric:
    type: count_distinct
    sql: ${TABLE}.user_id
```

---

## Dimensions

Dimensions represent individual attributes of a row in your data model. Types are auto-detected from the warehouse but can be overridden.

### Dimension Types

| Type | Description |
|---|---|
| `string` | Text values |
| `number` | Numeric values |
| `boolean` | True/False values |
| `date` | Date values (no time component) |
| `timestamp` | Date + time values |

### All Dimension Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `type` | string | auto-detected | Overrides warehouse-inferred type |
| `label` | string | column name | Custom display name shown in UI |
| `description` | string | — | Documentation shown on hover |
| `sql` | string | column reference | Custom SQL expression |
| `hidden` | boolean | `false` | Hide from sidebar and drilldowns |
| `format` | string | — | Spreadsheet-style format expression (overrides legacy `round`/`format`) |
| `round` | number | — | Legacy: decimal places to round to |
| `compact` | string | — | Compact notation: `thousands`, `millions`, `billions`, `trillions`, etc. |
| `groups` | string[] | — | Sidebar group path, up to 3 levels: `['Finance', 'Revenue']` |
| `tags` | string[] | — | Programmatic categorization for API filtering and AI agents |
| `urls` | array | — | Clickable links rendered on dimension values |
| `colors` | object | — | Per-value color map for string dimensions in charts |
| `richText` | string | — | Markdown/HTML Liquid template for table cell display |
| `image` | object | — | Display images in table cells |
| `time_intervals` | array or `OFF` | see below | Date/time granularities to expose |
| `case_sensitive` | boolean | `true` | Controls string filter behavior |
| `required_attributes` | object | — | AND-logic user attribute access control |
| `any_attributes` | object | — | OR-logic user attribute access control |
| `additional_dimensions` | object | — | Derive extra dimensions from the same column |

### Time Intervals

**Default intervals by type:**
- `date`: `['DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']`
- `timestamp`: `['RAW', 'DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']`

**All available interval values:**

| Category | Values |
|---|---|
| Truncations | `RAW`, `YEAR`, `QUARTER`, `MONTH`, `WEEK`, `DAY`, `HOUR`, `MINUTE`, `SECOND`, `MILLISECOND` |
| Numeric extractions | `DAY_OF_WEEK_INDEX`, `DAY_OF_MONTH_NUM`, `WEEK_NUM`, `MONTH_NUM`, `QUARTER_NUM`, `YEAR_NUM`, `MINUTE_OF_HOUR_NUM`, `HOUR_OF_DAY_NUM` |
| String extractions | `DAY_OF_WEEK_NAME`, `MONTH_NAME`, `QUARTER_NAME` |

Disable all intervals: `time_intervals: OFF`

Reference a specific interval in SQL: `${dimension_name_day}`, `${dimension_name_month}`, etc.

### Format Expressions (Spreadsheet-style)

| Pattern | Output | Use Case |
|---|---|---|
| `[$$]#,##0.00` | $15,430.75 | USD currency |
| `[$£]#,##0.00` | £15,430.75 | GBP currency |
| `#,##0.00%` | 67.58% | Percentage |
| `[$$]#,##0,"K"` | $15K | Compact currency |
| `"Delivered in "@` | Delivered in 3 | Custom text suffix |
| `m/d/yyyy` | 9/5/2023 | Date display |
| `m/d/yyyy h:mm AM/PM` | 9/5/2023 3:45 PM | Date-time display |

### Compact Values

| Value | Suffix |
|---|---|
| `thousands` | K |
| `millions` | M |
| `billions` | B |
| `trillions` | T |
| `kilobytes`, `megabytes`, `gigabytes`, `terabytes`, `petabytes` | KB, MB, GB, TB, PB |

### URL Templating (Liquid syntax)

| Variable | Value |
|---|---|
| `${ value.formatted }` | Display value (formatted) |
| `${ value.raw }` | Raw database value |
| `${ row.table_name.column_name.raw }` | Another column's raw value |

Available filters: `url_encode`, `downcase`, `append`

### Access Control

```yaml
# AND logic — user must have ALL attributes
required_attributes:
  is_admin: "true"
  department: "finance"

# OR logic — user must have AT LEAST ONE matching attribute
any_attributes:
  department: ["hr", "finance"]
  role: "manager"
```

### Dimension YAML Examples

#### Basic types

```yaml
# dbt v1.9 and earlier
columns:
  - name: status
    meta:
      dimension:
        type: string
        label: "Order Status"
        description: "Current status of the order"

  - name: revenue
    meta:
      dimension:
        type: number
        label: "Revenue (USD)"
        format: '[$$]#,##0.00'
        round: 2

  - name: created_at
    meta:
      dimension:
        type: timestamp
        time_intervals: ['RAW', 'DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']

  - name: is_active
    meta:
      dimension:
        type: boolean
        label: "Is Active"
        hidden: false
```

#### Date dimension with custom intervals

```yaml
columns:
  - name: order_date
    meta:
      dimension:
        type: date
        label: "Order Date"
        time_intervals: ['DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']
        groups: ['Time', 'Order Dates']
```

#### String dimension with colors and case sensitivity

```yaml
columns:
  - name: order_status
    meta:
      dimension:
        type: string
        case_sensitive: false
        colors:
          "placed": "#e6fa0f"
          "completed": "#558B2F"
          "cancelled": "#D32F2F"
```

#### Dimension with URL

```yaml
columns:
  - name: customer_id
    meta:
      dimension:
        type: string
        urls:
          - label: "View in CRM"
            url: "https://crm.example.com/customers/${ value.raw | url_encode }"
```

#### Dimension with rich text

```yaml
columns:
  - name: health_score
    meta:
      dimension:
        type: number
        richText: |
          {% if value.raw >= 80 %}
          **Good** — ${ value.formatted }
          {% elsif value.raw >= 50 %}
          **Fair** — ${ value.formatted }
          {% else %}
          **Poor** — ${ value.formatted }
          {% endif %}
```

#### Image dimension

```yaml
columns:
  - name: product_sku
    meta:
      dimension:
        type: string
        image:
          url: "https://cdn.example.com/products/${ value.raw }.jpg"
          width: 80
          height: 80
          fit: "cover"   # cover | contain | fill | none
```

#### Hidden dimension (used in SQL only)

```yaml
columns:
  - name: internal_flag
    meta:
      dimension:
        type: boolean
        hidden: true
```

#### Access-controlled dimension

```yaml
columns:
  - name: salary
    meta:
      dimension:
        type: number
        label: "Salary"
        required_attributes:
          is_hr: "true"
```

#### Additional dimensions (derive multiple from one column)

```yaml
columns:
  - name: revenue
    meta:
      dimension:
        type: number
        label: "Revenue"
      additional_dimensions:
        revenue_thousands:
          type: number
          label: "Revenue (K)"
          format: '#,##0," K"'
          sql: ${revenue}
        revenue_millions:
          type: number
          label: "Revenue (M)"
          format: '#,##0,,"M"'
          sql: ${revenue}
```

#### Tags

```yaml
columns:
  - name: mrr
    meta:
      dimension:
        type: number
        tags: ["core", "finance", "revenue"]
```

---

## Metrics

Metrics are aggregate or computed values derived from your data. They are defined at the column level (for aggregates tied to a column) or at the model level (for computed metrics).

### Metric Categories

| Category | Description | SQL Reference Rule |
|---|---|---|
| **Aggregate** | Perform SQL aggregations (COUNT, SUM, AVG, etc.) | Can only reference **dimensions** |
| **Non-Aggregate** | Derived calculations on top of aggregates | Can only reference **metrics** (not dimensions) |
| **Post-Calculation** | Computed after query results (window functions) | Can only reference aggregate or non-aggregate metrics |

### All Metric Types

| Type | Category | Description |
|---|---|---|
| `count` | Aggregate | SQL `COUNT()` |
| `count_distinct` | Aggregate | SQL `COUNT(DISTINCT ...)` |
| `sum` | Aggregate | SQL `SUM()` |
| `sum_distinct` | Aggregate (Beta) | Sum with deduplication by specified keys |
| `average` | Aggregate | SQL `AVG()` |
| `average_distinct` | Aggregate (Beta) | Average with deduplication by specified keys |
| `min` | Aggregate | SQL `MIN()` |
| `max` | Aggregate | SQL `MAX()` |
| `percentile` | Aggregate | `PERCENTILE_CONT` with configurable percentile value |
| `median` | Aggregate | 50th percentile (alias for `percentile: 50`) |
| `number` | Non-Aggregate | Numeric formula referencing other metrics |
| `boolean` | Non-Aggregate | TRUE/FALSE expression on aggregations |
| `string` | Non-Aggregate | String aggregation (e.g., `GROUP_CONCAT`) |
| `date` | Non-Aggregate | Date expression on aggregations |
| `percent_of_previous` | Post-Calculation (experimental) | Current row value as % of previous row |
| `percent_of_total` | Post-Calculation (experimental) | Current row value as % of total column |
| `running_total` | Post-Calculation (experimental) | Cumulative running total |

### All Metric Parameters

| Parameter | Required | Type | Description |
|---|---|---|---|
| `type` | Yes | string | One of the metric types above |
| `label` | No | string | Custom display name in UI |
| `description` | No | string | Documentation shown on hover |
| `sql` | No | string | Custom SQL (dimensions for aggregates; metrics for non-aggregates) |
| `hidden` | No | boolean | Hide from LightDash UI |
| `format` | No | string | Spreadsheet-style format expression |
| `round` | No | number | Legacy: decimal places |
| `compact` | No | string | Compact notation (`thousands`, `millions`, etc.) |
| `groups` | No | string[] | Sidebar organization |
| `tags` | No | string[] | Programmatic categorization |
| `urls` | No | array | Clickable links on metric values |
| `richText` | No | string | Liquid template for table cell display |
| `show_underlying_values` | No | string[] | Dimensions shown in drill-down |
| `filters` | No | array | Automatic filters applied to this metric |
| `distinct_keys` | No | string[] | Required for `sum_distinct`/`average_distinct` |
| `percentile` | No | number | Required for `percentile` type (0–100) |

### Filters on Metrics

Filters narrow the rows included in the aggregation. Only valid on aggregate metrics.

**Supported operators:** `=`, `!=`, `>`, `<`, `>=`, `<=`, `contains`, `starts_with`, `ends_with`, `null`, `!null`, list values, `inThePast N days/months`, `inTheNext N days/months`

```yaml
metrics:
  count_active_users:
    type: count_distinct
    filters:
      - is_closed_account: false
      - web_sessions.is_bot_user: false

  sales_last_30_days:
    type: sum
    filters:
      - order_date: "inThePast 30 days"
```

### Metric YAML Examples

#### Column-level aggregate metrics

```yaml
# dbt v1.9 and earlier
columns:
  - name: user_id
    meta:
      metrics:
        total_users:
          type: count
        distinct_users:
          type: count_distinct
          label: "Unique Users"
          description: "Count of distinct user IDs"

  - name: revenue
    meta:
      metrics:
        total_revenue:
          type: sum
          label: "Total Revenue"
          format: '[$$]#,##0.00'
        avg_revenue:
          type: average
          label: "Average Revenue"
          round: 2
        max_revenue:
          type: max
        min_revenue:
          type: min
```

#### Percentile and median

```yaml
columns:
  - name: order_value
    meta:
      metrics:
        p90_order_value:
          type: percentile
          percentile: 90
          label: "P90 Order Value"
        median_order_value:
          type: median
          label: "Median Order Value"
```

#### sum_distinct with deduplication keys

```yaml
columns:
  - name: order_shipping_cost
    meta:
      metrics:
        total_shipping_cost:
          type: sum_distinct
          sql: ${TABLE}.order_shipping_cost
          distinct_keys: [order_id, warehouse_location]
          label: "Total Shipping Cost (deduplicated)"
```

#### Custom SQL in aggregate metric

```yaml
columns:
  - name: user_id
    meta:
      metrics:
        num_7d_active_users:
          type: count_distinct
          sql: 'IF(${is_7d_active}, ${user_id}, NULL)'
          label: "7-Day Active Users"
```

#### Model-level non-aggregate metrics (reference other metrics)

```yaml
# dbt v1.9 and earlier
models:
  - name: orders
    meta:
      metrics:
        gross_margin_percent:
          type: number
          sql: '(${total_margin} / NULLIF(${total_sale}, 0))'
          format: '0.00%'
          label: "Gross Margin %"

        revenue_per_user:
          type: number
          sql: '${sum_revenue} / NULLIF(${distinct_users}, 0)'
          label: "Revenue per User"

        has_revenue:
          type: boolean
          sql: '${total_revenue} > 0'
          label: "Has Revenue"
```

#### dbt v1.10+ model-level metrics

```yaml
models:
  - name: orders
    config:
      meta:
        metrics:
          gross_margin_percent:
            type: number
            sql: '(${total_margin} / NULLIF(${total_sale}, 0))'
            format: '0.00%'
```

#### Post-calculation metrics (experimental)

```yaml
models:
  - name: revenue_by_month
    meta:
      metrics:
        revenue_percent_of_total:
          type: percent_of_total
          sql: ${total_revenue}
          format: '0.00%'
          label: "Revenue % of Total"

        running_revenue:
          type: running_total
          sql: ${total_revenue}
          label: "Running Revenue"

        revenue_percent_of_prev:
          type: percent_of_previous
          sql: ${total_revenue}
          format: '0.00%'
          label: "Revenue % vs Previous"
```

#### Metric with drill-down control

```yaml
columns:
  - name: order_id
    meta:
      metrics:
        total_orders:
          type: count
          show_underlying_values:
            - order_id
            - customer_id
            - orders.status
```

#### Metric with rich text

```yaml
columns:
  - name: clv
    meta:
      metrics:
        average_clv:
          type: average
          label: "Average CLV"
          richText: |
            {% if value.raw >= 100 %}
            **Excellent** — ${ value.formatted }
            {% else %}
            **Low** — ${ value.formatted }
            {% endif %}
```

#### Metric with tags

```yaml
columns:
  - name: revenue
    meta:
      metrics:
        total_revenue:
          type: sum
          tags: ["core", "finance"]
```

---

## Tables Configuration

Table-level (model-level) configuration controls how LightDash presents the model in the UI and applies global filters.

### All Table Parameters

| Parameter | Type | Description |
|---|---|---|
| `label` | string | Display name in UI instead of model name |
| `description` | string | Model description |
| `order_fields_by` | `index` \| `label` | Sort order for fields in the sidebar |
| `group_label` | string | Groups tables sharing the same label in sidebar |
| `sql_from` | string | Override default dbt relation name with a custom table reference |
| `sql_filter` / `sql_where` | string | Permanent WHERE clause applied to all queries (row-level security) |
| `primary_key` | string \| string[] | Column(s) uniquely identifying each row |
| `required_attributes` | object | AND-logic user attribute access control |
| `any_attributes` | object | OR-logic user attribute access control |
| `case_sensitive` | boolean | Default case sensitivity for string filters |
| `default_filters` | array | Pre-populated filters when the table is opened |
| `default_show_underlying_values` | array | Default fields in "View underlying data" modal |
| `joins` | array | Join other models to this table |
| `metrics` | object | Model-level metric definitions |
| `sets` | object | Reusable field collections |
| `explores` | object | Multiple table explores from one model |
| `parameters` | object | Model-level parameters for SQL templating |
| `group_details` | object | Descriptions for dimension/metric groups |

### sql_filter (Row-Level Security)

```yaml
meta:
  # Static filter
  sql_filter: ${TABLE}.sales_region = 'EMEA'

  # Dynamic filter from user attributes
  sql_filter: ${TABLE}.sales_region IN (${lightdash.attributes.sales_region})

  # Date-based filter
  sql_filter: ${date_dimension} >= '2025-01-01'
```

### Primary Key

```yaml
meta:
  # Single column
  primary_key: user_id

  # Composite key
  primary_key: [order_id, item_id]
```

### Default Filters

```yaml
meta:
  default_filters:
    - date: 'inThePast 14 days'
      required: true
    - status: "completed"
```

**Supported default filter operators:** `is`, `is not`, `between`, `contains`, `does not contain`, `starts with`, `ends with`, `>`, `>=`, `<`, `<=`, `inThePast`, `inTheNext`, `null`, `!null`, `empty`, `!empty`, `true`, `!true`, `in list`

### Sets (Reusable Field Collections)

```yaml
meta:
  sets:
    core_user_fields:
      fields:
        - user_id
        - user_name
        - email
        - created_at
    order_summary_fields:
      fields:
        - order_id
        - status
        - total_amount
        - orders.customer_id    # cross-table reference uses dot notation
```

Reference in joins: `fields: [core_user_fields*]`
Exclude a field: `fields: [core_user_fields*, -email]`

### Explores (Multiple Explore Views per Model)

```yaml
meta:
  explores:
    deals_accounts:
      label: 'Deals with Accounts'
      description: "Deals table joined with account details"
      required_attributes:
        is_exec: "true"
      joins:
        - join: accounts
          relationship: many-to-one
          sql_on: ${deals.account_id} = ${accounts.account_id}
```

### Parameters (SQL Templating)

```yaml
meta:
  parameters:
    region:
      label: "Region"
      description: "Filter data by region"
      options:
        - "EMEA"
        - "AMER"
        - "APAC"
      default: ["EMEA", "AMER"]
      multiple: true

    min_order_value:
      label: "Minimum Order Value"
      type: "number"
      options:
        - 100
        - 500
        - 1000
      default: 500

    department:
      label: "Department"
      options_from_dimension:
        model: "employees"
        dimension: "department"
```

Reference in SQL: `${lightdash.parameters.model_name.parameter_name}` or `${ld.parameters.model_name.parameter_name}`

### Full Table Configuration Examples

#### dbt v1.9 and earlier

```yaml
models:
  - name: users
    meta:
      label: 'App Users'
      description: "All registered application users"
      order_fields_by: 'label'
      group_label: 'Mobile App'
      sql_filter: ${TABLE}.sales_region IN (${lightdash.attributes.sales_region})
      primary_key: user_id
      case_sensitive: false
      default_filters:
        - created_at: 'inThePast 90 days'
      default_show_underlying_values:
        - user_id
        - email
        - created_at
      sets:
        event_fields:
          fields:
            - user_id
            - event_type
            - event_timestamp
      joins:
        - join: events
          sql_on: ${users.user_id} = ${events.user_id}
          fields: [event_fields*]
          relationship: one-to-many
      required_attributes:
        product_team: 'Mobile'
```

#### dbt v1.10+ / Fusion

```yaml
models:
  - name: users
    config:
      meta:
        label: 'App Users'
        order_fields_by: 'label'
        group_label: 'Mobile App'
        sql_filter: ${TABLE}.sales_region IN (${lightdash.attributes.sales_region})
        primary_key: user_id
        joins:
          - join: events
            sql_on: ${users.user_id} = ${events.user_id}
            relationship: one-to-many
        required_attributes:
          product_team: 'Mobile'
```

---

## Joins

Joins connect other models to a base table, making their dimensions and metrics available together in the Explorer.

### All Join Parameters

| Parameter | Required | Type | Default | Description |
|---|---|---|---|---|
| `join` | Yes | string | — | Name of the model to join |
| `sql_on` | Yes | string | — | SQL join condition using `${table.column}` syntax |
| `type` | No | string | `left` | Join type: `inner`, `left`, `right`, `full` |
| `label` | No | string | model name | Display name for the joined model in UI |
| `alias` | No | string | — | Identifier for joining the same model twice; must be lowercase, no spaces |
| `fields` | No | string[] | all fields | Subset of fields to expose from the joined model |
| `relationship` | No | string | — | Cardinality: `one-to-many`, `many-to-one`, `one-to-one`, `many-to-many` |
| `always` | No | boolean | `false` | Include this join in every query even if no fields are selected |
| `hidden` | No | boolean | `false` | Hide joined table columns from sidebar (table still independently explorable) |
| `description` | No | string | — | Override the joined model's description |

### Join Type Behavior

| Type | Returns |
|---|---|
| `left` (default) | All rows from the base table; matching rows from joined table |
| `inner` | Only rows with matches in both tables |
| `right` | All rows from the joined table; matching rows from base table |
| `full` | All rows from both tables |

### Join YAML Examples

#### Basic left join

```yaml
# dbt v1.9 and earlier
models:
  - name: orders
    meta:
      primary_key: order_id
      joins:
        - join: customers
          sql_on: ${orders.customer_id} = ${customers.customer_id}
          type: left
          relationship: many-to-one
```

#### Inner join with field subset

```yaml
models:
  - name: accounts
    meta:
      primary_key: id
      joins:
        - join: deals
          type: inner
          sql_on: ${accounts.id} = ${deals.account_id}
          fields: [unique_deals, new_deals, won_deals, lost_deals, stage]
          relationship: one-to-many
```

#### Join with label and description override

```yaml
joins:
  - join: users
    label: "Message Sender"
    description: "User who sent the message"
    sql_on: ${messages.sent_by} = ${users.user_id}
    relationship: many-to-one
```

#### Same model joined twice (alias required)

```yaml
joins:
  - join: users
    alias: sender
    label: "Sender"
    sql_on: ${messages.sent_by} = ${sender.user_id}
    relationship: many-to-one

  - join: users
    alias: recipient
    label: "Recipient"
    sql_on: ${messages.sent_to} = ${recipient.user_id}
    relationship: many-to-one
```

#### Always-on join

```yaml
joins:
  - join: account_context
    sql_on: ${orders.account_id} = ${account_context.account_id}
    always: true
    relationship: many-to-one
```

#### Hidden bridge table join (many-to-many via bridge)

```yaml
joins:
  - join: map_users_organizations
    sql_on: ${users.user_id} = ${map_users_organizations.user_id}
    hidden: true
  - join: organizations
    sql_on: ${organizations.organization_id} = ${map_users_organizations.organization_id}
    relationship: many-to-many
```

#### Join with row-level security in sql_on

```yaml
joins:
  - join: subscriptions
    sql_on: >
      ${subscriptions.user_id} = ${users.user_id}
      AND ${subscriptions.region} IN (${lightdash.attributes.allowed_regions})
    relationship: one-to-many
```

#### Using joined fields in metric filters

```yaml
joins:
  - join: subscriptions
    sql_on: ${subscriptions.user_id} = ${users.user_id} AND ${subscriptions.is_active}
    relationship: one-to-many

metrics:
  num_unique_premium_users:
    type: count_distinct
    filters:
      - subscriptions.plan: "premium"
```

#### dbt v1.10+ / Fusion joins

```yaml
models:
  - name: accounts
    config:
      meta:
        primary_key: id
        joins:
          - join: deals
            type: left
            sql_on: ${accounts.id} = ${deals.account_id}
            fields: [unique_deals, new_deals, stage]
            relationship: one-to-many
```

#### Lightdash YAML joins

```yaml
type: model
name: accounts

primary_key: id

joins:
  - join: deals
    type: left
    sql_on: ${accounts.id} = ${deals.account_id}
    fields: [unique_deals, new_deals, stage]
    relationship: one-to-many
```

### Sets with Joins

```yaml
meta:
  sets:
    event_fields:
      fields:
        - user_id
        - event_type
  joins:
    - join: events
      sql_on: ${users.user_id} = ${events.user_id}
      fields: [event_fields*]          # include all fields in set
      # fields: [event_fields*, -user_id]  # exclude specific field from set
      relationship: one-to-many
```

---

## lightdash.config.yml

The `lightdash.config.yml` file enables project-wide customization. Place it in the root directory of your dbt project alongside `dbt_project.yml`.

**Note:** Not supported when connected directly to dbt Cloud.

### Top-Level Sections

```yaml
spotlight:
  # ...

parameters:
  # ...

defaults:
  # ...

custom_granularities:
  # ...
```

### spotlight

Controls metric visibility in the Spotlight catalog.

```yaml
spotlight:
  default_visibility: "show"    # "show" | "hide" (default: "show")
  categories:
    finance:
      label: "Finance"
      color: "green"
    user_engagement:
      label: "User Engagement"
      color: "blue"
    core_kpis:
      label: "Core KPIs"
      color: "red"
```

**Category color options:** `gray`, `violet`, `red`, `orange`, `green`, `blue`, `indigo`, `pink`, `yellow`

### parameters

Project-wide parameters that can be referenced in model SQL and dimension/metric definitions.

```yaml
parameters:
  region:
    label: "Region"
    description: "Filter data by region"
    type: "string"             # "string" | "number" | "date" (default: "string")
    options:
      - "EMEA"
      - "AMER"
      - "APAC"
    default: ["EMEA", "AMER"]
    multiple: true             # allow multi-select

  min_revenue:
    label: "Minimum Revenue"
    description: "Filter for minimum revenue threshold"
    type: "number"
    options:
      - 1000
      - 5000
      - 10000
    default: 5000
    allow_custom_values: true  # allow values beyond the options list

  custom_date_range_start:
    label: "Custom date range - start"
    description: "Start date for a custom date range filter"
    type: "date"

  department:
    label: "Department"
    description: "Filter data by department"
    options_from_dimension:    # populate options from a dimension's values
      model: "employees"
      dimension: "department"
```

**Parameter properties:**

| Property | Required | Type | Description |
|---|---|---|---|
| `label` | Yes | string | User-facing display name |
| `description` | No | string | Explanatory text |
| `type` | No | string | `string`, `number`, or `date`. Default: `string` |
| `options` | No | array | Predefined selectable values |
| `default` | No | any | Default value(s); array for multi-select |
| `multiple` | No | boolean | Enable multi-select |
| `allow_custom_values` | No | boolean | Allow free-text beyond defined options |
| `options_from_dimension` | No | object | Populate options from a model dimension |

**Reference syntax:**

```sql
-- Full syntax
WHERE region IN (${lightdash.parameters.region})

-- Short alias
WHERE region IN (${ld.parameters.region})

-- Model-scoped parameter
WHERE region IN (${lightdash.parameters.orders.region})
```

### defaults

Project-wide defaults that apply unless overridden at table or dimension level.

```yaml
defaults:
  case_sensitive: false    # default: true
```

**Case sensitivity priority (highest to lowest):**
1. Dimension-level `case_sensitive`
2. Table/explore-level `case_sensitive`
3. Project-level (`lightdash.config.yml` `defaults.case_sensitive`)
4. Framework default (case sensitive)

### custom_granularities

Define custom date/time granularities to appear alongside standard intervals in date dimensions.

```yaml
custom_granularities:
  fiscal_quarter:
    label: "Fiscal Quarter"
    sql: "DATE_TRUNC('quarter', ${COLUMN} + INTERVAL '1 month')"
    type: date

  week_monday:
    label: "Week (Mon-Sun)"
    sql: "DATE_TRUNC('week', ${COLUMN})"
    type: date

  fiscal_year:
    label: "Fiscal Year"
    sql: "EXTRACT(YEAR FROM ${COLUMN} + INTERVAL '1 month')"
    type: string           # "date" | "timestamp" | "string" (default: "date")
```

**Properties:**

| Property | Required | Type | Description |
|---|---|---|---|
| `label` | Yes | string | Display name in date zoom dropdown |
| `sql` | Yes | string | SQL transformation; use `${COLUMN}` as placeholder for the date field |
| `type` | No | string | `date`, `timestamp`, or `string`. Default: `date` |

**Using custom granularities in a model:**

```yaml
columns:
  - name: order_date
    meta:
      dimension:
        type: date
        time_intervals: ['DAY', 'WEEK', 'MONTH', 'fiscal_quarter', 'fiscal_year']
```

### Deploy after changes

```bash
lightdash deploy
```

---

## Standalone LightDash YAML (No dbt)

Use standalone LightDash YAML when you do not have a dbt project. Files live at `./lightdash/models/[model_name].yml`.

### Warehouse Configuration

Create `lightdash.config.yml` at project root:

```yaml
warehouse:
  type: snowflake    # snowflake | bigquery | databricks | redshift | postgres | trino
```

### Model File Structure

```yaml
type: model
name: orders

# Optional: override the default table reference
sql_from: DATABASE.SCHEMA.ORDERS_TABLE

# Table-level config (all table parameters apply here at top level)
label: "Orders"
description: "All customer orders"
primary_key: order_id
group_label: "Sales"
order_fields_by: label
sql_filter: ${TABLE}.is_deleted = false

dimensions:
  - name: order_id
    sql: ${TABLE}.ORDER_ID
    type: string
    label: "Order ID"

  - name: status
    sql: ${TABLE}.STATUS
    type: string
    label: "Order Status"
    colors:
      "completed": "#558B2F"
      "cancelled": "#D32F2F"

  - name: created_at
    sql: ${TABLE}.CREATED_AT
    type: timestamp
    time_intervals:
      - DAY
      - WEEK
      - MONTH
      - QUARTER
      - YEAR

  - name: revenue
    sql: ${TABLE}.REVENUE
    type: number
    format: '[$$]#,##0.00'

metrics:
  total_orders:
    type: count
    label: "Total Orders"

  total_revenue:
    type: sum
    sql: ${TABLE}.REVENUE
    label: "Total Revenue"
    format: '[$$]#,##0.00'

  distinct_customers:
    type: count_distinct
    sql: ${TABLE}.CUSTOMER_ID
    label: "Unique Customers"

  revenue_per_order:
    type: number
    sql: ${total_revenue} / NULLIF(${total_orders}, 0)
    label: "Revenue per Order"
    format: '[$$]#,##0.00'

joins:
  - join: customers
    sql_on: ${orders.customer_id} = ${customers.customer_id}
    type: left
    relationship: many-to-one
```

### CLI Commands for Standalone YAML

```bash
lightdash lint                                      # validate YAML files
lightdash deploy --create --no-warehouse-credentials   # first deploy
lightdash deploy --no-warehouse-credentials            # subsequent deploys
```

---

## Complete YAML Examples

### E-commerce Orders Model (dbt v1.9)

```yaml
models:
  - name: orders
    meta:
      label: "Orders"
      description: "All customer orders with line items"
      group_label: "Sales"
      order_fields_by: "label"
      primary_key: order_id
      sql_filter: ${TABLE}.deleted_at IS NULL
      default_filters:
        - created_at: "inThePast 30 days"
      default_show_underlying_values:
        - order_id
        - customer_id
        - status
      joins:
        - join: customers
          sql_on: ${orders.customer_id} = ${customers.customer_id}
          type: left
          relationship: many-to-one
        - join: order_items
          sql_on: ${orders.order_id} = ${order_items.order_id}
          type: left
          relationship: one-to-many
          fields: [item_count, total_item_revenue]
      metrics:
        gross_margin_pct:
          type: number
          sql: "(${total_revenue} - ${total_cost}) / NULLIF(${total_revenue}, 0)"
          format: "0.00%"
          label: "Gross Margin %"
    columns:
      - name: order_id
        meta:
          dimension:
            type: string
            label: "Order ID"
            hidden: false
          metrics:
            total_orders:
              type: count
              label: "Total Orders"

      - name: status
        meta:
          dimension:
            type: string
            label: "Order Status"
            case_sensitive: false
            colors:
              "placed": "#FBC02D"
              "completed": "#388E3C"
              "cancelled": "#D32F2F"
              "refunded": "#7B1FA2"

      - name: created_at
        meta:
          dimension:
            type: timestamp
            label: "Order Date"
            time_intervals: ['RAW', 'DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']
            groups: ["Time", "Order Dates"]

      - name: revenue
        meta:
          dimension:
            type: number
            label: "Revenue"
            format: '[$$]#,##0.00'
            hidden: true
          metrics:
            total_revenue:
              type: sum
              label: "Total Revenue"
              format: '[$$]#,##0.00'
              tags: ["core", "finance"]
              show_underlying_values:
                - order_id
                - customer_id
                - revenue
            avg_order_value:
              type: average
              label: "Average Order Value"
              format: '[$$]#,##0.00'
              round: 2

      - name: cost
        meta:
          dimension:
            type: number
            hidden: true
          metrics:
            total_cost:
              type: sum
              hidden: true

      - name: customer_id
        meta:
          dimension:
            type: string
            label: "Customer ID"
            urls:
              - label: "View Customer Profile"
                url: "https://app.example.com/customers/${ value.raw }"
          metrics:
            distinct_customers:
              type: count_distinct
              label: "Unique Customers"
```

### SaaS Users Model with Access Control (dbt v1.10+)

```yaml
models:
  - name: users
    config:
      meta:
        label: "Users"
        description: "All application users"
        group_label: "Core"
        primary_key: user_id
        sql_filter: ${TABLE}.region IN (${lightdash.attributes.allowed_regions})
        case_sensitive: false
        required_attributes:
          is_internal: "true"
        explores:
          users_with_pii:
            label: "Users (with PII)"
            required_attributes:
              has_pii_access: "true"
            joins:
              - join: user_pii
                sql_on: ${users.user_id} = ${user_pii.user_id}
                relationship: one-to-one
        joins:
          - join: subscriptions
            sql_on: ${users.user_id} = ${subscriptions.user_id}
            type: left
            relationship: one-to-one
          - join: events
            sql_on: ${users.user_id} = ${events.user_id}
            type: left
            relationship: one-to-many
            fields: [event_count, last_event_at]
        metrics:
          dau_over_mau:
            type: number
            sql: "${dau} / NULLIF(${mau}, 0)"
            format: "0.00%"
            label: "DAU / MAU Ratio"
    columns:
      - name: user_id
        config:
          meta:
            dimension:
              type: string
              label: "User ID"
            metrics:
              total_users:
                type: count
                label: "Total Users"
              dau:
                type: count_distinct
                sql: "IF(${is_daily_active}, ${user_id}, NULL)"
                label: "Daily Active Users"
                hidden: true
              mau:
                type: count_distinct
                sql: "IF(${is_monthly_active}, ${user_id}, NULL)"
                label: "Monthly Active Users"
                hidden: true

      - name: created_at
        config:
          meta:
            dimension:
              type: timestamp
              label: "Sign Up Date"
              time_intervals: ['DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR']

      - name: plan
        config:
          meta:
            dimension:
              type: string
              label: "Subscription Plan"
              colors:
                "free": "#9E9E9E"
                "starter": "#1976D2"
                "pro": "#7B1FA2"
                "enterprise": "#F57C00"
            metrics:
              paying_users:
                type: count_distinct
                sql: "IF(${plan} != 'free', ${user_id}, NULL)"
                label: "Paying Users"
                filters:
                  - plan: "!= free"

      - name: email
        config:
          meta:
            dimension:
              type: string
              label: "Email"
              required_attributes:
                has_pii_access: "true"
```

### lightdash.config.yml — Full Example

```yaml
spotlight:
  default_visibility: "show"
  categories:
    core_kpis:
      label: "Core KPIs"
      color: "red"
    finance:
      label: "Finance"
      color: "green"
    engagement:
      label: "User Engagement"
      color: "blue"
    growth:
      label: "Growth"
      color: "orange"

parameters:
  region:
    label: "Region"
    description: "Filter data by sales region"
    options:
      - "EMEA"
      - "AMER"
      - "APAC"
    default: ["EMEA"]
    multiple: true
    allow_custom_values: false

  min_order_value:
    label: "Minimum Order Value"
    type: "number"
    options:
      - 0
      - 100
      - 500
      - 1000
    default: 0

  report_date:
    label: "Report Date"
    type: "date"

  department:
    label: "Department"
    options_from_dimension:
      model: "employees"
      dimension: "department"

defaults:
  case_sensitive: false

custom_granularities:
  fiscal_quarter:
    label: "Fiscal Quarter (Feb start)"
    sql: "DATE_TRUNC('quarter', ${COLUMN} + INTERVAL '1 month')"
    type: date

  fiscal_year:
    label: "Fiscal Year (Feb start)"
    sql: "EXTRACT(YEAR FROM ${COLUMN} + INTERVAL '1 month')"
    type: string

  iso_week:
    label: "ISO Week"
    sql: "DATE_TRUNC('week', ${COLUMN})"
    type: date
```

---

## Quick Reference: SQL Interpolation Syntax

| Syntax | Meaning |
|---|---|
| `${TABLE}.column_name` | Reference a column in the current table |
| `${dimension_name}` | Reference another dimension in the same model |
| `${joined_model.dimension_name}` | Reference a dimension in a joined model |
| `${metric_name}` | Reference a metric (in non-aggregate metrics) |
| `${dimension_name_day}` | Reference a specific time interval of a dimension |
| `${lightdash.attributes.attr_name}` | Inject a user attribute value |
| `${lightdash.parameters.param_name}` | Inject a project-level parameter value |
| `${ld.parameters.param_name}` | Short alias for above |
| `${lightdash.parameters.model.param_name}` | Inject a model-scoped parameter |
| `${COLUMN}` | Placeholder for date column in `custom_granularities` SQL |

---

## Cross-References

- See `docs/lightdash/reference-yaml.md` (this file) for complete YAML syntax
- LightDash dimensions reference: https://docs.lightdash.com/references/dimensions
- LightDash metrics reference: https://docs.lightdash.com/references/metrics
- LightDash tables reference: https://docs.lightdash.com/references/tables
- LightDash joins reference: https://docs.lightdash.com/references/joins
- LightDash config reference: https://docs.lightdash.com/references/lightdash-config-yml.md
- LightDash standalone YAML guide: https://docs.lightdash.com/guides/lightdash-yaml.md
