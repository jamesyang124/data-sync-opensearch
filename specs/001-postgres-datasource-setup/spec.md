# Feature Specification: PostgreSQL Datasource Setup with Sample Data

**Feature Branch**: `001-postgres-datasource-setup`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "prepare posgtgres datasource with docker compose and make file, also looking/suggest possible data set from hugging faces website"

## Clarifications

### Session 2025-12-25

- Q: Which specific dataset domain should be used (e-commerce, social media, IoT sensors, or general relational data)? → A: Video media platform like YouTube with video room settings
- Q: Which specific Hugging Face dataset should be used? → A: https://huggingface.co/datasets/AmaanP314/youtube-comment-sentiment
- Q: How much of the 1M+ comment dataset should be loaded during initial setup? → A: Representative subset (10K-50K records) for fast setup while maintaining data diversity across categories/time periods
- Q: How should default PostgreSQL credentials be managed? → A: Simple defaults documented in README with .env.example template allowing easy override
- Q: Should the CSV data be normalized into separate relational tables or loaded as-is? → A: Normalize into 3 related tables (videos, users/channels, comments) with foreign keys
- Q: Which specific Makefile targets should be provided? → A: Essential commands (start, stop, reset, health, inspect-schema, inspect-data, logs) for quick demo setup

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start Development Environment (Priority: P1)

As a developer, I need to start a fully configured PostgreSQL database with sample data using a single command, so I can immediately begin developing and testing the data sync pipeline without manual database setup.

**Why this priority**: This is the foundational infrastructure requirement. Without a working PostgreSQL datasource, no other features of the data-sync-opensearch project can be developed or tested.

**Independent Test**: Can be fully tested by running the start command and verifying database connectivity, schema existence, and sample data presence. Delivers immediate value by providing a ready-to-use development database.

**Acceptance Scenarios**:

1. **Given** no existing database containers, **When** developer runs `make start`, **Then** PostgreSQL container starts successfully with configured credentials and accessible on the expected port
2. **Given** PostgreSQL container is running, **When** developer connects to the database, **Then** sample schema and tables exist with populated data (videos, users, comments)
3. **Given** developer wants to verify the setup, **When** they run `make health`, **Then** system reports database status, connection details, and row counts for each table

---

### User Story 2 - Reset Database State (Priority: P2)

As a developer, I need to reset the database to its initial state with fresh sample data, so I can test the sync pipeline from a known baseline or recover from corrupted test data.

**Why this priority**: Essential for iterative development and testing. Developers frequently need to reset state when testing CDC, data transformations, or recovering from failed experiments.

**Independent Test**: Can be tested by populating database with test data, running reset command, and verifying database returns to original sample data state.

**Acceptance Scenarios**:

1. **Given** database contains modified or additional data, **When** developer runs `make reset`, **Then** database is dropped, recreated, and repopulated with original sample data
2. **Given** database schema has been altered, **When** developer runs `make reset`, **Then** schema is restored to the original 3-table structure
3. **Given** developer confirms the reset action, **When** reset completes, **Then** system displays confirmation with row counts matching the original sample data

---

### User Story 3 - Inspect Sample Data (Priority: P3)

As a developer, I need to view and understand the sample data schema and contents, so I can design appropriate transformations and mappings to OpenSearch.

**Why this priority**: Important for understanding the data model but not blocking for basic infrastructure setup. Developers can also inspect data using standard database tools.

**Independent Test**: Can be tested by running inspection commands and verifying they display schema definitions, sample rows, and data statistics.

**Acceptance Scenarios**:

1. **Given** database is running with sample data, **When** developer runs `make inspect-schema`, **Then** system displays table names (videos, users, comments), column definitions, data types, and foreign key relationships
2. **Given** developer wants to see sample records, **When** they run `make inspect-data`, **Then** system displays first 10 rows from each table with formatted output
3. **Given** developer needs container logs, **When** they run `make logs`, **Then** system displays PostgreSQL container logs with timestamps and initialization messages

---

### Edge Cases

- What happens when PostgreSQL container is already running on the default port? System should detect port conflict and either stop existing container or report clear error message with resolution steps.
- How does system handle Docker daemon not running? Command should check Docker availability and provide actionable error message directing user to start Docker.
- What happens when sample data download fails or is corrupted? System should validate data integrity and provide clear error with retry instructions.
- How does system handle insufficient disk space for database? Docker should report disk space errors; Makefile should include pre-flight check for minimum available space.
- What happens when network is unavailable during initial setup? System should gracefully handle network failures when pulling Docker images or downloading datasets, with clear error messages.
- What happens when .env file is missing? System should copy .env.example to .env automatically on first run, or provide clear instructions to create it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single command to start PostgreSQL database with all dependencies configured
- **FR-002**: System MUST automatically load a representative subset (10,000-50,000 records) from AmaanP314/youtube-comment-sentiment dataset into PostgreSQL on first initialization, ensuring data diversity across video categories and time periods
- **FR-003**: System MUST support video media platform domain with datasets containing videos, users/channels, comments, view statistics, video room settings, and playlists
- **FR-004**: System MUST provide command to stop and remove all database containers and volumes
- **FR-005**: System MUST provide command to reset database to initial state with original sample data
- **FR-006**: System MUST expose PostgreSQL on a configurable port with simple default credentials documented in README, using .env.example template that allows developers to override via .env file
- **FR-007**: System MUST create normalized database schema with 3 related tables (videos, users/channels, comments) derived from the flat CSV dataset, including proper foreign key relationships and indexes
- **FR-008**: System MUST provide commands to inspect database schema, view sample data, and display statistics
- **FR-009**: System MUST validate that Docker is installed and running before attempting container operations
- **FR-010**: System MUST persist database data in named Docker volumes to survive container restarts
- **FR-011**: System MUST provide health check command to verify database connectivity and readiness
- **FR-012**: System MUST provide and document the following Makefile targets: start (launch database), stop (stop containers), reset (restore to baseline), health (verify connectivity), inspect-schema (show table definitions), inspect-data (display sample rows), logs (view container logs)
- **FR-013**: System MUST ensure all Makefile commands provide clear output indicating success or failure with actionable next steps

### Key Entities *(include if feature involves data)*

- **Database Container**: Containerized PostgreSQL instance with configured version, credentials, port mappings, and volume mounts
- **Sample Dataset**: Structured video media platform data from Hugging Face Hub containing videos, users/channels, comments, view statistics, room settings, and playlists with realistic relationships
- **Database Schema**: Normalized 3-table structure with videos table (video_id PK, title, category, metadata), users table (channel_id PK, channel_name, metadata), and comments table (comment_id PK, video_id FK, channel_id FK, text, likes, replies, timestamp, sentiment, country_code)
- **Volume**: Persistent storage for database files ensuring data survives container lifecycle operations
- **Configuration**: Environment variables, connection strings, credentials, and settings required for database access and operation
- **Videos Table**: Contains unique video records extracted from CSV (video_id, title, category) with one row per distinct video
- **Users/Channels Table**: Contains unique user/channel records (channel_id, channel_name) with one row per distinct commenter
- **Comments Table**: Contains comment records with foreign keys to videos and users tables (comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can start complete database environment in under 3 minutes from clone to running database (including Docker image pull on first run)
- **SC-002**: Database reset operation completes in under 30 seconds and restores exact original sample data state
- **SC-003**: All database operations (start, stop, reset, inspect) succeed with single command execution without requiring manual intervention
- **SC-004**: Documentation includes working examples for all commands with expected output samples
- **SC-005**: Sample dataset contains 10,000-50,000 records across at least 3 related tables (videos, users/channels, comments) to adequately demonstrate sync functionality while maintaining fast initialization
- **SC-006**: Database remains accessible and responsive after 24 hours of continuous operation under normal query load
- **SC-007**: 100% of error scenarios provide actionable error messages with specific resolution steps
- **SC-008**: Zero manual configuration required - all defaults work for local development immediately after clone

## Assumptions

- **A-001**: Docker and Docker Compose are pre-installed on developer machine (documented as prerequisite)
- **A-002**: Developer has internet connectivity for initial Docker image pull and dataset download
- **A-003**: Default PostgreSQL port (5432) is available or developer can configure alternative port via environment variables
- **A-004**: Sample dataset from Hugging Face is in CSV format that will be transformed into normalized relational tables during loading, with subset selection performed via sampling strategy (e.g., stratified by category and time period)
- **A-005**: Developers are familiar with basic PostgreSQL concepts (databases, tables, schemas) but not necessarily with Debezium or CDC
- **A-006**: Makefile is the preferred automation tool (cross-platform compatibility via make utility)
- **A-007**: PostgreSQL version 14 or higher is acceptable for CDC with Debezium (supports logical replication)
- **A-008**: Default credentials (documented in .env.example) are acceptable for local development; production deployments will use secure credential management outside this feature's scope
- **A-009**: .env file (containing actual credentials) is git-ignored; only .env.example (with placeholder values) is version-controlled

## Suggested Datasets from Hugging Face

Based on research of available datasets suitable for demonstrating video media platform data sync:

### Video Platform Datasets (YouTube-like)

- **AmaanP314/youtube-comment-sentiment** (Recommended): Over 1 million YouTube comments with comprehensive metadata including video details (title, category, ID), author information (channel ID, name), engagement metrics (likes, replies), temporal data (PublishedAt), and geographical data (CountryCode). Available in CSV format. Excellent for demonstrating multi-table relationships (videos, users, comments) and CDC scenarios.

- **hridaydutta123/YT-100K**: Large-scale multilingual comment dataset with 100K+ comments. Each record includes video ID, comment ID, commenter name, commenter channel ID, comment text, upvotes, original channel ID, and category. Good for demonstrating comment moderation and engagement tracking.

- **breadlicker45/youtube-comments-180k**: Dataset containing 187,482 YouTube comments from 2025 (31.8 MB). Suitable for demonstrating real-time comment sync and moderation workflows.

- **HuggingFaceFV/finevideo**: Contains YouTube video metadata including comment counts, views, likes, and upload dates. Ideal for video catalog and statistics tracking.

### Integration Approach

- **PostgreSQL Integration**: Hugging Face datasets library supports direct PostgreSQL integration via `pgai` extension and `ai.load_dataset()` function for streaming ingestion.
- **CSV/Structured Data**: Platform supports efficient loading of CSV, JSON, Parquet formats into PostgreSQL using `from_sql()` and bulk loading methods.
- **Schema Design**: Datasets can be structured into relational tables: videos (video_id, title, category, upload_date), users (channel_id, name), comments (comment_id, video_id, author_id, text, likes, timestamp), room_settings (video_id, live_enabled, chat_enabled).

### Selection Criteria for Video Platform Domain

The dataset should include:
- Video metadata (titles, descriptions, categories, upload dates)
- User/channel information (creators and viewers)
- Comments with engagement metrics (likes, replies, timestamps)
- Realistic data volume (1,000+ records across multiple tables)
- Clear relationships (videos→users, comments→videos, comments→users)
- Mix of data types (text, numeric, timestamps, boolean)
- Potential for demonstrating CDC scenarios (new comments, view count updates, room setting changes)

**Selected Dataset**: AmaanP314/youtube-comment-sentiment - This dataset will be used for the initial implementation.

## References

- [PostgreSQL Integration with Hugging Face](https://huggingface.co/docs/dataset-viewer/en/postgresql)
- [Load Tabular Data](https://huggingface.co/docs/datasets/en/tabular_load)
- [Query Hugging Face Datasets from Postgres](https://www.crunchydata.com/blog/query-hugging-face-datasets-from-postgres)
- [YouTube Comment Sentiment Dataset](https://huggingface.co/datasets/AmaanP314/youtube-comment-sentiment)
- [YT-100K Dataset](https://huggingface.co/datasets/hridaydutta123/YT-100K)
- [YouTube Comments 180K](https://huggingface.co/datasets/breadlicker45/youtube-comments-180k)
- [FineVideo Dataset](https://huggingface.co/datasets/HuggingFaceFV/finevideo)
- [Video Dataset Documentation](https://huggingface.co/docs/hub/datasets-video)
