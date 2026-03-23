# LightDash: Integrations & Permissions

> Reference documentation for AI coding agents configuring LightDash integrations and managing access control.
> Sources: LightDash official documentation (docs.lightdash.com), fetched 2026-03-23.
> Covers roles, dbt integration, Slack, Google Sheets, user attributes, and SCIM provisioning.

---

## Roles & Access Control

LightDash uses a three-tier permission hierarchy: **organization roles** set a baseline across all projects, **project roles** control capabilities within a specific project, and **space roles** control access to individual spaces within a project.

### Organization Roles

Organization roles apply globally — a user with `org_admin` can access all projects and content whether or not they have been explicitly invited to those projects.

| Role | Creates Projects | Manages Org Access | Edits All Projects | Uses CLI / dbt Write-back | Creates Preview Projects |
|---|---|---|---|---|---|
| **org_admin** | Yes | Yes | Yes | Yes | Yes |
| **org_developer** | No | No | Yes | Yes | Yes |
| **org_editor** | No | No | Yes | No | No |
| **org_interactive_viewer** | No | No | No | No | No |
| **org_viewer** | No | No | No | No | No |
| **org_member** | No | No | No | No | No |

**Key behaviors:**
- `org_admin` has access to all content even without explicit project invitations.
- `org_member` is the default role assigned on invitation. Access is determined entirely by project-level assignments.
- `org_developer` and above can create personal access tokens.
- `org_viewer` cannot export all results to CSV (subject to export limits).

### Project Roles

Project roles scope permissions to a single project. Users without an org-wide role that grants access must be explicitly assigned a project role.

| Capability | project_admin | project_developer | project_editor | project_interactive_viewer | project_viewer |
|---|---|---|---|---|---|
| Manage project access | Yes | No | No | No | No |
| Delete project | Yes | No | No | No | No |
| Use SQL Runner | Yes | Yes | No | No | No |
| Create custom SQL dimensions | Yes | Yes | No | No | No |
| Create/edit charts & dashboards | Yes | Yes | Yes | No | No |
| Manage syncs (Google Sheets, etc.) | Yes | Yes | No | No | No |
| Create scheduled deliveries | Yes | Yes | Yes | Yes | No |
| Create comments | Yes | Yes | Yes | Yes | No |
| View underlying data | Yes | Yes | Yes | Yes | No |
| Export all results (override limit) | Yes | Yes | Yes | No | No |
| View charts & dashboards | Yes | Yes | Yes | Yes | Yes |
| Create queries in Explore | Yes | Yes | Yes | Yes | No |

**`project_interactive_viewer`** can create and manage their own scheduled deliveries; `project_admin`, `project_developer`, and `project_editor` can see and manage all scheduled deliveries in the project.

### Space Roles

Spaces are organizational containers within a project. Space-level permissions layer on top of project roles.

| Space Role | Manage Content | Manage Access | View Content |
|---|---|---|---|
| **Full Access** | Yes | Yes | Yes |
| **Can Edit** | Yes | No | Yes |
| **Can View** | No | No | Yes |

**Important constraint:** Space permissions control access to content within the space, but do not restrict what data a user can query or explore — that is governed by project role.

**Group inheritance:** When a user belongs to multiple groups with different space access levels, they inherit the highest level. Explicit individual user permissions always override group permissions.

### Custom Roles (Enterprise only)

Custom roles allow administrators to build granular permission sets beyond the five standard project roles.

**Creation path:** Settings → General Settings → Custom Roles → Create New Role.

Select individual scopes across three categories:
- **View permissions** — access to dashboards, charts, spaces
- **Create permissions** — ability to generate new content
- **Manage permissions** — rights to edit, delete, administer resources

Two SQL-specific scopes that operate independently:
- `Manage SQL Runner` — access to the SQL Runner tool for ad-hoc queries and virtual views
- `Manage Custom SQL` — create custom SQL dimensions in Explore view

**Additive model:** LightDash uses additive permissions. If a user already has a scope from their org-level role, assigning a custom project role will not restrict that access.

Custom roles are assigned in Project Settings → Access, to individual users or groups.

**Requirement:** Enterprise plan only.

### Auto-Join Configuration

Organization admins can designate specific email domains for automatic membership. Users signing up with a matching domain are auto-assigned configurable default org and project roles. Generic providers (gmail.com, etc.) cannot be used as auto-join domains.

---

## dbt Integration

LightDash is built on top of dbt — it reads your dbt project's `schema.yml` files to generate the metrics, dimensions, and tables visible in the Explore UI.

### Requirements

- dbt v1.4.0 or higher.
- The dbt project must be accessible via a git repository or dbt Cloud API.

### Connection Types

| Connection Type | How It Works | Limitations |
|---|---|---|
| **GitHub (OAuth)** | Persistent auth via OAuth app; enables PR creation for dbt write-back | Recommended for most teams |
| **GitHub (PAT)** | Personal access token with `repo` scope | Token tied to individual; breaks if user leaves |
| **GitHub (Fine-grained token)** | Scoped to specific repositories | More secure; no write-back |
| **GitLab** | Platform-specific token with repository read permissions | — |
| **Azure DevOps** | Repository token | — |
| **Bitbucket** | Repository token | — |
| **dbt Cloud** | Uses dbt Cloud Discovery API directly; no git access required | No write-back, no preview environments from UI, no automatic refresh on commit |
| **CLI / Local** | `lightdash deploy` from local machine | Only for self-hosted; not recommended for production |

**dbt Cloud configuration fields:**
- Service token with `Metadata Only` permission
- Environment ID (use your production environment ID)
- Discovery API endpoint

**Git repository configuration fields:**
- Repository: `organization/repository-name`
- Branch (default: `main`)
- Project directory path (use `/` if `dbt_project.yml` is at repo root)

### Sync Methods

| Method | Trigger | Use Case |
|---|---|---|
| **GitHub Actions (recommended)** | On push to branch | Production continuous deployment |
| **In-app Refresh** | Manual click on "Refresh dbt" in Query from tables page | Ad-hoc refresh after schema changes |
| **CLI deploy** | `lightdash deploy` command | Developer workflow; not recommended as sole production method |

**CLI environment variables for CI/CD:**
```bash
LIGHTDASH_API_KEY=<personal-access-token>
LIGHTDASH_URL=https://your-lightdash-instance.com
LIGHTDASH_PROJECT=<project-uuid>
```

Set `CI=true` to disable interactive prompts in pipelines.

**Before clicking "Refresh dbt":** If changes affect underlying data structure or dimension SQL, run `dbt run -m yourmodel` first.

### dbt Selectors

In Advanced settings, configure a dbt selector to limit which models LightDash compiles. Uses standard dbt selector syntax.

Example — include only models with a specific tag:
```
my_model tag:lightdash
```

The selector is applied before compilation, skipping excluded models entirely (not just hiding them from the UI).

### dbt Targets

Targets define the warehouse connection and schema configuration for a given environment (dev, prod, staging). Set in `profiles.yml`.

LightDash defaults to your `profiles.yml` default target. Override in Project Settings to point at a specific target (e.g., `prod`).

Macros that reference `target.name` will execute using the configured target name. This enables environment-specific behaviors such as schema naming conventions or warehouse sizing.

### Environment Variables

In Advanced settings, configure key-value pairs to inject environment variables. Available inside dbt macros via `env_var()`.

```yaml
# In dbt macro or schema.yml
{{ env_var('MY_VARIABLE', 'default_value') }}
```

Use this pattern when projects rely on dbt Cloud-style environment-variable-based configuration rather than target-based configuration.

### Defining Dimensions in dbt YAML

LightDash reads dimension configuration from the `meta.dimension` block in `schema.yml` (dbt ≤ v1.9) or `config.meta.dimension` (dbt ≥ v1.10).

**dbt ≤ v1.9:**
```yaml
models:
  - name: orders
    columns:
      - name: revenue_gbp_total_est
        description: 'Total estimated revenue in GBP.'
        meta:
          dimension:
            type: number
            label: 'Total revenue'
            format: '[$£]#,##0.00'
            groups: ['finance']
            hidden: false
```

**dbt ≥ v1.10:**
```yaml
models:
  - name: orders
    columns:
      - name: revenue_gbp_total_est
        config:
          meta:
            dimension:
              type: number
              label: 'Total revenue'
```

**Dimension properties:**

| Property | Type | Purpose |
|---|---|---|
| `type` | string | `string`, `number`, `timestamp`, `date`, `boolean` |
| `label` | string | Custom display name in the UI |
| `description` | string | Override the column description |
| `sql` | string | Custom SQL expression for the dimension |
| `hidden` | boolean | Hide from the Explore UI |
| `format` | string | Spreadsheet-style format string, e.g., `'$#,##0.00'` |
| `groups` | array | Sidebar category groupings |
| `time_intervals` | array | For date/timestamp: `['DAY', 'WEEK', 'MONTH', 'QUARTER']` |

**Additional dimensions** (multiple dimensions from one column):
```yaml
columns:
  - name: revenue
    meta:
      dimension:
        type: number
      additional_dimensions:
        revenue_in_thousands:
          type: number
          format: '#,##0," K"'
```

### Defining Metrics in dbt YAML

**dbt ≤ v1.9:**
```yaml
models:
  - name: orders
    columns:
      - name: order_id
        meta:
          metrics:
            total_order_count:
              type: count_distinct
      - name: order_value
        meta:
          metrics:
            total_sales:
              type: sum
```

**dbt ≥ v1.10:**
```yaml
models:
  - name: orders
    columns:
      - name: order_id
        config:
          meta:
            metrics:
              total_order_count:
                type: count_distinct
```

**LightDash native YAML format** (alternative to dbt schema.yml):
```yaml
type: model
name: orders

dimensions:
  - name: status
  - name: order_id
  - name: order_value

metrics:
  total_order_count:
    type: count_distinct
    sql: ${order_id}
  total_sales:
    type: sum
    sql: ${order_value}
    label: "Total sales (USD)"
    groups: ["Sales metrics"]
    round: 2
```

### CLI Key Commands

```bash
lightdash deploy            # Compile and deploy to production (pushes directly — use preview first)
lightdash preview           # Create temporary isolated preview environment
lightdash start-preview     # Create persistent preview project
lightdash compile           # Process LightDash resources using local files
lightdash dbt run           # Run dbt then auto-generate schema files
lightdash generate          # Create or update schema.yml for models
lightdash download          # Export charts and dashboards as code
lightdash upload            # Import modified content back to projects
lightdash rename            # Find-and-replace on field/table references
```

---

## Slack Integration

### Overview of Features

| Feature | Description |
|---|---|
| **Link unfurling** | LightDash chart/dashboard URLs automatically expand with visual previews in Slack |
| **Scheduled deliveries** | Send charts and dashboards to Slack channels or DMs on a schedule |
| **Saved chart alerts** | Conditional notifications when a saved chart meets defined criteria |
| **AI Agent** | Mention `@Lightdash` in a Slack thread to query data and generate charts conversationally |

### Setup (LightDash Cloud)

**Requirement:** Only Organization Admins can install the integration.

1. Navigate to **Organization settings** → **Integrations**.
2. Click **Add to Slack**.
3. Review and confirm the permissions page for the LightDash Slack App.
4. If you are not a Slack workspace admin, Slack may require admin approval before the app installs.

### OAuth Scopes

The LightDash Slack app requests:

| Scope | Purpose |
|---|---|
| `links:read` | Fetch information from charts and dashboards for unfurling |
| `links:write` | Display unfurl previews in channels |
| `app_mentions:read` | Enable AI agent `@mention` queries |
| `channels:join` | Join public channels for delivery |
| `chat:write` | Post messages and images |

### Advanced Configuration Options

| Setting | Details |
|---|---|
| **Notification channel** | Select a channel to receive alerts about failed scheduled deliveries |
| **Bot avatar** | Custom image URL (512×1024 px recommended) |
| **AI Agent OAuth** | When enabled, each Slack user authenticates individually; queries run under their LightDash permissions |

**Security note on unfurling:** Link previews execute queries using the credentials of the user who installed the Slack app — not the user who shared the link. Data visible in previews reflects that installer's access level.

### Scheduled Deliveries to Slack

**Who can create:** `project_admin`, `project_developer`, `project_editor`, `project_interactive_viewer` (own deliveries only).

**Creating a delivery:**
1. Open a chart or dashboard.
2. Click the three-dot menu → **Scheduled deliveries** → **Create new**.

**Configuration options:**

| Option | Details |
|---|---|
| **Name** | Appears as the message header in Slack |
| **Frequency** | Hourly, daily, weekly, monthly, or custom cron expression |
| **Time zone** | Defaults to project setting; overridable per delivery |
| **Format** | Image (visual snapshot) or CSV (downloadable data file) |
| **CSV row limit** | Current results, custom number, or all results (max 100,000 cells by default) |
| **Destinations** | Multiple channels (`#channel-name`) or DMs (`@person-name`) |
| **Dashboard filters** | Customize saved filters per delivery (dashboards only) |
| **Message customization** | Custom text in the Customization tab |

**Private channels:** The LightDash bot must be added manually — run `/invite @Lightdash` inside the channel, or add it via channel settings.

**File expiry:** Delivered files expire after 3 days by default. Self-hosted instances can adjust this via environment variable.

**Monitoring:** Project admins can view all deliveries, statuses, and history at Project Settings → Syncs & Scheduled Deliveries. Status values: `Completed`, `Failed`, `Partial failure`, `Running`, `Scheduled`.

### Self-Hosted Slack App Configuration

For self-hosted LightDash, create a custom Slack app using the manifest approach:

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From an app manifest**.
2. Replace `your-lightdash-deployment-url.com` in the manifest with your actual domain.

**Manifest key sections:**

```yaml
# OAuth redirect URLs (update domain)
https://your-lightdash-deployment-url.com/api/v1/slack/oauth_redirect
https://your-lightdash-deployment-url.com/api/v1/auth/slack/callback

# Event subscriptions request URL
https://your-lightdash-deployment-url.com/slack/events

# Bot scopes
app_mentions:read
channels:join
chat:write
links:read
links:write
```

3. From **Basic Information**, retrieve: Client ID, Client Secret, Signing Secret.

**Required environment variables:**
```bash
SLACK_CLIENT_ID=<client-id>
SLACK_CLIENT_SECRET=<client-secret>
SLACK_SIGNING_SECRET=<signing-secret>
SLACK_STATE_SECRET=<any-string>
```

**Socket Mode (for instances without public internet access):**
Generate an app-level token in the Slack app settings, then set:
```bash
SLACK_SOCKET_MODE=true
```
Reinstall the integration after enabling Socket Mode.

---

## Google Sheets Integration

### Overview

LightDash can sync chart results to Google Sheets on a schedule. Each chart supports multiple syncs. Data is automatically overwritten in the target sheet on each sync run.

### Setup (LightDash Cloud)

No separate installation step is required for cloud users. Authentication happens per-user via Google OAuth when creating the first sync.

**Google OAuth scopes requested:**
- `drive.file` — access to files created or opened by the app
- `spreadsheets` (optional) — broader spreadsheet access

### Creating a Sync

**Required permission:** Project Editor or above.

1. Open a chart in view or edit mode.
2. Click the three-dot menu (top-right) → **Google Sheets Sync**.
3. Configure the sync on the setup screen.

**Configuration options:**

| Option | Details |
|---|---|
| **Name** | Identifies the sync within LightDash |
| **Frequency** | Hourly, daily, weekly, monthly, or custom cron (all times in UTC) |
| **Sheet selection** | Choose target Google Sheet via Google Drive file picker |
| **Tab behavior** | Default: overwrite first tab. Enable "Save in new tab" to write to a dedicated named tab |

### Metadata Tab

LightDash automatically creates a `metadata` tab in the target spreadsheet documenting:
- Last update time
- Refresh frequency

### Administration

Only project admins can view all syncs in the project. Navigate to Project Settings → Syncs & Scheduled Deliveries.

### Self-Hosted Configuration

Self-hosted instances must configure Google OAuth and a Google Drive API key.

**Prerequisites:**
- Google SSO must be configured on the server (Google as a login provider can then be disabled via `AUTH_GOOGLE_ENABLED=false` while keeping the integration active).

**Steps:**
1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials), enable:
   - Google Picker API
   - Google Sheets API
2. Create an API key.
3. Set environment variable:

```bash
GOOGLE_DRIVE_API_KEY=<your-api-key>
```

The Google Drive file picker used during sync configuration requires this key.

---

## User Attributes

### What They Are

User attributes are organization-wide, text-only key-value pairs assigned to users or groups. They enable:
- Row-level security (filter data based on who is logged in)
- Column/table access control (restrict which fields are visible)
- Join condition customization per user

Use cases: sales region, department, PII access flag, financial data permissions.

### Managing User Attributes

**Only administrators can create, edit, and assign user attributes.**

**Creating an attribute:**
Navigate to Organization Settings → User Attributes → Create attribute.

**Assigning values:**
Assign values to individual users (by email) or to groups (by name). A default value can be set for users with no explicit assignment.

**Multiple group values:** When a user belongs to multiple groups with different values for the same attribute, all values are combined into an array and applied together (e.g., all matching rows are returned for `sql_filter`).

**Individual overrides groups:** An explicit per-user assignment takes precedence over group-level values.

### Referencing Attributes in dbt YAML

User attributes can be referenced in four YAML contexts:

| Context | Location | Logic | Use For |
|---|---|---|---|
| `sql_filter` | Model level | Filters rows returned | Row-level security |
| `required_attributes` | Column/dimension level | AND — all must match | Restrict column access |
| `any_attributes` | Column/dimension level | OR — any must match | Flexible column access |
| `sql_on` | Join condition | Filters join results | Row-level security on joined tables |

**Cannot** be used inside `sql:` tags directly.

### Syntax

```yaml
# Standard attribute reference
${lightdash.attributes.my_attr_1}

# Aliases (all equivalent)
${ld.attr.my_attr_1}
${ld.attribute.my_attr_1}

# Intrinsic attribute — logged-in user's verified email
${lightdash.user.email}
```

### YAML Examples

**Row-level security with `sql_filter`:**
```yaml
models:
  - name: sales_data
    meta:
      sql_filter: ${TABLE}.sales_region IN (${lightdash.attributes.sales_region})
    columns:
      - name: revenue
```

**Column access — AND logic (`required_attributes`):**
```yaml
columns:
  - name: salary
    meta:
      dimension:
        required_attributes:
          is_admin: "true"
          team_name: "HR"
```

**Column access — OR logic (`any_attributes`):**
```yaml
columns:
  - name: deal_value
    meta:
      dimension:
        any_attributes:
          department: ["sales", "finance"]
          role: "analyst"
```

**Combining both (user must satisfy both blocks):**
```yaml
columns:
  - name: pii_field
    meta:
      dimension:
        required_attributes:
          access_level: "2"
        any_attributes:
          department: ["legal", "compliance"]
```

**Email-based row filter:**
```yaml
models:
  - name: user_data
    meta:
      sql_filter: ${TABLE}.email = '${lightdash.user.email}'
```

**Join-level row filter (`sql_on`):**
```yaml
joins:
  - join: user_permissions
    sql_on: >
      ${user_permissions.user_email} = '${lightdash.user.email}'
```

### Security Limitations

| Limitation | Detail |
|---|---|
| Custom SQL bypass | Users with SQL Runner access can write queries that bypass `required_attributes` and `any_attributes` protections |
| Scheduled deliveries | Run using the creator's attribute context — not the recipient's |
| Intrinsic email attribute | Requires verified email; cannot be used with `required_attributes` or `any_attributes` |
| Development access | Developers with SQL Runner access can view all data regardless of attribute filters |

---

## SCIM Provisioning

### Overview

SCIM (System for Cross-domain Identity Management) 2.0 automates user and group provisioning from an external Identity Provider (IdP) into LightDash. Instead of manually managing users in LightDash, your IdP becomes the source of truth.

**Requirement:** Enterprise plan only. For self-hosted instances using SCIM with SSO, enable: `AUTH_ENABLE_OIDC_TO_EMAIL_LINKING=true`.

### Supported Identity Providers

- Okta (SCIM 2.0 Test App with header authentication)
- Azure Entra ID (non-gallery application)
- OneLogin and any provider implementing SCIM 2.0

### Generating a SCIM Token

1. Navigate to **User Settings** → **SCIM Access Tokens**.
2. Click **Generate new token** — provide a name and optional expiration date.
3. Copy and save the token immediately (it cannot be retrieved after this step).
4. Note the **SCIM URL** displayed — this is the base URL to configure in your IdP.

**SCIM base URL format:** `https://<your-lightdash-url>/api/v1/scim/v2/`

Token rotation is supported via PATCH requests (minimum once per hour). Provide the token UUID and a new expiration date.

### Key Attribute Mapping

| SCIM Attribute | LightDash Field |
|---|---|
| `userName` | User's primary email address |
| `roles[].value` | Organization or project role |

**Critical:** The IdP must set `userName` to the user's primary email address.

**Azure note:** Azure's email field is user-editable and not reliable. Use `userPrincipalName` (UPN) as the email claim for Azure deployments.

### Role Provisioning via SCIM

LightDash supports the standard SCIM 2.0 `roles` attribute (RFC 7643).

**Organization role values:**
```
member | viewer | interactive_viewer | editor | developer | admin
```

**Project role values** (scoped to a project UUID):
```
<project-uuid>:viewer
<project-uuid>:interactive_viewer
<project-uuid>:editor
<project-uuid>:developer
<project-uuid>:admin
<project-uuid>:<custom-role-name>
```

### Behavior Rules

| Rule | Detail |
|---|---|
| Minimum one admin | SCIM requests that would remove all org admins are rejected |
| Deactivating users | Setting `active: false` demotes the user to `member` and removes all project and group access |
| One role per scope | Each user has one org role and one role per project |
| Preview projects | SCIM cannot manage roles on preview projects |
| PATCH omission | Omitting `roles` in a PATCH request leaves existing roles unchanged |

### SCIM API Endpoints

All endpoints are under `/api/v1/scim/v2/`. Authenticate using a LightDash personal access token.

| Operation | Method | Path |
|---|---|---|
| List users | GET | `/Users` |
| Get user | GET | `/Users/{id}` |
| Create user | POST | `/Users` |
| Update user (full) | PUT | `/Users/{id}` |
| Update user (partial) | PATCH | `/Users/{id}` |
| Delete user | DELETE | `/Users/{id}` |
| List groups | GET | `/Groups` |
| Get group | GET | `/Groups/{id}` |
| Create group | POST | `/Groups` |
| Replace group | PUT | `/Groups/{id}` |
| Patch group | PATCH | `/Groups/{id}` |
| Delete group | DELETE | `/Groups/{id}` |
| Provider config | GET | `/ServiceProviderConfig` |
| Resource types | GET | `/ResourceTypes` |
| Schemas | GET | `/Schemas` |

---

## Summary: Permission Decision Matrix

Use this matrix when deciding which role or mechanism to use for a given access pattern.

| Access Pattern | Recommended Mechanism |
|---|---|
| Read-only stakeholder across all projects | `org_viewer` or `org_interactive_viewer` |
| Analyst who builds charts in one project | `project_editor` on that project |
| Developer needing SQL Runner access | `project_developer` or `project_admin` |
| Fine-grained permission set (e.g., can view but not export) | Custom role (Enterprise) |
| Row-level data isolation per user | User attributes + `sql_filter` in dbt YAML |
| Column-level data access control | User attributes + `required_attributes` / `any_attributes` |
| Bulk user provisioning from Okta/Azure | SCIM provisioning (Enterprise) |
| Email-domain-based auto-membership | Auto-join configuration in Org Settings |
| Restrict access within a project space | Space roles (Full Access / Can Edit / Can View) |

---

## Cross-References

- LightDash roles reference: `https://docs.lightdash.com/references/workspace/roles.md`
- LightDash SCIM reference: `https://docs.lightdash.com/references/workspace/scim-integration.md`
- LightDash user attributes reference: `https://docs.lightdash.com/references/workspace/user-attributes.md`
- LightDash Slack integration reference: `https://docs.lightdash.com/references/integrations/slack-integration.md`
- LightDash Google Sheets reference: `https://docs.lightdash.com/references/integrations/google-sheets.md`
- LightDash dbt projects reference: `https://docs.lightdash.com/references/integrations/dbt-projects.md`
- Self-host Slack app configuration: `https://docs.lightdash.com/self-host/customize-deployment/configure-a-slack-app-for-lightdash.md`
- Self-host Google Sheets configuration: `https://docs.lightdash.com/self-host/customize-deployment/google-sheets-integration.md`
- Custom roles reference: `https://docs.lightdash.com/references/workspace/custom-roles.md`
