# Snowflake Platform Features Reference

> Compiled from [Snowflake Documentation](https://docs.snowflake.com/) (fetched 2026-03-23).
> Covers connectors, APIs, data loading, security, data sharing, and platform constraints.

---

## Table of Contents

- [Connectors and Drivers](#connectors-and-drivers)
- [Snowpark](#snowpark)
- [SQL API (REST API)](#sql-api-rest-api)
- [Snowflake Python APIs](#snowflake-python-apis)
- [Snowpipe and Data Loading](#snowpipe-and-data-loading)
- [External Tables](#external-tables)
- [Security and Access Control](#security-and-access-control)
- [Data Sharing and Marketplace](#data-sharing-and-marketplace)
- [Key Platform Limits and Constraints](#key-platform-limits-and-constraints)

---

## Connectors and Drivers

Snowflake provides native drivers for connecting from applications written in multiple languages. All drivers support standard operations (DDL, DML, queries) against Snowflake.

| Driver | Language | Key Details |
|---|---|---|
| **Python Connector** | Python | Pure Python, no JDBC/ODBC dependency. Implements PEP-249 (DB-API v2). Supports pandas DataFrames, SQLAlchemy integration. Install via `pip install snowflake-connector-python`. |
| **JDBC Driver** | Java | Standard JDBC interface. Compatible with most Java client tools and applications that support JDBC. |
| **ODBC Driver** | C/C++ | ODBC-based connectivity for client applications. Works on Linux, macOS, Windows. |
| **Go Driver** | Go | Native Go interface for developing Go applications that connect to Snowflake. |
| **Node.js Driver** | JavaScript | Native asynchronous Node.js interface for Snowflake operations. |
| **.NET Driver** | C# / .NET | Interface for the Microsoft .NET open source framework. |
| **PHP PDO Driver** | PHP | PDO-based driver for PHP applications. |

### Python Connector Details

- Pure Python package — no JDBC or ODBC dependencies
- Installable via pip on Linux, macOS, and Windows
- Supports Connection objects (connecting) and Cursor objects (executing statements)
- Supports pandas DataFrames via `snowflake-connector-python[pandas]`
- Compatible with SQLAlchemy via `snowflake-sqlalchemy`
- SnowSQL (Snowflake's CLI) is built on this connector
- Does not currently support GCP regional endpoints

### Driver Session Reuse

Snowflake documents considerations when drivers reuse sessions. Drivers can maintain persistent sessions to reduce connection overhead, but care must be taken with session state (role, warehouse, database context) when sessions are shared across operations.

---

## Snowpark

Snowpark is Snowflake's library for querying and processing data at scale using Java, Python, or Scala — without moving data out of Snowflake.

### Supported Languages

| Language | Developer Guide | API Reference |
|---|---|---|
| Python | Snowpark Developer Guide for Python | Snowpark Library for Python API Reference |
| Java | Snowpark Developer Guide for Java | Snowpark Library for Java API Reference |
| Scala | Snowpark Developer Guide for Scala | Snowpark Library for Scala API Reference |

### Key Features

- **Pushdown execution**: All operations are pushed down to Snowflake's compute engine. No separate cluster needed outside Snowflake.
- **Lazy evaluation**: Operations are executed lazily on the server. Data transformations are batched and delayed until an action (e.g., `collect()`, `show()`) is called, reducing data transfer.
- **DataFrame abstraction**: Core abstraction is the DataFrame, representing a set of data with methods for transformation (select, filter, join, aggregate, etc.).
- **Native language constructs**: Build SQL statements using programming constructs (e.g., `select(col("id"))`) instead of raw SQL strings. Enables IDE features like code completion and type checking.
- **UDF support**: Create and call User-Defined Functions (UDFs) and stored procedures directly from Snowpark.

### Snowpark Python API — Key Classes

| Category | Key Classes |
|---|---|
| **I/O** | `DataFrameReader`, `DataFrameWriter`, `FileOperation`, `PutResult`, `GetResult` |
| **DataFrame** | `DataFrame`, `DataFrameNaFunctions`, `DataFrameStatFunctions`, `DataFrameAnalyticsFunctions`, `DataFrameAIFunctions` |
| **Readers** | `.avro()`, `.csv()`, `.json()`, `.parquet()`, `.orc()`, `.xml()`, `.table()`, `.dbapi()`, `.jdbc()` |
| **Writers** | `.saveAsTable()`, `.csv()`, `.json()`, `.parquet()`, `.copy_into_location()` |

### Snowpark vs. Spark Connector

Compared to the Snowflake Connector for Spark, Snowpark provides:
- No separate compute cluster required — all computation runs in Snowflake
- Full pushdown for all operations including UDFs
- Local development support (Jupyter, VS Code, IntelliJ)
- Scale and compute management handled by Snowflake

### Related Components

- **Snowpark Container Services**: Run containerized workloads within Snowflake.
- **Snowpark Code Execution Environments**: Managed environments for running Snowpark code.
- **Snowpark ML**: Machine learning capabilities integrated with Snowpark.

---

## SQL API (REST API)

The Snowflake SQL API is a REST API for accessing and updating data in Snowflake databases. It enables building custom applications and integrations.

### Capabilities

- Submit SQL statements for execution
- Check execution status of statements
- Cancel statement execution
- Execute standard queries, most DDL and DML statements
- Manage deployments (provision users, roles, create tables)

### API Operations

| Operation | Description |
|---|---|
| **Submit statements** | Send SQL statements for execution via REST endpoint |
| **Check status** | Poll for execution status of submitted statements |
| **Cancel execution** | Cancel a running SQL statement |
| **Multiple statements** | Submit multiple SQL statements in a single request |
| **Stored procedures** | Create and call stored procedures via the API |
| **Explicit transactions** | Execute SQL within transaction boundaries (BEGIN, COMMIT, ROLLBACK) |

### Authentication

The SQL API supports two authentication methods:
- **OAuth**: Standard OAuth 2.0 token-based authentication
- **Key Pair**: RSA key pair authentication with JWT tokens

### Endpoints

The API provides RESTful endpoints for statement submission, status checking, and cancellation. Responses include result data, error details, and execution metadata.

### Limitations

Certain SQL statement types are not supported through the SQL API. Refer to the Snowflake documentation for the current list of unsupported statement types.

---

## Snowflake Python APIs

Snowflake provides first-class Python APIs for managing core Snowflake resources programmatically without using SQL:

- Databases
- Schemas
- Tables
- Tasks
- Warehouses

These APIs complement the Python Connector by providing object-oriented resource management.

---

## Snowpipe and Data Loading

### Snowpipe (File-Based Continuous Loading)

Snowpipe enables loading data from files as soon as they are available in a stage, delivering data in micro-batches within minutes.

#### How It Works

- A **pipe** is a named Snowflake object containing a COPY statement that defines the source stage and target table.
- All data types are supported, including semi-structured (JSON, Avro, Parquet, etc.).

#### Two Triggering Mechanisms

| Mechanism | Description |
|---|---|
| **Cloud messaging (automated)** | Event notifications from cloud storage (S3, GCS, Azure Blob) trigger Snowpipe. Serverless, continuous loading. |
| **REST endpoints** | Client application calls a REST endpoint with pipe name and file list. Files are queued for loading. |

#### Supported Cloud Storage

All combinations are supported — Snowflake accounts on any cloud (AWS, GCP, Azure) can load from any of:
- Amazon S3
- Google Cloud Storage
- Microsoft Azure Blob Storage
- Microsoft Data Lake Storage Gen2
- Microsoft Azure General-purpose v2

#### Snowpipe vs. Bulk Loading

| Feature | Snowpipe | Bulk Loading (COPY) |
|---|---|---|
| **Authentication** | Key pair auth with JWT (REST) | Standard client session auth |
| **Load history** | 14 days in pipe metadata | 64 days in table metadata |
| **Transactions** | Combined/split across transactions | Single transaction per load |
| **Compute** | Snowflake-supplied serverless compute | User-specified warehouse |
| **Cost model** | Per compute resources used during load | Per warehouse active time |

#### Best Practices

- Enable cloud event filtering to reduce costs, noise, and latency
- Follow file sizing recommendations (compressed files ~100-250 MB)
- Stage files once per minute for best cost/performance balance
- Use either Snowpipe or bulk loading for a given file set — never both (avoids duplicate data)
- Government regions do not allow cross-region event notifications

### Snowpipe Streaming (Row-Based Real-Time Loading)

Snowpipe Streaming enables low-latency, continuous loading of streaming data directly into Snowflake — rows are available for query within seconds.

#### Value Proposition

- **Real-time data availability**: Data is queryable as it arrives (live dashboards, real-time analytics, fraud detection)
- **No staging files required**: Rows are written directly into tables via SDK, bypassing intermediate cloud storage
- **Serverless and auto-scaling**: Compute resources scale automatically based on ingestion load
- **Optimized billing**: Cost-effective for high-volume, low-latency data feeds

#### Two Implementations

| Feature | High-Performance Architecture | Classic Architecture |
|---|---|---|
| **SDK** | `snowpipe-streaming` SDK | `snowflake-ingest-sdk` |
| **Data flow** | Uses PIPE object for management + lightweight transforms | Channels open directly against target tables |
| **Pricing** | Throughput-based (credits per uncompressed GB) | Serverless compute + active client connections |
| **Schema validation** | Server-side against PIPE schema | Client-side |
| **REST API** | Yes, for direct lightweight ingestion | No |
| **Recommendation** | New streaming projects | Existing setups |

#### Snowpipe Streaming vs. Snowpipe

| Category | Snowpipe Streaming | Snowpipe |
|---|---|---|
| **Data form** | Rows (streaming records) | Files |
| **Use case** | Kafka topics, application events, IoT sensors, CDC streams | File-based batch/micro-batch loads |
| **Latency** | Seconds | Minutes |
| **Staging** | No intermediate storage needed | Requires cloud storage stage |

### Bulk Data Loading

Standard COPY INTO command for loading data from staged files:
- Supports all file formats (CSV, JSON, Avro, Parquet, ORC, XML)
- Internal stages (Snowflake-managed) and external stages (S3, GCS, Azure)
- Schema evolution: automatic table schema evolution during load
- Transform during load: apply transformations during the COPY operation

---

## External Tables

External tables allow querying data stored in external stages (cloud storage) as if it were a native Snowflake table.

### Key Characteristics

- **Read-only**: No DML operations (INSERT, UPDATE, DELETE) supported
- **Query and join**: Full support for SELECT queries and JOIN operations
- **Views supported**: Can create views against external tables
- **File formats**: All formats supported by COPY INTO except XML
- **Performance**: Slower than native tables; use materialized views to improve query performance
- **Parquet optimization**: For Parquet files, consider Apache Iceberg tables for optimal performance

### Built-in Columns

| Column | Type | Description |
|---|---|---|
| `VALUE` | VARIANT | Represents a single row from the external file |
| `METADATA$FILENAME` | Pseudocolumn | File name and path in the stage |
| `METADATA$FILE_ROW_NUMBER` | Pseudocolumn | Row number within the staged file |

### Virtual Columns

If the schema of source files is known, additional virtual columns can be defined as expressions using the VALUE column and metadata pseudocolumns. This enables strong type checking and schema validation.

### Apache Iceberg Tables

Snowflake supports Apache Iceberg tables as a high-performance alternative:
- **Externally managed Iceberg tables**: Query Iceberg tables managed by external catalogs
- **Managed Iceberg tables**: Snowflake manages the Iceberg metadata and storage
- **Snowflake Open Catalog**: Catalog service for Iceberg tables

---

## Security and Access Control

### Access Control Framework

Snowflake combines three access control models:

| Model | Description |
|---|---|
| **Discretionary Access Control (DAC)** | Each object has an owner who can grant access to that object |
| **Role-Based Access Control (RBAC)** | Privileges are assigned to roles, which are assigned to users |
| **User-Based Access Control (UBAC)** | Privileges can be assigned directly to users (active when USE SECONDARY ROLE = ALL) |

### Core Concepts

| Concept | Description |
|---|---|
| **Securable object** | Entity to which access can be granted (database, table, view, etc.). Access denied unless explicitly granted. |
| **Role** | Entity to which privileges can be granted. Assigned to users or other roles. |
| **Privilege** | Defined level of access to an object. Multiple granular privileges per object type. |
| **User** | Identity (person or service) recognized by Snowflake. Can be assigned roles. |

### Role Types

| Role Type | Scope |
|---|---|
| **Account roles** | Permit SQL actions on any object in the account |
| **Database roles** | Limited to objects within a single database |
| **Instance roles** | Permit access to instances of a class |
| **Application roles** | Enable consumer access to Snowflake Native App objects |
| **System application roles** | Snowflake-provided roles for specific feature functionality |

### System-Defined Roles

Snowflake provides built-in roles that cannot be dropped:

| Role | Purpose |
|---|---|
| **ORGADMIN** | Organization-level administration |
| **ACCOUNTADMIN** | Top-level account role (combines SYSADMIN + SECURITYADMIN) |
| **SECURITYADMIN** | Manage grants, create/modify/drop roles |
| **SYSADMIN** | Create and manage databases, warehouses, and other objects |
| **USERADMIN** | Create and manage users and roles |
| **PUBLIC** | Automatically granted to every user and role |

### Role Hierarchy and Privilege Inheritance

- Roles can be granted to other roles, creating a hierarchy
- Privileges are inherited upward in the hierarchy
- A role owner does NOT inherit the privileges of the owned role (inheritance only through hierarchy)
- Managed access schemas restrict grant decisions to the schema owner or MANAGE GRANTS privilege holders

### Authentication Methods

| Method | Description |
|---|---|
| **Multi-factor authentication (MFA)** | Additional verification factor for login |
| **Federated authentication / SSO** | SAML-based single sign-on with identity providers |
| **Key-pair authentication** | RSA key pair with key rotation support |
| **Programmatic access tokens** | Tokens for programmatic access |
| **OAuth** | OAuth 2.0 integration for third-party application access |
| **Workload identity federation** | Federated identity for cloud workloads |
| **Authentication policies** | Configurable policies governing authentication requirements |

### Network Security

#### Network Policies

- Control inbound access to Snowflake service and internal stages
- Use **network rules** to group related network identifiers (IP addresses, VPC endpoints, Azure Link IDs)
- Policies have **allowed lists** and **blocked lists** of network rules
- Can be activated at account, user, or security integration level
- A network policy does not restrict traffic until activated

#### Network Rules

| Type | Identifier | Description |
|---|---|---|
| **IPV4** | IP addresses/CIDR ranges | Control access by IP address |
| **AWSVPCEID** | AWS VPC Endpoint IDs | Control access via AWS PrivateLink |
| **AZURELINKID** | Azure Private Link IDs | Control access via Azure Private Link |

#### Precedence Rules

- Private connectivity rules (AWSVPCEID, AZURELINKID) take precedence over IPV4 rules
- If the same IP is in both allowed and blocked lists, the blocked list takes precedence
- To allow only private endpoints while blocking public access, create separate network rules for each

#### Additional Network Security

- **Malicious IP protection**: Built-in protection against known malicious IPs
- **Network policy advisor**: Recommendations for network policy configuration
- **Network egress control**: Control outbound traffic from Snowflake
- **Private connectivity**: Both inbound and outbound private connectivity (AWS PrivateLink, Azure Private Link, GCP Private Service Connect)

### Encryption

#### End-to-End Encryption (E2EE)

Snowflake implements end-to-end encryption to protect customer data:

- **In transit**: All data encrypted with TLS between client and Snowflake service
- **At rest**: All customer data encrypted at rest in Snowflake's storage
- **Internal stages**: Files are automatically encrypted on the client before upload, and encrypted again after loading into the stage
- **External stages**: Client-side encryption supported (recommended but optional); unencrypted data is encrypted upon loading into Snowflake tables

#### Client-Side Encryption

- Uses customer-provided master key (128-bit or 256-bit AES, Base64 encoded)
- Follows cloud-provider-specific client-side encryption protocols
- Random encryption key encrypts the file; master key encrypts the random key
- Both encrypted file and encrypted key stored in cloud storage
- Third parties (cloud provider, ISP) never see data in the clear

#### Key Management

- Snowflake manages encryption keys with automatic key rotation
- Customer-managed keys supported via Tri-Secret Secure (bring your own key)
- Keys are hierarchical: account master key > table master key > file key

### Data Governance

- **Row access policies**: Control which rows a user can see
- **Column-level security (dynamic data masking)**: Mask sensitive data based on user role
- **Object tagging**: Classify and tag objects for governance
- **Access history**: Track who accessed what data and when
- **Trust Center**: Centralized security posture management

---

## Data Sharing and Marketplace

### Secure Data Sharing

Snowflake's sharing architecture enables sharing data between accounts without copying or moving data.

#### How It Works

- No actual data is copied or transferred between accounts
- Sharing uses Snowflake's services layer and metadata store
- Shared data does not consume storage in the consumer account
- Consumers pay only for compute (warehouse) costs to query imported data
- Setup is quick for providers; access is near-instantaneous for consumers

#### Shareable Objects

- Databases
- Tables (including dynamic tables, external tables, Iceberg tables)
- Views (regular, secure, secure materialized, semantic)
- User-Defined Functions (UDFs)
- Cortex Search services
- Models (USER_MODEL, CORTEX_FINETUNED, DOC_AI)

#### Important Constraints

- All shared database objects are **read-only** (cannot be modified by consumers)
- Only one database can be created per share (on consumer side)
- Consumers can apply standard RBAC to control access to imported data

#### Sharing Options

| Option | Description |
|---|---|
| **Listing** | Offer a share + metadata as a data product to one or more accounts |
| **Direct Share** | Share specific database objects directly to another account in same region |
| **Data Exchange** | Set up and manage a group of accounts for sharing |
| **Clean Room** | Share data with controlled queries (privacy-preserving collaboration) |

#### Provider / Consumer Model

- **Provider**: Creates shares, grants access to specific objects, adds consumer accounts
- **Consumer**: Creates a read-only database from the share, queries data using standard RBAC
- Any full Snowflake account can be both a provider and consumer
- **Reader accounts**: Special accounts for third parties that consume from a single provider

### Cross-Region and Cross-Cloud Sharing

- Data can be shared across regions and cloud platforms
- Snowflake replicates the shared data to enable cross-region access

### Snowflake Marketplace

- Public marketplace for discovering and accessing third-party data products
- Providers can list data products for free or paid access
- Listings include metadata, sample queries, and usage documentation

### Data Clean Rooms

- Privacy-preserving collaboration between parties
- Controlled queries against shared data
- Supports: overlap analysis, lookalike modeling, attribution, ML, custom SQL
- Built-in differential privacy support
- Cross-cloud auto-fulfillment

---

## Key Platform Limits and Constraints

### Object Limits

| Object | Limit |
|---|---|
| Databases per account | 10,000 |
| Schemas per database | 10,000 |
| Tables per schema | 10,000 |
| Columns per table | 2,000 (standard), up to 5,000 for wider tables |
| Column name length | 255 characters |
| Identifier length | 255 characters |
| SQL statement size | 1 MB (via SQL API), varies by driver |
| Result set size | Unlimited (paginated via result scan) |

### Query and Compute Limits

| Feature | Limit |
|---|---|
| Maximum query execution time | 2 days (configurable via STATEMENT_TIMEOUT_IN_SECONDS) |
| Maximum warehouse size | 6XL (supports X-Small through 6X-Large) |
| Multi-cluster warehouse max clusters | 10 |
| Concurrent queries per warehouse | Varies by size; queuing when exceeded |
| Maximum query text length | 1 MB |

### Data Loading Limits

| Feature | Limit |
|---|---|
| Maximum file size (bulk load) | 5 GB (compressed) recommended; larger files supported but slower |
| Recommended file size (Snowpipe) | 100-250 MB compressed |
| Snowpipe load history retention | 14 days |
| Bulk load history retention | 64 days |
| COPY INTO max files per statement | 1,000 (use pattern matching for more) |

### Data Types

| Type | Max Size |
|---|---|
| VARCHAR | 16 MB |
| BINARY | 8 MB |
| VARIANT (semi-structured) | 16 MB per value |
| NUMBER precision | Up to 38 digits |
| FLOAT | IEEE 754 double precision |

### Sharing and Collaboration Limits

| Feature | Limit |
|---|---|
| Shares per account | Unlimited |
| Consumer accounts per share | Unlimited |
| Databases per share | 1 (but can share objects from multiple databases) |
| Shared objects | Read-only (no DML by consumers) |

### Session and Connection Limits

| Feature | Limit |
|---|---|
| Maximum sessions per user | Unlimited (but resource-governed) |
| Session idle timeout | Configurable (default 4 hours) |
| Client session keep-alive | Driver-dependent |
| Network policy rules | 10,000 per policy (via network rules) |

### SQL API Specific Limits

| Feature | Limit |
|---|---|
| Statement size | 1 MB |
| Concurrent requests | Rate-limited per account |
| Result pagination | Results returned in pages; use result set endpoints to iterate |

### Time Travel and Fail-Safe

| Feature | Standard Edition | Enterprise Edition |
|---|---|---|
| Time Travel retention | 0-1 days | 0-90 days |
| Fail-safe period | 7 days (non-configurable) | 7 days (non-configurable) |

### Storage

| Feature | Details |
|---|---|
| Compression | Automatic compression of all stored data |
| Storage billing | Based on compressed data size (after Snowflake's proprietary compression) |
| Minimum storage billing | Per-account minimums vary by cloud provider and region |

---

## Additional Platform Features

### Dynamic Tables

- Declarative data transformation pipelines
- Define target state with SQL; Snowflake manages incremental refreshes
- Configurable target lag (freshness guarantee)

### Streams and Tasks

- **Streams**: Change data capture (CDC) on tables, views, and external tables
- **Tasks**: Scheduled or event-driven execution of SQL statements
- Combined for ELT pipelines within Snowflake

### Snowflake CLI (SnowCLI)

- Command-line tool for managing Snowflake resources
- Supports Snowpark development, Streamlit apps, Native Apps

### Streamlit in Snowflake

- Build interactive data applications directly in Snowflake
- Python-based UI framework
- Runs securely within Snowflake (data never leaves the platform)

### Snowflake Native App Framework

- Build, distribute, and monetize applications within the Snowflake ecosystem
- Declarative sharing model
- Provider-consumer architecture

### Kafka and Spark Connectors

- **Kafka Connector**: Continuous ingestion from Kafka topics into Snowflake
- **Spark Connector**: Bidirectional data transfer between Spark and Snowflake

### Git Integration

- Connect Snowflake to Git repositories
- Version control for Snowflake objects and code

---

## Documentation Links

| Topic | URL |
|---|---|
| Reference (main) | https://docs.snowflake.com/en/reference |
| Drivers | https://docs.snowflake.com/en/developer-guide/drivers |
| Snowpark API | https://docs.snowflake.com/en/developer-guide/snowpark/index |
| Snowpark Python API Reference | https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/snowpark/index |
| SQL API | https://docs.snowflake.com/en/developer-guide/sql-api/index |
| Python Connector | https://docs.snowflake.com/en/developer-guide/python-connector/python-connector |
| Snowpipe | https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro |
| Snowpipe Streaming | https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview |
| Access Control | https://docs.snowflake.com/en/user-guide/security-access-control-overview |
| Network Policies | https://docs.snowflake.com/en/user-guide/network-policies |
| Encryption | https://docs.snowflake.com/en/user-guide/security-encryption |
| Data Sharing | https://docs.snowflake.com/en/user-guide/data-sharing-intro |
| External Tables | https://docs.snowflake.com/en/user-guide/tables-external-intro |
