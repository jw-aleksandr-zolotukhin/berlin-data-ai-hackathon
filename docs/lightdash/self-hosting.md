# LightDash: Self-Hosting

> Reference documentation for AI coding agents deploying and configuring Lightdash in self-hosted environments.
> Sources: https://docs.lightdash.com/self-host/ (fetched 2026-03-23).
> Covers Docker Compose, Kubernetes/Helm, all environment variables, SSO, storage, database, monitoring, and production hardening.

---

## Overview & Requirements

### What Is Self-Hosting

Lightdash is MIT-licensed open-source software. Self-hosting runs it on your own infrastructure. Lightdash Cloud is the recommended path for most teams — self-hosting is appropriate for:

- **Enterprise POCs**: Large orgs awaiting cloud approval
- **Hobbyist/experimental projects**
- **Customization needs**: Tailored functionality or compliance requirements

Self-hosting carries no warranty or support from the Lightdash team. Enterprise features (query result caching, SCIM, custom roles, AI Analyst, embedding) require a separate enterprise license key.

### Prerequisites

The operator must have working knowledge of:

- Docker and Docker Compose
- Kubernetes and `kubectl` (for production deployments)
- Environment variable configuration
- SMTP credentials and database connections

### System Requirements

| Component | CPU | Memory | Ephemeral Storage |
|---|---|---|---|
| Lightdash (app server) | 1 core | 1.5 Gi | 1 Gi |
| BrowserlessChrome (headless) | 2 cores | 4 Gi | 1 Gi |
| Scheduler worker | 1 core | 1425 Mi | 1 Gi |

PostgreSQL version 12 or higher is required. The `uuid-ossp` extension must be installed.

### Two Deployment Paths

| Option | When to Use |
|---|---|
| **Kubernetes + Helm** (recommended) | Production deployments; scalable, flexible |
| **Docker Compose** | Proof-of-concept or local evaluation only |

---

## Docker Compose Deployment

Docker Compose is suitable for local evaluation only. The instance is not internet-accessible by default.

### Step 1: Clone the Repository

```bash
git clone https://github.com/lightdash/lightdash
cd lightdash
```

### Step 2: Configure the `.env` File

Edit the `.env` file in the repo root. Minimum required values:

```env
PGHOST=db
PGPORT=5432
PGUSER=<your postgres user>
PGPASSWORD=<your postgres password>
PGDATABASE=postgres
DBT_DEMO_DIR=<path to examples/full-jaffle-shop-demo>
```

### Step 3: Set Critical Variables and Launch

`LIGHTDASH_SECRET` encrypts database data at rest. **Losing this key makes all stored data unrecoverable.** Store it securely.

```bash
export LIGHTDASH_SECRET="use-a-strong-random-value-here"
export PGPASSWORD="your-postgres-password"

docker compose -f docker-compose.yml --env-file .env up --detach --remove-orphans
```

### Windows Note

If you encounter timeout errors on Windows, go to Docker Settings > General and enable "Expose daemon on tcp://localhost:2375 without TLS".

---

## Kubernetes / Helm Deployment

### Step 1: Add the Helm Repository

```bash
helm repo add lightdash https://lightdash.github.io/helm-charts
```

The chart is community-maintained at https://github.com/lightdash/helm-charts.

### Step 2: Create a Namespace

```bash
kubectl create namespace lightdash
```

### Step 3: Create `values.yaml`

Helm values are split into three stanzas:

| Stanza | Use For |
|---|---|
| `configMap` | Non-sensitive values (URLs, regions, feature flags) |
| `secrets` | Passwords, API keys, tokens |
| `extraEnv` | Additional variables not covered by the chart |

Minimum viable `values.yaml`:

```yaml
secrets:
  LIGHTDASH_SECRET: "use-a-strong-random-value-here"
  PGPASSWORD: "your-postgres-password"
  S3_ACCESS_KEY: "your-s3-access-key"
  S3_SECRET_KEY: "your-s3-secret-key"

configMap:
  SITE_URL: "https://lightdash.mycompany.com"
  PGHOST: "your-postgres-host"
  PGPORT: "5432"
  PGUSER: "lightdash"
  PGDATABASE: "lightdash"
  S3_REGION: "us-east-1"
  S3_BUCKET: "lightdash-files"
  S3_ENDPOINT: "https://s3.amazonaws.com"

service:
  type: NodePort   # or LoadBalancer for external access
```

### Step 4: Install with Helm

```bash
helm install lightdash lightdash/lightdash -n lightdash -f values.yaml
```

Alternatively, render to a manifest and apply with kubectl:

```bash
helm template lightdash lightdash/lightdash -n lightdash -f values.yaml > lightdash.yaml
kubectl apply -f lightdash.yaml
```

### Step 5: Configure HTTPS / Ingress

Add to `values.yaml`:

```yaml
service:
  type: NodePort

ingress:
  enabled: true
  hosts:
    - host: lightdash.mycompany.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: lightdash-tls
      hosts:
        - lightdash.mycompany.com
```

Required environment variables for HTTPS:

```yaml
configMap:
  SITE_URL: "https://lightdash.mycompany.com"
  TRUST_PROXY: "true"     # if TLS is terminated at a proxy/load balancer
  SECURE_COOKIES: "true"  # restrict cookies to HTTPS only
```

---

## Environment Variables Reference

### Core Database (PostgreSQL)

| Variable | Required | Default | Description |
|---|---|---|---|
| `PGHOST` | Yes | — | PostgreSQL server hostname |
| `PGPORT` | Yes | — | PostgreSQL server port (typically 5432) |
| `PGUSER` | Yes | — | PostgreSQL username |
| `PGPASSWORD` | Yes | — | PostgreSQL password |
| `PGDATABASE` | Yes | — | PostgreSQL database name |
| `PGCONNECTIONURI` | No | — | Full connection URI (alternative to individual PG vars) |
| `PGMAXCONNECTIONS` | No | — | Maximum database connections in pool |
| `PGMINCONNECTIONS` | No | — | Minimum database connections in pool |

### Security & Session

| Variable | Required | Default | Description |
|---|---|---|---|
| `LIGHTDASH_SECRET` | **Yes** | — | Encryption key for data at rest. Must be kept secret and never rotated without a migration plan. |
| `SECURE_COOKIES` | No | `false` | Restrict cookies to HTTPS connections only. Set `true` in production. |
| `COOKIES_MAX_AGE_HOURS` | No | — | Session timeout in hours |
| `TRUST_PROXY` | No | `false` | Trust `X-Forwarded-Proto` header from reverse proxies |
| `LIGHTDASH_CSP_REPORT_ONLY` | No | `true` | Content Security Policy report-only mode |
| `LIGHTDASH_CSP_ALLOWED_DOMAINS` | No | — | CSP-approved domains (comma-separated) |
| `LIGHTDASH_CSP_REPORT_URI` | No | — | CSP violation report endpoint |
| `LIGHTDASH_CORS_ENABLED` | No | `false` | Enable CORS |
| `LIGHTDASH_CORS_ALLOWED_DOMAINS` | No | — | CORS-approved domains (comma-separated) |

### Site & Network

| Variable | Required | Default | Description |
|---|---|---|---|
| `SITE_URL` | No | `http://localhost:8080` | Full URL where Lightdash is hosted (with protocol). Used in all generated links. |
| `INTERNAL_LIGHTDASH_HOST` | No | Same as `SITE_URL` | Internal host for headless browser connectivity |
| `STATIC_IP` | No | `http://localhost:8080` | Server static IP for data warehouse allowlisting |

### Query & Performance

| Variable | Required | Default | Description |
|---|---|---|---|
| `LIGHTDASH_QUERY_MAX_LIMIT` | No | `5000` | Maximum rows returned per query |
| `LIGHTDASH_QUERY_DEFAULT_LIMIT` | No | `500` | Default row count for queries |
| `LIGHTDASH_QUERY_MAX_PAGE_SIZE` | No | `2500` | Maximum paginated result size |
| `LIGHTDASH_CSV_CELLS_LIMIT` | No | `100000` | Maximum cells in CSV exports |
| `LIGHTDASH_PIVOT_TABLE_MAX_COLUMN_LIMIT` | No | `200` | Maximum columns in pivot tables |
| `LIGHTDASH_MAX_PAYLOAD` | No | `5mb` | Maximum HTTP request body size |

### Scheduler

| Variable | Required | Default | Description |
|---|---|---|---|
| `SCHEDULER_ENABLED` | No | `true` | Enable the scheduled delivery worker |
| `SCHEDULER_CONCURRENCY` | No | `3` | Concurrent job processing limit |
| `SCHEDULER_JOB_TIMEOUT` | No | `600000` (10 min) | Job timeout in milliseconds |
| `SCHEDULER_SCREENSHOT_TIMEOUT` | No | — | Screenshot capture timeout in milliseconds |
| `SCHEDULER_INCLUDE_TASKS` | No | — | Comma-separated task whitelist |
| `SCHEDULER_EXCLUDE_TASKS` | No | — | Comma-separated task blacklist |

### Feature Flags

| Variable | Required | Default | Description |
|---|---|---|---|
| `GROUPS_ENABLED` | No | `false` | Enable groups functionality |
| `CUSTOM_VISUALIZATIONS_ENABLED` | No | `false` | Enable custom chart types |
| `ALLOW_MULTIPLE_ORGS` | No | `false` | Allow separate user organizations |
| `DISABLE_PAT` | No | `false` | Disable Personal Access Tokens |
| `DISABLE_DASHBOARD_COMMENTS` | No | `false` | Disable dashboard comments |
| `ORGANIZATION_WAREHOUSE_CREDENTIALS_ENABLED` | No | `false` | Enable org-level warehouse settings |
| `HEADWAY_ENABLED` | No | `true` | Show changelog widget in the UI |
| `EXTENDED_USAGE_ANALYTICS` | No | `false` | Enable extended usage analytics |
| `MICROSOFT_TEAMS_ENABLED` | No | `false` | Enable Microsoft Teams integration |

### Personal Access Tokens

| Variable | Required | Default | Description |
|---|---|---|---|
| `PAT_ALLOWED_ORG_ROLES` | No | All roles | Comma-separated roles permitted to create PATs |
| `PAT_MAX_EXPIRATION_TIME_IN_DAYS` | No | — | Maximum PAT validity period |
| `DISABLE_PAT` | No | `false` | Disable PAT functionality entirely |

### Downloads & Exports

| Variable | Required | Default | Description |
|---|---|---|---|
| `MAX_DOWNLOADS_AS_CODE` | No | `100` | Maximum code download limit |
| `PERSISTENT_DOWNLOAD_URLS_ENABLED` | No | `false` | Enable persistent Lightdash-hosted download URLs |
| `PERSISTENT_DOWNLOAD_URL_EXPIRATION_SECONDS` | No | `259200` (3 days) | URL validity duration |
| `PERSISTENT_DOWNLOAD_URL_EXPIRATION_SECONDS_EMAIL` | No | Inherits main | Email link expiration override |
| `PERSISTENT_DOWNLOAD_URL_EXPIRATION_SECONDS_SLACK` | No | Inherits main | Slack link expiration override |
| `PERSISTENT_DOWNLOAD_URL_EXPIRATION_SECONDS_MSTEAMS` | No | Inherits main | Teams link expiration override |

### Deployment Mode

| Variable | Required | Default | Description |
|---|---|---|---|
| `LIGHTDASH_MODE` | No | `default` | Deployment mode (`default`, `demo`, `pr`) |
| `LIGHTDASH_LICENSE_KEY` | No | — | Enterprise license key |

### Headless Browser

| Variable | Required | Default | Description |
|---|---|---|---|
| `HEADLESS_BROWSER_HOST` | No | — | Hostname of the Browserless Chromium service. Use `headless-browser` in Docker, `localhost` for host network. |
| `HEADLESS_BROWSER_PORT` | No | `3001` | Port for the headless browser service |
| `USE_SECURE_BROWSER` | No | `false` | Use WSS (secure WebSocket) for browser connection |

Recommended image: `ghcr.io/browserless/chromium:v2.24.3`

The `SITE_URL` must be reachable from the headless browser container. Charts and dashboard screenshots are captured via Playwright, stored in S3, and delivered via email/Slack.

---

## Database & Storage Configuration

### External PostgreSQL

For production, always use a managed PostgreSQL service (RDS, Cloud SQL, Azure Database for PostgreSQL).

**Requirements:**
- PostgreSQL version 12 or higher
- Extension: `uuid-ossp` must be installed before first startup

**Helm `values.yaml`:**

```yaml
postgresql:
  enabled: false   # disable the bundled PostgreSQL sidecar

externalDatabase:
  host: your-postgres-host.example.com
  port: 5432
  username: lightdash
  database: lightdash
```

Pass the password via `secrets`:

```yaml
secrets:
  PGPASSWORD: "your-postgres-password"
```

**Automatic Migrations:** Database schema migrations run automatically on server and worker startup. No manual migration steps are required during upgrades. If a `pg_lock` error occurs, inspect the `knex_migrations_lock` table and manually release the lock.

### S3-Compatible Object Storage

S3 storage is **required** for production. It stores exported images, file exports, and scheduler screenshots.

**Supported providers:**
- Amazon S3
- Google Cloud Storage (via S3-compatible API)
- MinIO
- Azure Blob (via MinIO or s3proxy — not natively S3-compatible)

#### Amazon S3

```yaml
secrets:
  S3_ACCESS_KEY: "your-access-key-id"
  S3_SECRET_KEY: "your-secret-access-key"

configMap:
  S3_ENDPOINT: "https://s3.us-east-1.amazonaws.com"
  S3_REGION: "us-east-1"
  S3_BUCKET: "lightdash-files"
```

Alternatively, use IAM roles (omit `S3_ACCESS_KEY`/`S3_SECRET_KEY`; the SDK picks up the instance role automatically).

#### Google Cloud Storage

1. Create a GCS bucket (Standard class, fine-grained access control).
2. In Settings > Interoperability, generate HMAC credentials.

```yaml
secrets:
  S3_ACCESS_KEY: "your-hmac-access-key"
  S3_SECRET_KEY: "your-hmac-secret"

configMap:
  S3_ENDPOINT: "https://storage.googleapis.com"
  S3_REGION: "auto"
  S3_BUCKET: "your-bucket-name"
```

#### MinIO

```yaml
secrets:
  S3_ACCESS_KEY: "your-minio-access-key"
  S3_SECRET_KEY: "your-minio-secret-key"

configMap:
  S3_ENDPOINT: "https://minio.internal.example.com"
  S3_REGION: "us-east-1"
  S3_BUCKET: "lightdash"
  S3_FORCE_PATH_STYLE: "true"   # required for MinIO
```

#### S3 Environment Variables Reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `S3_ENDPOINT` | Yes | — | S3 endpoint URL |
| `S3_BUCKET` | Yes | — | Bucket name |
| `S3_REGION` | Yes | — | Bucket region |
| `S3_ACCESS_KEY` | No | — | Access key (not needed with IAM roles) |
| `S3_SECRET_KEY` | No | — | Secret key (not needed with IAM roles) |
| `S3_USE_CREDENTIALS_FROM` | No | — | Credential chain: `env`, `token_file`, `ini`, `ecs`, `ec2` |
| `S3_EXPIRATION_TIME` | No | `259200` (3 days) | File expiration in seconds |
| `S3_FORCE_PATH_STYLE` | No | `false` | Force path-style addressing (required for MinIO) |
| `RESULTS_S3_BUCKET` | No | `S3_BUCKET` | Separate bucket for query results |
| `RESULTS_S3_REGION` | No | `S3_REGION` | Region for query results bucket |
| `RESULTS_S3_ACCESS_KEY` | No | `S3_ACCESS_KEY` | Access key for results bucket |
| `RESULTS_S3_SECRET_KEY` | No | `S3_SECRET_KEY` | Secret key for results bucket |

**Note:** IAM-generated signed URLs expire within 7 days maximum.

#### Query Results Caching (Enterprise)

| Variable | Required | Default | Description |
|---|---|---|---|
| `RESULTS_CACHE_ENABLED` | No | `false` | Enable query result caching |
| `AUTOCOMPLETE_CACHE_ENABLED` | No | `false` | Enable filter autocomplete caching |
| `CACHE_STALE_TIME_SECONDS` | No | `86400` (24 h) | Cache validity duration |

---

## SSO & Authentication

Multiple authentication methods can be active simultaneously (e.g., "Password + Okta" or "Google + Azure AD + OneLogin").

### Disabling Password Authentication

```yaml
configMap:
  AUTH_DISABLE_PASSWORD_AUTHENTICATION: "true"
```

To override a user's password from the server shell:
```bash
cd ./packages/backend && node ./dist/overrideUserPassword.js <user-email> <new-password>
```

### General SSO Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `AUTH_DISABLE_PASSWORD_AUTHENTICATION` | No | `false` | Disable email/password login |
| `AUTH_ENABLE_GROUP_SYNC` | No | `false` | Enable SSO group-to-Lightdash-group sync (deprecated; use SCIM) |
| `AUTH_ENABLE_OIDC_LINKING` | No | `false` | Link OIDC identities by matching email |
| `AUTH_ENABLE_OIDC_TO_EMAIL_LINKING` | No | `false` | Link OIDC logins to existing email-based accounts |

### Google OAuth

**Setup:**
1. Create an OAuth 2.0 Web Client ID in Google Cloud Console.
2. Add authorized origin: `https://<lightdash-domain>`
3. Add redirect URI: `https://<lightdash-domain>/api/v1/oauth/redirect/google`

```yaml
configMap:
  AUTH_GOOGLE_ENABLED: "true"
secrets:
  AUTH_GOOGLE_OAUTH2_CLIENT_ID: "your-client-id"
  AUTH_GOOGLE_OAUTH2_CLIENT_SECRET: "your-client-secret"
```

### Okta (OIDC)

**Setup:**
1. In Okta admin, create a Web application with OIDC sign-in.
2. Redirect URI: `<lightdash-url>/api/v1/oauth/redirect/okta`
3. Initiate login URI: `<lightdash-url>/api/v1/login/okta`

| Variable | Required | Description |
|---|---|---|
| `AUTH_OKTA_DOMAIN` | Yes | Okta domain (no `https://`) |
| `AUTH_OKTA_OAUTH_CLIENT_ID` | Yes | Application client ID |
| `AUTH_OKTA_OAUTH_CLIENT_SECRET` | Yes | Application client secret |
| `AUTH_OKTA_OAUTH_ISSUER` | Yes | Authorization server issuer URI (include `https://`) |
| `AUTH_OKTA_AUTHORIZATION_SERVER_ID` | No | Custom authorization server ID |
| `AUTH_OKTA_EXTRA_SCOPES` | No | Additional scopes, e.g., `groups` |
| `AUTH_ENABLE_GROUP_SYNC` | No | Set `"true"` for automatic group assignment (deprecated) |

### Azure Active Directory

**Setup:**
1. Register a new app in Azure portal.
2. Redirect URI: `<lightdash-url>/api/v1/oauth/redirect/azuread`
3. Copy Application (client) ID and Directory (tenant) ID.
4. Create a client secret in Certificates & Secrets.

| Variable | Required | Description |
|---|---|---|
| `AUTH_AZURE_AD_OAUTH_CLIENT_ID` | Yes | Application (client) ID |
| `AUTH_AZURE_AD_OAUTH_CLIENT_SECRET` | Yes | Client secret value |
| `AUTH_AZURE_AD_OAUTH_TENANT_ID` | Yes | Directory (tenant) ID |
| `AUTH_AZURE_AD_OIDC_METADATA_ENDPOINT` | No | OIDC metadata endpoint override |
| `AUTH_AZURE_AD_X509_CERT_PATH` | No | Path to certificate file |
| `AUTH_AZURE_AD_X509_CERT` | No | Certificate content (inline) |
| `AUTH_AZURE_AD_PRIVATE_KEY_PATH` | No | Path to private key file |
| `AUTH_AZURE_AD_PRIVATE_KEY` | No | Private key content (inline) |

### OneLogin

**Setup:**
1. Create an OIDC application in OneLogin admin.
2. Login URL: `<site_url>/api/v1/login/oneLogin`
3. Redirect URL: `<site_url>/api/v1/oauth/redirect/oneLogin`
4. Application type: Web; Token endpoint: POST; enable login hint.

| Variable | Required | Description |
|---|---|---|
| `AUTH_ONE_LOGIN_OAUTH_CLIENT_ID` | Yes | OneLogin client ID |
| `AUTH_ONE_LOGIN_OAUTH_CLIENT_SECRET` | Yes | OneLogin client secret |
| `AUTH_ONE_LOGIN_OAUTH_ISSUER` | Yes | OneLogin issuer URL |

### Generic OpenID Connect

Supports any OIDC-compliant identity provider.

**Authentication methods:** `client_secret_basic` (default) or `private_key_jwt`

| Variable | Required | Description |
|---|---|---|
| `AUTH_OIDC_CLIENT_ID` | Yes | OIDC client ID |
| `AUTH_OIDC_METADATA_DOCUMENT_URL` | Yes | OIDC discovery endpoint (`.well-known/openid-configuration`) |
| `AUTH_OIDC_CLIENT_SECRET` | Conditional | Required unless using `private_key_jwt` |
| `AUTH_OIDC_AUTH_METHOD` | No | Authentication method override |
| `AUTH_OIDC_SCOPES` | No | Space-delimited scope list |
| `AUTH_OIDC_X509_CERT` | No | Certificate content for `private_key_jwt` |
| `AUTH_OIDC_PRIVATE_KEY` | No | Private key for `private_key_jwt` |
| `AUTH_OIDC_X509_CERT_PATH` | No | Path to certificate file |
| `AUTH_OIDC_PRIVATE_KEY_PATH` | No | Path to private key file |

### Enterprise: SCIM Provisioning

```yaml
configMap:
  SCIM_ENABLED: "true"
```

SCIM is preferred over `AUTH_ENABLE_GROUP_SYNC` for automated user provisioning and group management. Requires enterprise license.

### Email (SMTP) for Password Resets

SMTP is required for password reset emails. It is also used by the scheduler for scheduled delivery notifications.

| Variable | Required | Default | Description |
|---|---|---|---|
| `EMAIL_SMTP_HOST` | Yes | — | SMTP server hostname |
| `EMAIL_SMTP_USER` | Yes | — | SMTP authentication username |
| `EMAIL_SMTP_SENDER_EMAIL` | Yes | — | From address for outgoing emails |
| `EMAIL_SMTP_PASSWORD` | Conditional [1] | — | SMTP password |
| `EMAIL_SMTP_ACCESS_TOKEN` | Conditional [1] | — | OAuth2 access token (alternative to password) |
| `EMAIL_SMTP_PORT` | No | `587` | SMTP server port |
| `EMAIL_SMTP_SECURE` | No | `true` | Use TLS/SSL connection |
| `EMAIL_SMTP_SENDER_NAME` | No | `Lightdash` | Display name for sender |
| `EMAIL_SMTP_ALLOW_INVALID_CERT` | No | `false` | Accept self-signed certificates |
| `EMAIL_SMTP_IMAGE_INLINE_CID` | No | `false` | Embed images as CID (for deployments behind firewalls where email clients cannot reach internal image URLs) |

[1] Either `EMAIL_SMTP_PASSWORD` or `EMAIL_SMTP_ACCESS_TOKEN` is required.

---

## Integrations

### Slack

**Setup:**
1. Create a Slack app from a manifest at https://api.slack.com/apps — select "From an app manifest".
2. Replace `your-lightdash-deployment-url.com` with your actual URL in the manifest.
3. Collect credentials from the app's Basic Information section.

| Variable | Required | Default | Description |
|---|---|---|---|
| `SLACK_CLIENT_ID` | Yes | — | Must be quoted as a string |
| `SLACK_CLIENT_SECRET` | Yes | — | Slack app client secret |
| `SLACK_SIGNING_SECRET` | Yes | — | Used to verify Slack requests |
| `SLACK_STATE_SECRET` | No | `slack-state-secret` | Any string value |
| `SLACK_APP_TOKEN` | No | — | Required for Socket Mode |
| `SLACK_SOCKET_MODE` | No | `false` | Use WebSocket instead of HTTP webhooks |
| `SLACK_PORT` | No | `4351` | Slack integration port |
| `SLACK_CHANNELS_CACHED_TIME` | No | `600000` (10 min) | Channel list cache duration (ms) |

**Socket Mode** (for instances not publicly accessible): enable in Slack app settings, generate an app-level token, set `SLACK_APP_TOKEN` and `SLACK_SOCKET_MODE=true`.

### GitHub

| Variable | Required | Description |
|---|---|---|
| `GITHUB_APP_ID` | Yes | GitHub App ID |
| `GITHUB_APP_NAME` | Yes | App display name |
| `GITHUB_CLIENT_ID` | Yes | OAuth client ID |
| `GITHUB_CLIENT_SECRET` | Yes | OAuth client secret |
| `GITHUB_PRIVATE_KEY` | Yes | App private key |
| `GITHUB_REDIRECT_DOMAIN` | No | OAuth redirect domain |

### Microsoft Teams

```yaml
configMap:
  MICROSOFT_TEAMS_ENABLED: "true"
```

### Google Cloud Platform

| Variable | Required | Default | Description |
|---|---|---|---|
| `GOOGLE_CLOUD_PROJECT_ID` | No | — | GCP project ID |
| `GOOGLE_DRIVE_API_KEY` | No | — | Google Drive API key |
| `AUTH_ENABLE_GCLOUD_ADC` | No | `false` | Use Application Default Credentials for GCP |

---

## Monitoring & Logging

### Logging Configuration

By default, logs go to the console in pretty (human-readable) format. All logging variables are optional.

| Variable | Default | Description |
|---|---|---|
| `LIGHTDASH_LOG_LEVEL` | `INFO` | Minimum severity: `DEBUG`, `AUDIT`, `HTTP`, `INFO`, `WARN`, `ERROR` |
| `LIGHTDASH_LOG_FORMAT` | `pretty` | Output format: `PLAIN`, `PRETTY`, `JSON` |
| `LIGHTDASH_LOG_OUTPUTS` | `console` | Destination(s) for logs |
| `LIGHTDASH_LOG_CONSOLE_LEVEL` | Inherits `LOG_LEVEL` | Console-specific severity override |
| `LIGHTDASH_LOG_CONSOLE_FORMAT` | Inherits `LOG_FORMAT` | Console-specific format override |
| `LIGHTDASH_LOG_FILE_LEVEL` | Inherits `LOG_LEVEL` | File-specific severity override |
| `LIGHTDASH_LOG_FILE_FORMAT` | Inherits `LOG_FORMAT` | File-specific format override |
| `LIGHTDASH_LOG_FILE_PATH` | `./logs/all.log` | Log file path |

For production: use `JSON` format with a log aggregation pipeline (e.g., Fluentd, Loki, CloudWatch).

### Prometheus Metrics

| Variable | Default | Description |
|---|---|---|
| `LIGHTDASH_PROMETHEUS_ENABLED` | `false` | Enable the `/metrics` endpoint |
| `LIGHTDASH_PROMETHEUS_PORT` | `9090` | Metrics port |
| `LIGHTDASH_PROMETHEUS_PATH` | `/metrics` | Metrics path |
| `LIGHTDASH_PROMETHEUS_PREFIX` | — | Metric name prefix |
| `LIGHTDASH_GC_DURATION_BUCKETS` | `0.001,0.01,0.1,1,2,5` | GC duration histogram buckets (seconds) |
| `LIGHTDASH_EVENT_LOOP_MONITORING_PRECISION` | `10` | Event loop precision in milliseconds (must be > 0) |
| `LIGHTDASH_PROMETHEUS_LABELS` | — | Additional labels as valid JSON |

**Available metric categories:**

| Category | Metrics |
|---|---|
| Process | CPU usage, memory consumption, file descriptors |
| Node.js runtime | Event loop lag, heap management, garbage collection |
| PostgreSQL | Connection pool status, query execution duration |
| Queue | Job queue size |

**Recommended alert thresholds:**

| Metric | Alert When |
|---|---|
| `process_resident_memory_bytes` | Exceeds memory limit threshold |
| `nodejs_eventloop_lag_p99_seconds` | Sustained spikes |
| `pg_active_connections / pg_pool_max_size` | Above 0.8 (80%) |

Lightdash metrics integrate with OpenTelemetry via the Prometheus receiver.

### Sentry Error Tracking

| Variable | Default | Description |
|---|---|---|
| `SENTRY_DSN` | — | Sentry DSN for both frontend and backend |
| `SENTRY_BE_DSN` | — | Backend-only Sentry DSN |
| `SENTRY_FE_DSN` | — | Frontend-only Sentry DSN |
| `SENTRY_BE_SECURITY_REPORT_URI` | — | Backend security report URI |
| `SENTRY_TRACES_SAMPLE_RATE` | `0.1` | Transaction sample rate (0.0–1.0) |
| `SENTRY_PROFILES_SAMPLE_RATE` | `0.2` | Profile sample rate (0.0–1.0) |
| `SENTRY_ANR_ENABLED` | `false` | Enable ANR detection |
| `SENTRY_ANR_CAPTURE_STACKTRACE` | `false` | Capture ANR stacktraces |

### Kubernetes Pod Metadata

Inject pod identity for log correlation:

| Variable | Description |
|---|---|
| `K8S_NODE_NAME` | Kubernetes node name |
| `K8S_POD_NAME` | Kubernetes pod name |
| `K8S_POD_NAMESPACE` | Kubernetes namespace |
| `LIGHTDASH_CLOUD_INSTANCE` | Cloud instance identifier |

---

## Enterprise Features

These variables require a valid `LIGHTDASH_LICENSE_KEY`.

### AI Analyst

| Variable | Default | Description |
|---|---|---|
| `AI_COPILOT_ENABLED` | `false` | Enable AI Analyst |
| `ASK_AI_BUTTON_ENABLED` | `false` | Show "Ask AI" button in UI |
| `AI_EMBEDDING_ENABLED` | `false` | Enable AI embeddings for semantic search |
| `AI_DEFAULT_PROVIDER` | `openai` | AI provider: `openai`, `azure`, `anthropic`, `openrouter`, `bedrock` |
| `AI_DEFAULT_EMBEDDING_PROVIDER` | `openai` | Embedding provider: `openai`, `bedrock`, `azure` |
| `AI_COPILOT_MAX_QUERY_LIMIT` | `500` | Max rows for AI-generated queries |
| `AI_VERIFIED_ANSWER_SIMILARITY_THRESHOLD` | `0.6` | Semantic similarity threshold (0–1) |

**OpenAI:**

| Variable | Default | Description |
|---|---|---|
| `OPENAI_API_KEY` | — | OpenAI API key |
| `OPENAI_MODEL_NAME` | `gpt-5.2` | Model name |
| `OPENAI_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding model |
| `OPENAI_BASE_URL` | — | Compatible proxy URL |

**Anthropic:**

| Variable | Default | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | — | Anthropic API key |
| `ANTHROPIC_MODEL_NAME` | `claude-sonnet-4-5` | Model name |

**Azure AI:**

| Variable | Description |
|---|---|
| `AZURE_AI_API_KEY` | Azure OpenAI API key |
| `AZURE_AI_ENDPOINT` | Azure endpoint URL |
| `AZURE_AI_API_VERSION` | API version |
| `AZURE_AI_DEPLOYMENT_NAME` | Deployment name |
| `AZURE_EMBEDDING_DEPLOYMENT_NAME` | Embedding deployment (default: `text-embedding-3-small`) |

**AWS Bedrock:**

| Variable | Default | Description |
|---|---|---|
| `BEDROCK_REGION` | — | AWS region (required) |
| `BEDROCK_ACCESS_KEY_ID` | — | AWS access key |
| `BEDROCK_SECRET_ACCESS_KEY` | — | AWS secret key |
| `BEDROCK_SESSION_TOKEN` | — | Temporary credentials token |
| `BEDROCK_MODEL_NAME` | `claude-sonnet-4-5` | Model name |
| `BEDROCK_EMBEDDING_MODEL` | `cohere.embed-english-v3` | Embedding model |

**OpenRouter:**

| Variable | Default | Description |
|---|---|---|
| `OPENROUTER_API_KEY` | — | OpenRouter API key |
| `OPENROUTER_MODEL_NAME` | `openai/gpt-4.1-2025-04-14` | Model name |
| `OPENROUTER_SORT_ORDER` | `latency` | Sort by: `price`, `throughput`, `latency` |

### Embedding (iFrame)

| Variable | Default | Description |
|---|---|---|
| `EMBEDDING_ENABLED` | `false` | Enable embedded charts/dashboards |
| `EMBED_ALLOW_ALL_DASHBOARDS_BY_DEFAULT` | `false` | Default-allow all dashboards for embedding |
| `EMBED_ALLOW_ALL_CHARTS_BY_DEFAULT` | `false` | Default-allow all charts for embedding |
| `LIGHTDASH_IFRAME_EMBEDDING_DOMAINS` | — | Allowed iframe parent domains (comma-separated) |

### Other Enterprise Variables

| Variable | Default | Description |
|---|---|---|
| `CUSTOM_ROLES_ENABLED` | `false` | Enable custom role creation |
| `SERVICE_ACCOUNT_ENABLED` | `false` | Enable service accounts |
| `SCIM_ENABLED` | `false` | Enable SCIM provisioning |
| `RESULTS_CACHE_ENABLED` | `false` | Enable query result caching |
| `AUTOCOMPLETE_CACHE_ENABLED` | `false` | Enable filter autocomplete caching |

### Instance Initialization (Enterprise)

These variables are used to bootstrap a fresh instance programmatically (e.g., in CI/CD pipelines):

| Variable | Required | Description |
|---|---|---|
| `LD_SETUP_ADMIN_EMAIL` | Yes | Initial admin email |
| `LD_SETUP_ORGANIZATION_NAME` | Yes | Organization name |
| `LD_SETUP_ADMIN_API_KEY` | Yes | Admin PAT (must have `ldpat_` prefix) |
| `LD_SETUP_SERVICE_ACCOUNT_TOKEN` | Yes | Service account token (`ldsvc_` prefix) |
| `LD_SETUP_PROJECT_NAME` | Yes | Project name |
| `LD_SETUP_PROJECT_SCHEMA` | Yes | Database/schema name |
| `LD_SETUP_ADMIN_NAME` | No | Admin display name (default: `Admin User`) |
| `LD_SETUP_ORGANIZATION_UUID` | No | Target organization UUID |
| `LD_SETUP_ORGANIZATION_EMAIL_DOMAIN` | No | Allowed email domains (comma-separated) |
| `LD_SETUP_ORGANIZATION_DEFAULT_ROLE` | No | Default member role (default: `viewer`) |
| `LD_SETUP_API_KEY_EXPIRATION` | No | API key expiration in days (default: 30) |
| `LD_SETUP_SERVICE_ACCOUNT_EXPIRATION` | No | Service account expiration in days (default: 30) |
| `LD_SETUP_START_OF_WEEK` | No | Week start day (default: `SUNDAY`) |
| `LD_SETUP_DBT_VERSION` | No | dbt version (default: `latest`) |

---

## Production Checklist

### Required for Production

- [ ] **External object storage configured** (`S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`)
- [ ] **`LIGHTDASH_SECRET` set** to a strong random value — stored in a secrets manager, not in code
- [ ] **External PostgreSQL** (`postgresql.enabled: false` in Helm) with `uuid-ossp` extension installed
- [ ] **`SITE_URL` set** to the full HTTPS URL

### Strongly Recommended

- [ ] **HTTPS/TLS enabled** via ingress controller or load balancer
- [ ] **`SECURE_COOKIES: "true"`** set when running HTTPS
- [ ] **`TRUST_PROXY: "true"`** set when TLS is terminated at a proxy/load balancer
- [ ] **SMTP configured** for password reset and scheduler email delivery
- [ ] **Resource requests/limits set** per the recommended values above
- [ ] **Headless browser deployed** (`ghcr.io/browserless/chromium:v2.24.3`) for scheduler screenshots
- [ ] **Log format set to `JSON`** for log aggregation pipelines
- [ ] **Prometheus metrics enabled** with alerts on memory, event loop lag, and DB connection pool

### Optional but Valuable

- [ ] SSO configured (Google, Okta, Azure AD, OneLogin, or generic OIDC)
- [ ] Slack integration enabled for scheduled deliveries
- [ ] Sentry DSN configured for error tracking
- [ ] `LIGHTDASH_PROMETHEUS_LABELS` set with environment and service metadata
- [ ] Enterprise license key set if using enterprise features (AI, SCIM, embedding, caching)
- [ ] `K8S_NODE_NAME`, `K8S_POD_NAME`, `K8S_POD_NAMESPACE` injected for log correlation

### Security Hardening

- [ ] Rotate `LIGHTDASH_SECRET` only with a planned migration — losing it is unrecoverable
- [ ] Use IAM roles instead of `S3_ACCESS_KEY`/`S3_SECRET_KEY` where possible (AWS/GCP)
- [ ] Set `AUTH_DISABLE_PASSWORD_AUTHENTICATION: "true"` if SSO is the only intended login method
- [ ] Set `DISABLE_PAT: "true"` if personal access tokens should be prohibited
- [ ] Configure `LIGHTDASH_CSP_ALLOWED_DOMAINS` and `LIGHTDASH_CORS_ALLOWED_DOMAINS` to restrict to known origins
- [ ] Use managed PostgreSQL with encryption at rest and in transit

### Upgrade Procedure

1. Pull the new Lightdash image tag.
2. Run `helm upgrade` (or update the Docker Compose image tag and restart).
3. Database migrations run automatically on startup — no manual steps required.
4. If a `pg_lock` error appears, check the `knex_migrations_lock` table and release the lock manually.

---

## Cross-References

- Official Helm chart: https://github.com/lightdash/helm-charts
- Full documentation index: https://docs.lightdash.com/llms.txt
- Environment variables reference: https://docs.lightdash.com/self-host/customize-deployment/environment-variables
