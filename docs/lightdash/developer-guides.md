# LightDash: Developer Guides

> Reference documentation for AI coding agents working with LightDash.
> Sources: docs.lightdash.com — CLI reference, CI/CD automation guide, AI agents guide, caching guide, virtual views guide, embedding guide, React SDK reference, iframe embedding reference.
> Covers the full developer surface: CLI commands, CI/CD pipelines, AI agent configuration, caching behavior, virtual views, and embedding (iframe + React SDK).

---

## Table of Contents

1. [CLI Installation & Authentication](#cli-installation--authentication)
2. [CLI Usage & Deployment](#cli-usage--deployment)
3. [CI/CD Integration](#cicd-integration)
4. [AI Agents & Verified Answers](#ai-agents--verified-answers)
5. [Caching Strategies](#caching-strategies)
6. [Virtual Views](#virtual-views)
7. [Embedding](#embedding)
8. [Code Examples](#code-examples)

---

## CLI Installation & Authentication

### Installation

| Method | Command | Platform |
|---|---|---|
| Homebrew | `brew tap lightdash/lightdash && brew install lightdash` | Mac only |
| NPM | `npm install -g @lightdash/cli` | All platforms |
| GitHub binary | Download from [GitHub releases](https://github.com/lightdash/lightdash/releases) | All platforms |

**Install Node.js via NVM (if needed before NPM install):**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
nvm install --lts
```

**Upgrade:**
```bash
brew upgrade lightdash          # Homebrew
npm update -g @lightdash/cli    # NPM

# Pin to specific version:
npm install -g @lightdash/cli@0.1743.1
```

**Verify:**
```bash
lightdash --version
```

### Authentication

```bash
# Interactive login
lightdash login https://app.lightdash.cloud

# Token-based login (for SSO users and CI/CD)
lightdash login https://app.lightdash.cloud --token <personal-access-token>

# OAuth browser-based login
lightdash login https://app.lightdash.cloud --oauth

# Login and select a project immediately
lightdash login https://app.lightdash.cloud --project <uuid>
```

**Personal access tokens** are generated in Lightdash Settings > Personal Access Tokens.

### Project Selection

```bash
# Select by name
lightdash config set-project --name "My Project"

# Select by UUID
lightdash config set-project --uuid "d75379bc-f6e9-4e52-86b2-d897cabacd0c"

# View active project
lightdash config get-project

# List all projects
lightdash config list-projects
```

### Environment Variables

| Variable | Purpose |
|---|---|
| `LIGHTDASH_API_KEY` | API token for authentication (CI/CD) |
| `LIGHTDASH_URL` | Lightdash instance URL |
| `LIGHTDASH_PROJECT` | Project UUID |
| `LIGHTDASH_PROXY_AUTHORIZATION` | Proxy authorization header |
| `CI=true` | Disables interactive prompts in CI |
| `DBT_PROJECT_DIR` | Override dbt project directory |
| `DBT_PROFILES_DIR` | Override dbt profiles directory |

---

## CLI Usage & Deployment

### Global Flags

```bash
--version / -V        # Show CLI version
--help / -h           # Show help for any command
--verbose             # Enable detailed logging
```

### Compilation

```bash
# Compile full project
lightdash compile

# Compile specific models
lightdash compile -s accounts
lightdash compile --select tag:marketing

# Skip dbt compile, use existing manifest.json
lightdash compile --skip-dbt-compile

# Compile without warehouse access (uses YAML types)
lightdash compile --no-warehouse-credentials
```

### Preview Environments

Preview environments are isolated temporary projects — safe for testing before touching production.

```bash
# Create interactive preview (blocks terminal until closed)
lightdash preview --name "PR: Add Revenue Metric"
lightdash preview --name "feature/my-branch" --ignore-errors
lightdash preview --start-of-week=0 --select "tag:marketing"

# Create persistent preview (used in CI/CD)
lightdash start-preview --name "my-branch-name"

# Destroy a preview
lightdash stop-preview --name "my-branch-name"
```

**Preview flags:**

| Flag | Description |
|---|---|
| `--name [name]` | Preview project name (required for start-preview) |
| `--start-of-week [0-6]` | Set week start (0=Monday, 6=Sunday) |
| `--skip-dbt-compile` | Use existing manifest |
| `--skip-warehouse-catalog` | Use YAML types instead of warehouse catalog |
| `--no-warehouse-credentials` | Compile without warehouse access |
| `--ignore-errors` | Deploy despite compilation errors |
| `--table-configuration [prod/all]` | Copy table config from source project |
| `--skip-copy-content` | Skip copying charts/dashboards |
| `--use-batched-deploy` | Deploy explores in batches |
| `--batch-size [number]` | Explores per batch (default: 50) |
| `--parallel-batches [number]` | Parallel batch uploads (default: 1) |

### Production Deployment

> **Warning:** `lightdash deploy` pushes directly to your production project, overwriting the semantic layer. Ensure local dbt profiles point to the correct database target.

```bash
# Deploy current local state to production
lightdash deploy

# Deploy to a specific dbt target
lightdash deploy --target prod

# Deploy using a specific dbt profile
lightdash deploy --profile prod

# Create a brand-new project during deploy
lightdash deploy --create "My New Project"

# Batched deployment for large projects
lightdash deploy --use-batched-deploy --batch-size 100 --parallel-batches 3
```

**`lightdash deploy` vs `lightdash refresh`:**

| Command | Uses | Safe For |
|---|---|---|
| `lightdash deploy` | Local dbt profile from `profiles.yml` | Deploying local changes (risk: profile misconfiguration) |
| `lightdash refresh` | Saved dbt credentials in Lightdash | Re-triggering metadata sync from any machine |

### Validation & Linting

```bash
# Validate project content against local files
lightdash validate

# Validate specific elements only
lightdash validate --only ["dashboards"]
lightdash validate --only ["charts", "tables"]

# Validate last preview
lightdash validate --preview

# Lint YAML files against JSON schemas
lightdash lint
lightdash lint --path ./lightdash/charts/my-chart.yml
lightdash lint --format json    # JSON/SARIF output for CI integration
lightdash lint --verbose
```

### Schema Generation

```bash
# Generate or update schema.yml for a model
lightdash generate -s mymodel

# Generate without Lightdash metadata
lightdash generate -s mymodel --exclude-meta

# Preserve original column casing
lightdash generate -s mymodel --preserve-column-case

# Run dbt then update schema.yml for changed models
lightdash dbt run --select mymodel

# Generate exposures YAML (beta, requires Project Admin)
lightdash generate-exposures --output ./lightdash-exposures.yml
```

### Content Management (Charts & Dashboards as Code)

```bash
# Download all charts and dashboards to ./lightdash/
lightdash download

# Download specific dashboard (and its charts)
lightdash download -d https://app.lightdash.cloud/my-dashboard-url

# Download to custom directory
lightdash download -p /path/to/output/

# Download with translation maps for localization
lightdash download --language-map

# Upload modified content
lightdash upload
lightdash upload -d my-dashboard-slug
lightdash upload -d my-dashboard-slug --include-charts   # include chart updates
lightdash upload --force                                 # required for new content
lightdash upload --validate                              # validate after upload
lightdash upload --skip-space-create                    # don't create missing spaces

# Rename fields/models across all content
lightdash rename --type field --from num_users --to count_distinct_user_id
lightdash rename --type model --from users_mart_v1 --to users --dry-run
lightdash rename --type field --model orders --from count --to count_distinct_order_id --list
```

### Utility Commands

```bash
# Run raw SQL and export to CSV
lightdash sql "SELECT * FROM users LIMIT 100" -o users.csv
lightdash sql "SELECT * FROM orders" -o orders.csv --limit 1000 --page-size 5000

# Show CLI environment info for debugging
lightdash diagnostics
lightdash diagnostics --dbt
lightdash diagnostics --dbt --project-dir ./my-dbt-project
```

### dbt Node Selection Flags (used across commands)

```bash
-s / --select [models...]   # Include specific models
--exclude [models...]       # Exclude specific models
--selector [name]           # Use named selector
--project-dir [path]        # dbt project directory
--profiles-dir [path]       # dbt profiles directory
--profile [name]            # dbt profile name
--target [name]             # dbt target name
--vars [vars]               # Set project variables
--threads [number]          # Thread count
--defer                     # Use deferred state
--full-refresh              # Full refresh mode
```

---

## CI/CD Integration

### Overview

Two automation patterns are supported:

1. **Preview on pull request** — creates an isolated preview project for each PR, deleted on merge/close.
2. **Deploy on merge** — automatically deploys to production when changes land on `main`.

Both patterns use GitHub Actions and the Lightdash CLI.

### Required GitHub Secrets

| Secret | Value |
|---|---|
| `LIGHTDASH_API_KEY` | Personal access token from Lightdash Settings |
| `LIGHTDASH_PROJECT` | Project UUID (from Lightdash URL) |
| `LIGHTDASH_URL` | Instance URL (e.g., `https://app.lightdash.cloud`) |
| `DBT_PROFILES` | dbt `profiles.yml` content as YAML |
| `GOOGLE_APPLICATION_CREDENTIALS` | BigQuery service account JSON (BigQuery only) |

### dbt Profile Templates for CI/CD

**BigQuery:**
```yaml
[my-bigquery-db]:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      keyfile: keyfile.json
      project: [GCP project id]
      dataset: [dbt dataset name]
```

**Postgres:**
```yaml
company-name:
  target: dev
  outputs:
    dev:
      type: postgres
      host: [hostname]
      user: [username]
      password: [password]
      port: [port]
      dbname: [database name]
      schema: [dbt schema]
      threads: [1 or more]
      keepalives_idle: 0
      connect_timeout: 10
      retries: 1
```

**Redshift:**
```yaml
company-name:
  target: dev
  outputs:
    dev:
      type: redshift
      host: [hostname.region.redshift.amazonaws.com]
      user: [username]
      password: [password]
      port: 5439
      dbname: analytics
      schema: analytics
      threads: 4
      keepalives_idle: 240
      connect_timeout: 10
      ra3_node: true
```

**Snowflake:**
```yaml
my-snowflake-db:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: [account id]
      user: [username]
      password: [password]
      role: [user role]
      database: [database name]
      warehouse: [warehouse name]
      schema: [dbt schema]
      threads: [1 or more]
      client_session_keep_alive: False
      query_tag: [anything]
```

**Databricks:**
```yaml
your_profile_name:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: [optional catalog name]
      schema: [schema name]
      host: [yourorg.databrickshost.com]
      http_path: [/sql/your/http/path]
      token: [dapiXXXXXXXXXXXXXXXXXXXXXXX]
      threads: [1 or more]
```

### Pattern 1: Compile Check on Pull Request

Use `compile.yml` from the [lightdash/cli-actions](https://github.com/lightdash/cli-actions) repository. This validates YAML and metrics on every PR — errors (e.g., metric referencing a nonexistent dimension) appear in the Actions tab.

To compile only selected models:
```yaml
run: lightdash compile --select tag:lightdash
```

### Pattern 2: Preview on Pull Request

Use `start-preview.yml` and `close-preview.yml` from the cli-actions repository.

**Key workflow step:**
```yaml
run: lightdash start-preview --project-dir "$PROJECT_DIR" --profiles-dir . --name ${GITHUB_REF##*/} --target ${{ github.actor }}
```

**Developer credential strategies:**

**Option 1 — Profile targets per developer (GitHub username as target):**
```yaml
jaffle_shop:
  target: prod
  outputs:
    prod:
      type: bigquery
      method: oauth
      keyfile: keyfile.json
      project: jaffle-shop
      dataset: prod
    katie:
      type: bigquery
      method: oauth
      keyfile: keyfile.json
      project: jaffle-shop
      dataset: dbt_katie
```
Reference in workflow: `--target ${{ github.actor }}`

**Option 2 — GitHub Environments (per-developer secrets):**
```yaml
jobs:
  preview:
    runs-on: ubuntu-latest
    environment: ${{ github.actor }}
```

**Option 3 — dbt Cloud PR schema (`dbt_cloud_pr_<job_id>_<pr_id>`):**

Add to `profiles.yml`:
```yaml
schema: "{{ env_var('DBT_SCHEMA') }}"
```

Fetch PR ID in workflow:
```yaml
- uses: actions/github-script@v6
  id: pr_id
  with:
    script: |
      if (context.issue.number) {
        return context.issue.number;
      } else {
        return (
          await github.rest.repos.listPullRequestsAssociatedWithCommit({
            commit_sha: context.sha,
            owner: context.repo.owner,
            repo: context.repo.repo,
          })
        ).data[0].number;
      }
    result-encoding: string
```

Set schema in workflow step:
```yaml
env:
  DBT_SCHEMA: 'dbt_cloud_pr_1234_${{steps.pr_id.outputs.result}}'
```

### Pattern 3: Deploy on Merge to Main

Use `deploy.yml` from the cli-actions repository. Triggered automatically on merges to `main`, this deploys updated configurations to all Lightdash projects.

### Best Practices

- Always use production warehouse credentials in `deploy.yml`.
- Use separate dev/prod profiles for preview vs. deploy workflows.
- Set `CI=true` to disable interactive CLI prompts.
- Store `DBT_PROFILES` content as a single GitHub secret; inject via `echo "$DBT_PROFILES" > profiles.yml` in workflow steps.
- Monitor GitHub Actions logs for compilation and deployment status.

---

## AI Agents & Verified Answers

### Overview

AI agents answer natural language questions by querying your semantic layer (dbt models + Lightdash metrics). They generate semantic queries — not raw SQL — and return charts, tables, or text answers.

**Availability:** Add-on across all pricing tiers. Free trial available for new organizations.

**Supported visualization types:** Tables, bar charts, line charts, scatter charts, pie charts, funnel charts.

**Not supported:** Forecasting, predictive analytics, custom statistical calculations, table calculations, big number visualizations, cross-session memory.

### Setup (4 Steps)

**Step 1 — Enable AI features (admin only):**

Navigate to `/ai-agents/admin/agents` and toggle "Enable AI features for users". This activates:
- The "Ask AI" button on the homepage and navbar.
- User access to all AI agents.
- Admin visibility into all agent threads.

**Step 2 — Create a new agent:**

From the Ask AI interface, select the agent dropdown and click "Create new agent".

**Step 3 — Configure the agent:**

| Setting | Description |
|---|---|
| Name & Image | Memorable identifier with visual branding |
| Instructions | Domain knowledge, company context, analysis preferences, role/expertise |
| Data access | Toggle to allow query result analysis (off = metadata only) |
| User/group permissions | Controls who can use the agent |
| Tags | Restrict agent to specific dbt dimensions and metrics |

**Tags** restrict what data the agent can see. Tag dbt model dimensions/metrics with identifiers (e.g., `"ai"`, `"sales"`), then add matching tags to agent settings. Untagged fields are invisible to the agent.

**Step 4 — Slack integration (optional):**

1. Add Slack in organization settings (admin required).
2. Configure the target Slack channel in agent integration settings.
3. Add "Lightdash for analytics" app to the channel via: channel settings → Edit settings → Integrations.
4. Enable thread context sharing in Lightdash Integrations settings for multi-turn conversations.

Default: one agent per Slack channel. Multi-agent Slack support is available in beta on request.

### AI Hints (Metadata for Agents)

AI hints are metadata fields in dbt models that take precedence over standard descriptions when the agent is processing queries. They are invisible to regular users.

**Three levels:**

| Level | Purpose | Example |
|---|---|---|
| Model-level | Table purpose and use cases | "This table contains one row per customer order, excluding test orders" |
| Dimension-level | Column explanation and sensitivity | "Contains PII data — do not surface in public dashboards" |
| Metric-level | What the metric measures and when to use it | "MRR includes only recurring subscription revenue, excludes one-time fees" |

Hints support string and array formats in YAML.

### Writing Effective Agent Instructions

**Include:**
- Industry terminology and org-specific acronyms.
- Preferred communication style for the target audience.
- Business constraints (regulatory, budget-related).
- Data analysis preferences and KPI thresholds (e.g., "Flag churn > 5% as critical").
- Contextual interpretation guidance (seasonal patterns, expected baselines).

**Avoid:**
- Contradictory or vague directives.
- Restating built-in AI capabilities.
- Overloading a single agent with multiple business domains.
- Conflicting priorities without a clear hierarchy.

**Principle:** "Your agent is only as clever as the context and instructions you've given it."

**Principle:** "If your colleague wouldn't understand your documentation, neither will the AI agent."

### Specialization Pattern

Create focused agents per business area rather than one general-purpose agent:

| Agent | Data Access | Tags |
|---|---|---|
| Marketing Assistant | Campaigns, leads, acquisition | `marketing` |
| Finance Agent | Revenue, costs, MRR, churn | `finance` |
| Operations Agent | Fulfillment, SLA, inventory | `ops` |

This prevents sensitive data cross-contamination and improves answer accuracy.

### Verified Answers

Verified answers train the agent with high-quality examples, improving consistency and accuracy over time.

**How to verify an answer:**
1. Ask the agent a question.
2. Review the generated chart/dashboard in the conversation.
3. Click the checkmark icon in the top-right corner.

**Effects:**
- Agent references verified answers when responding to similar future questions.
- After 6+ verified answers exist, suggested question starters appear automatically in new conversations.
- In Slack, the agent surfaces links to relevant verified answers in its responses.

**Access control:** Only users with Admin or Developer roles can verify answers.

**Management:** View all verified answers, who verified them, timestamps, and reference counts in the Verified Answers tab in agent settings.

### Evaluation & Feedback

- Encourage users to use thumbs-up/thumbs-down ratings.
- Admins should regularly review negative feedback patterns.
- Convert failed prompts into evaluation test cases.
- Run evaluations before deploying instruction changes.
- Build evaluation test suites to systematically test agent behavior.

### Self-Improvement (Beta)

When enabled, the agent can propose semantic layer modifications, which are tracked as changesets for admin review before application.

### Data Privacy

Lightdash stores only one-line summaries and basic query metadata. Actual warehouse data is never persisted by the AI system unless the "data access" toggle is enabled.

---

## Caching Strategies

### Availability

| Feature | Availability |
|---|---|
| Filter value caching | Lightdash Cloud (all plans), on-premise with valid license |
| Chart/dashboard results caching | Lightdash Cloud Pro+ only (requires Lightdash team activation) |

Results caching is **not enabled by default** even on paid plans. Contact Lightdash support to activate it.

### Caching Types

**1. Filter value caching (automatic)**

- No configuration required.
- Automatically caches filter dropdown values.
- Displays a timestamp showing when cached values were loaded.
- Users can manually refresh by clicking the timestamp message.
- Applies to both initial filter loads and search-based filtering.

**2. Chart and dashboard results caching**

- First daily visitor triggers fresh warehouse queries; results are stored.
- Subsequent visitors receive cached results.
- Query modifications (filters, date ranges, user attributes) create separate cache entries.
- Cache is stored in S3, identified by project ID and generated SQL.

### What Is and Is Not Cached

| Cached | Not Cached |
|---|---|
| Saved charts (not in edit mode) | New or edited charts |
| Dashboard tiles | Metrics Catalog and Spotlight |
| Scheduled deliveries | SQL runner charts |
| Google Sheets syncs | — |

### Cache Scope

Caching applies to the entire Lightdash instance when enabled. There is no way to enable or disable caching for specific projects or individual dashboards.

**User-level isolation:** Projects requiring user credentials maintain separate cache entries per user, preserving row-level access controls.

### Cache Duration & Invalidation

| Setting | Default | Notes |
|---|---|---|
| Cache expiry | 24 hours | Configurable at org level |
| Expiry type | Rolling (per result, not scheduled) | Each cached result has its own 24-hour clock |
| Manual invalidation | Dashboard refresh button | No per-chart invalidation |

The dashboard header displays the timestamp of the oldest cached result. No timestamp means no active cache.

### Avoiding Cache Fragmentation (Best Practice)

Dynamic datetime values with second-level precision generate unique SQL strings on every query, preventing cache reuse.

**Do:**
- Use date-only filters: `2024-01-15`
- Round times to fixed intervals: `12:00:00`

**Avoid:**
- Dynamic "current time" functions with second precision (e.g., `NOW()`)

### Limitations

- No per-project or per-dashboard caching control.
- No per-chart manual cache invalidation.
- Metrics Catalog and Spotlight do not support caching.
- Google Sheets syncs deliver cached results until expiration (not always fresh).

---

## Virtual Views

### What Are Virtual Views

Virtual views are custom SQL queries created in the SQL Runner that are saved and made available to all team members as table-like objects. They appear in the Tables list alongside standard dbt models, enabling exploration and chart building without requiring dbt model changes.

**Key characteristic:** Virtual views are not saved to or managed in the dbt project.

### When to Use Virtual Views

| Use Case | Recommendation |
|---|---|
| One-off analysis to share with the team | Virtual View |
| Regularly-used asset that should be version-controlled | Write back to dbt |
| Exploratory SQL that needs a persistent home | Virtual View |
| Production-grade table used by many dashboards | dbt model |

### Creating a Virtual View

1. Open the SQL Runner.
2. Write your SQL query.
3. From the save dropdown menu, select **Create Virtual View**.
4. The view immediately appears in the Tables list for all team members.

### Managing Virtual Views

Access management through the Explorer interface:

1. Locate the three-dot menu beside the Virtual View name in the Tables list.
2. Options available: **Edit** (modify the SQL) or **Delete**.
3. Changes to a Virtual View propagate to all dependent charts and dashboards.

> **Warning:** Deleting a Virtual View will break any charts or dashboards built on top of it.

### Limitations

- Not stored in or synced with the dbt project.
- No version control — changes are immediate and irreversible through the UI.
- No YAML configuration; defined entirely through the SQL Runner interface.
- Not recommended as a permanent replacement for dbt models in production use cases.

---

## Embedding

### Embedding Methods Comparison

| Method | Supports | CORS Required | Dependencies | Best For |
|---|---|---|---|---|
| iframe embedding | Dashboards only | No | None | Simple, framework-agnostic integration |
| React SDK (`@lightdash/sdk`) | Dashboards, Charts, Explore | Yes | React 18+, Next.js 15+ | React apps needing programmatic filters & callbacks |

**Charts via iframe are not supported** — use the React SDK for embedding individual charts.

### Security Model (Both Methods)

- All embedding uses **JWT tokens** signed with a per-project embed secret.
- Tokens are **short-lived** and must be **generated server-side**. Never generate in frontend code.
- Embedded content is accessible to anyone with a valid token — **no Lightdash login required**.
- Row-level security is enforced via `userAttributes` in the JWT payload.
- The embed secret is stored as an environment variable; never hardcode it.

### Embed Setup (Both Methods)

1. Generate an embed secret for your project in Lightdash project settings.
2. Whitelist dashboards by adding them to the allowed list.
3. Configure token expiration, interactivity, and export options.
4. Generate tokens server-side on each request using the embed secret.

---

### iframe Embedding

#### URL Structure

```
https://your-instance.lightdash.cloud/embed/{projectUuid}/dashboard/{dashboardUuid}#{jwtToken}
```

Dashboard slugs can substitute UUIDs:
```
https://your-instance.lightdash.cloud/embed/{projectUuid}/dashboard/{dashboardSlug}#{jwtToken}
```

The JWT is passed in the **URL hash fragment** — this prevents the token from being transmitted to the server or appearing in server logs.

#### Theming Parameters

Append query parameters before the hash:
```
https://your-instance.lightdash.cloud/embed/{projectUuid}/dashboard/{slug}?theme=dark&backgroundColor=1c1c1c#{jwtToken}
```

| Parameter | Values |
|---|---|
| `theme` | `light` (default) or `dark` |
| `backgroundColor` | 3, 6, or 8-digit hex code without `#` (e.g., `1c1c1c`, `FFF`, `FF000080`) |

#### Basic iframe HTML

```html
<iframe
  src="https://app.lightdash.cloud/embed/project-uuid/dashboard/dashboard-uuid#jwt-token"
  width="100%"
  height="600"
  frameborder="0"
  style="border: none;"
  loading="lazy"
  title="Lightdash Dashboard"
  allowfullscreen
></iframe>
```

#### Responsive Sizing Options

**Aspect ratio (16:9):**
```html
<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden;">
  <iframe
    src="https://app.lightdash.cloud/embed/..."
    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none;"
    frameborder="0"
    allowfullscreen
  ></iframe>
</div>
```

**Modern CSS:**
```html
<iframe
  src="https://app.lightdash.cloud/embed/..."
  style="aspect-ratio: 16/9; width: 100%; border: none;"
  frameborder="0"
></iframe>
```

**Viewport height:**
```html
<iframe
  src="https://app.lightdash.cloud/embed/..."
  style="width: 100%; height: 80vh; border: none;"
  frameborder="0"
></iframe>
```

#### Security Sandbox

```html
<iframe
  src="https://app.lightdash.cloud/embed/..."
  sandbox="allow-scripts allow-same-origin allow-forms allow-downloads"
  style="width: 100%; height: 600px; border: none;"
></iframe>
```

#### Token Refresh Strategies

**Option 1 — Extended expiration:**
```javascript
jwt.sign(payload, secret, { expiresIn: '7d' })
```

**Option 2 — Periodic client refresh (50-minute interval for 1-hour tokens):**
```javascript
function refreshEmbed() {
  fetch('/api/dashboard-embed-url')
    .then(res => res.json())
    .then(data => {
      document.getElementById('dashboard-iframe').src = data.url;
    });
}
setInterval(refreshEmbed, 50 * 60 * 1000);
```

**Option 3 — Backend proxy (generates fresh token per request):**
```javascript
app.get('/embed-proxy/dashboard/:dashboardUuid', authenticateUser, (req, res) => {
  const token = jwt.sign({
    content: {
      type: 'dashboard',
      dashboardUuid: req.params.dashboardUuid,
    },
  }, process.env.LIGHTDASH_EMBED_SECRET, { expiresIn: '1h' });

  const embedUrl = `https://app.lightdash.cloud/embed/${projectUuid}/dashboard/${req.params.dashboardUuid}#${token}`;
  res.redirect(embedUrl);
});
```

---

### React SDK Embedding

#### Installation

```bash
npm install @lightdash/sdk
# or
pnpm add @lightdash/sdk
# or
yarn add @lightdash/sdk
```

**Requirements:** React 18+, Next.js 15+.

**Critical:** Import the SDK stylesheet as the **first import** in your application entry point:

```tsx
import "@lightdash/sdk/sdk.css";   // MUST be first
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

#### CORS Configuration (Required for React SDK)

Set these environment variables on your Lightdash server:
```bash
LIGHTDASH_CORS_ENABLED=true
LIGHTDASH_CORS_ALLOWED_DOMAINS=https://your-domain.com
```

CORS is required for the React SDK. It is **not** required for iframe embedding.

#### Three Core Components

**1. `Lightdash.Dashboard`**

```typescript
type DashboardProps = {
  instanceUrl: string;
  token: string | Promise<string>;
  styles?: { backgroundColor?: string; fontFamily?: string };
  filters?: SdkFilter[];
  contentOverrides?: LanguageMap;
  onExplore?: (options: { chart: SavedChart }) => void;
};
```

**2. `Lightdash.Chart`**

```typescript
type ChartProps = {
  instanceUrl: string;
  id: string;          // savedQueryUuid
  token: string | Promise<string>;
  styles?: { backgroundColor?: string; fontFamily?: string };
  contentOverrides?: LanguageMap;
};
```

**3. `Lightdash.Explore`**

```typescript
type ExploreProps = {
  instanceUrl: string;
  token: string | Promise<string>;
  styles?: { backgroundColor?: string; fontFamily?: string };
  contentOverrides?: LanguageMap;
};
```

#### JWT Token Configuration Reference

All tokens share a common structure: `content` (required), `user` (optional), `userAttributes` (optional), plus standard JWT claims.

**Dashboard token fields:**

| Field | Type | Description |
|---|---|---|
| `content.type` | `'dashboard'` | Required literal |
| `content.dashboardUuid` | string | Dashboard UUID (or use `dashboardSlug`) |
| `content.dashboardSlug` | string | Dashboard slug (alternative to UUID) |
| `content.dashboardFiltersInteractivity` | `{ enabled: 'all' \| 'some' \| 'none' }` | User filter interaction control |
| `content.parameterInteractivity.enabled` | boolean | Allow parameter value modifications |
| `content.canExportCsv` | boolean | Per-chart CSV download |
| `content.canExportImages` | boolean | PNG capture |
| `content.canExportPagePdf` | boolean | Full dashboard as PDF |
| `content.canDateZoom` | boolean | Date granularity adjustment |
| `content.canExplore` | boolean | Query builder access |
| `content.canViewUnderlyingData` | boolean | Raw data table access |
| `userAttributes` | object | Key-value pairs for row-level security |
| `user.externalId` | string | For query tracking/analytics |
| `user.email` | string | For query tracking/analytics |

**Chart token fields:**

| Field | Type | Description |
|---|---|---|
| `content.type` | `'chart'` | Required literal |
| `content.contentId` | string | Saved chart UUID |
| `content.isPreview` | boolean | Preview mode |
| `content.canExportCsv` | boolean | CSV download |
| `content.canExportImages` | boolean | PNG capture |
| `content.canViewUnderlyingData` | boolean | Raw data table access |

**Explore token — set `canExplore: true` in a dashboard token:**

```javascript
jwt.sign({
  content: {
    type: 'dashboard',
    dashboardUuid: 'starting-dashboard-uuid',
    canExplore: true,   // Required to enable Explore component
    canExportCsv: true,
    canExportImages: true,
  },
}, process.env.LIGHTDASH_EMBED_SECRET, { expiresIn: '4h' });
```

#### FilterOperator Values (React SDK)

```typescript
import { FilterOperator } from '@lightdash/sdk';
```

| Operator | Description | Value Type |
|---|---|---|
| `IS_NULL` | Field is null | n/a |
| `NOT_NULL` | Field is not null | n/a |
| `EQUALS` | Exact match | single |
| `NOT_EQUALS` | Excludes value | single |
| `STARTS_WITH` | String prefix | single |
| `ENDS_WITH` | String suffix | single |
| `INCLUDE` | Matches any in array | array |
| `NOT_INCLUDE` | Excludes all in array | array |
| `LESS_THAN` | < | single |
| `LESS_THAN_OR_EQUAL` | <= | single |
| `GREATER_THAN` | > | single |
| `GREATER_THAN_OR_EQUAL` | >= | single |
| `IN_THE_PAST` | Date in past N units | single |
| `NOT_IN_THE_PAST` | Date not in past N | single |
| `IN_THE_NEXT` | Date in next N units | single |
| `IN_THE_CURRENT` | Date in current period | single |
| `NOT_IN_THE_CURRENT` | Date outside period | single |
| `IN_BETWEEN` | Range check | array[2] |
| `NOT_IN_BETWEEN` | Outside range | array[2] |

#### Localization

Generate translation maps:
```bash
lightdash download --language-map
```

Apply in component:
```tsx
<Lightdash.Dashboard
  instanceUrl={lightdashUrl}
  token={token}
  contentOverrides={i18n.getResourceBundle(i18n.language, 'demo-dashboard')}
/>
```

**Translatable:** Dashboard names, descriptions, tile titles, chart names, axis labels, series names, markdown content.
**Not translatable:** Data warehouse values, dimension data, metric names from the database.

---

## Code Examples

### Example 1: Node.js iframe Token Generation

```javascript
import jwt from 'jsonwebtoken';

const LIGHTDASH_EMBED_SECRET = process.env.LIGHTDASH_EMBED_SECRET;
const instanceUrl = 'https://app.lightdash.cloud';
const projectUuid = 'your-project-uuid';
const dashboardUuid = 'your-dashboard-uuid';

// Generate token with row-level security
const token = jwt.sign({
  content: {
    type: 'dashboard',
    dashboardUuid: dashboardUuid,
    canExportCsv: true,
    canExportImages: true,
    dashboardFiltersInteractivity: { enabled: 'all' },
  },
  userAttributes: {
    tenant_id: user.tenantId,
    region: user.region,
  },
  user: {
    externalId: user.id,
    email: user.email,
  },
}, LIGHTDASH_EMBED_SECRET, { expiresIn: '1h' });

const embedUrl = `${instanceUrl}/embed/${projectUuid}/dashboard/${dashboardUuid}#${token}`;
```

### Example 2: Python iframe Token Generation

```python
import jwt
import datetime
import os

LIGHTDASH_EMBED_SECRET = os.getenv('LIGHTDASH_EMBED_SECRET')
instance_url = 'https://app.lightdash.cloud'
project_uuid = 'your-project-uuid'
dashboard_uuid = 'your-dashboard-uuid'

payload = {
    'content': {
        'type': 'dashboard',
        'dashboardUuid': dashboard_uuid,
        'canExportCsv': True,
    },
    'userAttributes': {
        'tenant_id': user['tenant_id'],
    },
    'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1)
}

token = jwt.encode(payload, LIGHTDASH_EMBED_SECRET, algorithm='HS256')
embed_url = f"{instance_url}/embed/{project_uuid}/dashboard/{dashboard_uuid}#{token}"
```

### Example 3: Ruby iframe Token Generation

```ruby
require 'jwt'

lightdash_embed_secret = ENV['LIGHTDASH_EMBED_SECRET']
instance_url = 'https://app.lightdash.cloud'
project_uuid = 'your-project-uuid'
dashboard_uuid = 'your-dashboard-uuid'

payload = {
  content: {
    type: 'dashboard',
    dashboardUuid: dashboard_uuid,
    canExportCsv: true
  },
  userAttributes: {
    tenant_id: user[:tenant_id]
  },
  exp: Time.now.to_i + 3600
}

token = JWT.encode(payload, lightdash_embed_secret, 'HS256')
embed_url = "#{instance_url}/embed/#{project_uuid}/dashboard/#{dashboard_uuid}##{token}"
```

### Example 4: Full React SDK Integration

**Backend (Express.js):**
```javascript
import express from 'express';
import jwt from 'jsonwebtoken';

const app = express();

app.get('/api/dashboard-token', authenticateUser, async (req, res) => {
  const user = await getUserFromDatabase(req.user.id);

  const token = jwt.sign({
    content: {
      type: 'dashboard',
      dashboardUuid: 'abc-123-def-456',
      dashboardFiltersInteractivity: { enabled: 'all' },
      canExportCsv: true,
      canExplore: true,
    },
    userAttributes: {
      tenant_id: user.tenantId,
    },
    user: {
      externalId: user.id,
      email: user.email,
    },
  }, process.env.LIGHTDASH_EMBED_SECRET, { expiresIn: '2h' });

  res.json({ token });
});

app.listen(3000);
```

**Frontend (React):**
```tsx
import { useState, useEffect } from 'react';
import Lightdash, { FilterOperator } from '@lightdash/sdk';

export function EmbeddedDashboard({ tenantId }: { tenantId: string }) {
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/dashboard-token')
      .then(res => res.json())
      .then(data => {
        setToken(data.token);
        setLoading(false);
      });
  }, []);

  if (loading) return <div>Loading...</div>;
  if (!token) return <div>Failed to load</div>;

  return (
    <div style={{ height: '100vh', width: '100%' }}>
      <Lightdash.Dashboard
        instanceUrl="https://app.lightdash.cloud"
        token={token}
        filters={[
          {
            model: 'orders',
            field: 'status',
            operator: FilterOperator.EQUALS,
            value: 'completed',
          },
          {
            model: 'dbt_users',
            field: 'created_date_week',
            operator: FilterOperator.IN_BETWEEN,
            value: ['2024-08', '2024-10'],
          },
        ]}
        styles={{
          backgroundColor: 'transparent',
          fontFamily: 'Inter, -apple-system, sans-serif',
        }}
        onExplore={({ chart }) => {
          console.log('User is exploring:', chart.name);
        }}
      />
    </div>
  );
}
```

### Example 5: React SDK Chart Embedding

**Token generation (backend):**
```javascript
export function generateChartToken(chartId: string) {
  return jwt.sign({
    content: {
      type: 'chart',
      contentId: chartId,
      canExportCsv: true,
      canExportImages: false,
      canViewUnderlyingData: true,
    },
  }, process.env.LIGHTDASH_EMBED_SECRET, { expiresIn: '24h' });
}
```

**Component:**
```tsx
<Lightdash.Chart
  instanceUrl="https://app.lightdash.cloud"
  id="your-saved-chart-uuid"
  token={generateChartToken('your-saved-chart-uuid')}
  styles={{ backgroundColor: '#ffffff' }}
/>
```

### Example 6: Next.js Server Component (iframe)

```tsx
import jwt from 'jsonwebtoken';

async function DashboardPage() {
  const token = jwt.sign({
    content: {
      type: 'dashboard',
      dashboardUuid: 'dashboard-uuid',
      canExportCsv: true,
    },
  }, process.env.LIGHTDASH_EMBED_SECRET!, { expiresIn: '24h' });

  const embedUrl = `https://app.lightdash.cloud/embed/project-uuid/dashboard/dashboard-uuid#${token}`;

  return (
    <iframe
      src={embedUrl}
      width="100%"
      height="600"
      frameBorder="0"
      style={{ border: 'none' }}
    />
  );
}
```

### Example 7: GitHub Actions Deploy Workflow (Production)

```yaml
name: Deploy to Lightdash

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup dbt profiles
        run: |
          mkdir -p ~/.dbt
          echo "$DBT_PROFILES" > ~/.dbt/profiles.yml
        env:
          DBT_PROFILES: ${{ secrets.DBT_PROFILES }}

      - name: Deploy to Lightdash
        run: |
          npm install -g @lightdash/cli
          lightdash deploy --target prod
        env:
          LIGHTDASH_API_KEY: ${{ secrets.LIGHTDASH_API_KEY }}
          LIGHTDASH_PROJECT: ${{ secrets.LIGHTDASH_PROJECT }}
          LIGHTDASH_URL: ${{ secrets.LIGHTDASH_URL }}
          CI: true
```

### Example 8: GitHub Actions Preview Workflow (Pull Requests)

```yaml
name: Lightdash Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup dbt profiles
        run: |
          echo "$DBT_PROFILES" > profiles.yml
        env:
          DBT_PROFILES: ${{ secrets.DBT_PROFILES }}

      - name: Start Lightdash preview
        run: |
          npm install -g @lightdash/cli
          lightdash start-preview \
            --project-dir . \
            --profiles-dir . \
            --name ${GITHUB_REF##*/} \
            --target ${{ github.actor }}
        env:
          LIGHTDASH_API_KEY: ${{ secrets.LIGHTDASH_API_KEY }}
          LIGHTDASH_PROJECT: ${{ secrets.LIGHTDASH_PROJECT }}
          LIGHTDASH_URL: ${{ secrets.LIGHTDASH_URL }}
          CI: true
```

---

## Cross-References

- [Lightdash CLI Reference](https://docs.lightdash.com/references/lightdash-cli.md)
- [Lightdash Embedding API Reference](https://docs.lightdash.com/references/embedding.md)
- [React SDK Reference](https://docs.lightdash.com/references/react-sdk.md)
- [iframe Embedding Reference](https://docs.lightdash.com/references/iframe-embedding.md)
- [CLI Actions Repository](https://github.com/lightdash/cli-actions) — ready-to-use GitHub Actions workflows
- [AI Agents Getting Started](https://docs.lightdash.com/guides/ai-agents/getting-started.md)
- [AI Agents Best Practices](https://docs.lightdash.com/guides/ai-agents/best-practices.md)
- [Verified Answers](https://docs.lightdash.com/guides/ai-agents/verified-answers.md)
- [Caching Guide](https://docs.lightdash.com/guides/developer/caching.md)
- [Virtual Views Guide](https://docs.lightdash.com/guides/developer/virtual-views.md)
