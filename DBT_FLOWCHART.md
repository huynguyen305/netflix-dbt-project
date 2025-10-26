# Netflix dbt Project - Visual Flowchart

## Complete Data Pipeline Flow

```mermaid
graph TB
    subgraph "LOCAL ENVIRONMENT"
        A[Raw CSV Files<br/>movies.csv, tags.csv<br/>links.csv, genome-tags.csv]
    end

    subgraph "AWS CLOUD"
        B[AWS S3 Bucket<br/>netflix-dbt-data-20251025<br/>/raw-data/]
        C[IAM Role<br/>snowflake-s3-role<br/>Trust: Snowflake IAM User]
    end

    subgraph "SNOWFLAKE DATA WAREHOUSE"
        subgraph "RAW SCHEMA"
            D1[RAW_MOVIES]
            D2[RAW_TAGS]
            D3[RAW_LINKS]
            D4[RAW_GENOME_TAGS]
            D5[RAW_RATINGS]
            D6[RAW_GENOME_SCORES]
        end

        subgraph "DEV SCHEMA - dbt Managed"
            subgraph "STAGING LAYER - Views"
                E1[src_movies]
                E2[src_tags]
                E3[src_ratings]
                E4[src_genome_scores]
                E5[src_genome_tags]
                E6[src_link]
            end

            subgraph "DIMENSIONAL LAYER - Tables"
                F1[dim_movies<br/>genre arrays]
                F2[dim_users<br/>unique users]
                F3[dim_genome_tags<br/>tag labels]
            end

            subgraph "FACT LAYER - Tables"
                G1[fct_ratings<br/>INCREMENTAL]
                G2[fct_genome_score<br/>relevance scores]
            end

            subgraph "GOLD LAYER - Views"
                H1[genre_ratings]
                H2[user_engagement]
                H3[tag_relevance]
                H4[monthly_trends]
                H5[top10_by_genre]
                H6[movie_analysis]
                H7[release_trends]
            end

            subgraph "MART LAYER - Tables"
                I1[mart_movie_realeases]
            end
        end

        subgraph "SNAPSHOTS SCHEMA"
            J[snap_tags<br/>SCD Type 2]
        end
    end

    subgraph "dbt TOOL"
        K[dbt Core<br/>Transformation Engine]
        L[dbt Tests<br/>Data Quality]
        M[dbt Docs<br/>Documentation]
    end

    subgraph "BI & ANALYTICS"
        N[Tableau / PowerBI<br/>SQL Clients<br/>Analysts]
    end

    A -->|Upload| B
    B -->|Storage Integration| C
    C -->|COPY INTO| D1 & D2 & D3 & D4 & D5 & D6
    
    D1 & D2 & D3 & D4 & D5 & D6 -->|dbt source| E1 & E2 & E3 & E4 & E5 & E6
    
    E1 & E2 & E3 & E4 & E5 & E6 -->|dbt ref| F1 & F2 & F3
    
    E3 -->|dbt ref| G1
    E4 -->|dbt ref| G2
    
    F1 & F2 & F3 -->|dbt ref| G1 & G2
    
    G1 & G2 & F1 & F2 & F3 -->|dbt ref| H1 & H2 & H3 & H4 & H5 & H6 & H7
    
    F1 -->|dbt ref| I1
    
    E2 -->|dbt snapshot| J
    
    K -->|Builds| E1 & E2 & E3 & E4 & E5 & E6 & F1 & F2 & F3 & G1 & G2 & H1 & H2 & H3 & H4 & H5 & H6 & H7 & I1
    
    L -->|Validates| F1 & F2 & F3 & G1 & G2
    
    M -->|Documents| E1 & E2 & E3 & E4 & E5 & E6 & F1 & F2 & F3 & G1 & G2 & H1 & H2 & H3 & H4 & H5 & H6 & H7
    
    H1 & H2 & H3 & H4 & H5 & H6 & H7 & I1 -->|Query| N

    style A fill:#e1f5ff
    style B fill:#ff9900
    style C fill:#ff9900
    style K fill:#ff694b
    style L fill:#ff694b
    style M fill:#ff694b
    style N fill:#90ee90
```

## dbt Execution Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant DBT as dbt CLI
    participant SF as Snowflake
    participant Docs as Documentation

    Dev->>DBT: dbt debug
    DBT->>SF: Test connection
    SF-->>DBT: Connection OK
    DBT-->>Dev: ✓ All checks passed

    Dev->>DBT: dbt deps
    DBT->>DBT: Install dbt_utils
    DBT-->>Dev: ✓ Packages installed

    Dev->>DBT: dbt seed
    DBT->>SF: CREATE TABLE seed_movie_release_dates
    DBT->>SF: INSERT 10 rows
    SF-->>DBT: Success
    DBT-->>Dev: ✓ Seed loaded

    Dev->>DBT: dbt run
    
    DBT->>SF: CREATE VIEW src_movies
    DBT->>SF: CREATE VIEW src_tags
    DBT->>SF: CREATE VIEW src_ratings...
    SF-->>DBT: Staging views created

    DBT->>SF: CREATE TABLE dim_movies
    DBT->>SF: CREATE TABLE dim_users
    DBT->>SF: CREATE TABLE dim_genome_tags
    SF-->>DBT: Dimension tables created

    DBT->>SF: CREATE TABLE fct_ratings (incremental)
    DBT->>SF: CREATE TABLE fct_genome_score
    SF-->>DBT: Fact tables created

    DBT->>SF: CREATE VIEW genre_ratings
    DBT->>SF: CREATE VIEW user_engagement
    DBT->>SF: CREATE VIEW tag_relevance...
    SF-->>DBT: Gold views created

    DBT->>SF: CREATE TABLE mart_movie_realeases
    SF-->>DBT: Mart table created

    DBT-->>Dev: ✓ 20 models built successfully

    Dev->>DBT: dbt test
    DBT->>SF: SELECT (test queries)
    SF-->>DBT: Test results
    DBT-->>Dev: ✓ 15 tests passed

    Dev->>DBT: dbt snapshot
    DBT->>SF: CREATE/UPDATE snap_tags (SCD Type 2)
    SF-->>DBT: Snapshot updated
    DBT-->>Dev: ✓ Snapshot complete

    Dev->>DBT: dbt docs generate
    DBT->>Docs: Generate manifest.json
    DBT->>Docs: Generate catalog.json
    DBT-->>Dev: ✓ Documentation generated

    Dev->>DBT: dbt docs serve
    DBT->>Docs: Start web server on :8080
    Docs-->>Dev: 📊 http://localhost:8080
```

## Model Dependency Graph (DAG)

```mermaid
graph LR
    subgraph "Sources"
        S1[source: r_movies]
        S2[source: r_tags]
        S3[source: r_ratings]
        S4[source: r_genome_scores]
        S5[source: r_genome_tags]
        S6[source: r_links]
    end

    subgraph "Staging"
        ST1[src_movies]
        ST2[src_tags]
        ST3[src_ratings]
        ST4[src_genome_scores]
        ST5[src_genome_tags]
        ST6[src_link]
    end

    subgraph "Dimensions"
        D1[dim_movies]
        D2[dim_users]
        D3[dim_genome_tags]
    end

    subgraph "Facts"
        F1[fct_ratings]
        F2[fct_genome_score]
    end

    subgraph "Gold"
        G1[genre_ratings]
        G2[user_engagement]
        G3[tag_relevance]
        G4[monthly_trends]
        G5[top10_by_genre]
    end

    S1 --> ST1
    S2 --> ST2
    S3 --> ST3
    S4 --> ST4
    S5 --> ST5
    S6 --> ST6

    ST1 --> D1
    ST2 --> D2
    ST3 --> D2
    ST3 --> F1
    ST4 --> F2
    ST5 --> D3

    D1 --> F1
    D1 --> G1
    D1 --> G5
    D2 --> F1
    D3 --> F2

    F1 --> G1
    F1 --> G2
    F1 --> G4
    F2 --> G3
    D3 --> G3

    style S1 fill:#e8e8e8
    style S2 fill:#e8e8e8
    style S3 fill:#e8e8e8
    style S4 fill:#e8e8e8
    style S5 fill:#e8e8e8
    style S6 fill:#e8e8e8
    style ST1 fill:#e1f5ff
    style ST2 fill:#e1f5ff
    style ST3 fill:#e1f5ff
    style ST4 fill:#e1f5ff
    style ST5 fill:#e1f5ff
    style ST6 fill:#e1f5ff
    style D1 fill:#fff4e6
    style D2 fill:#fff4e6
    style D3 fill:#fff4e6
    style F1 fill:#ffe6f0
    style F2 fill:#ffe6f0
    style G1 fill:#e6ffe6
    style G2 fill:#e6ffe6
    style G3 fill:#e6ffe6
    style G4 fill:#e6ffe6
    style G5 fill:#e6ffe6
```

## Data Transformation Process

```mermaid
flowchart TD
    A[Raw Data in Snowflake] -->|dbt source| B{Staging Models}
    B -->|Clean & Standardize| C[src_* views]
    
    C -->|dbt ref| D{Business Logic Layer}
    D -->|Dimensions| E[dim_* tables]
    D -->|Facts| F[fct_* tables]
    
    E --> G{Materialization}
    F --> G
    
    G -->|Tables| H[Physical Storage<br/>Faster Queries]
    G -->|Views| I[Logical Views<br/>Always Fresh]
    G -->|Incremental| J[Append Only<br/>Performance]
    
    H --> K{Testing}
    I --> K
    J --> K
    
    K -->|Schema Tests| L[unique, not_null<br/>relationships]
    K -->|Custom Tests| M[Business Rules<br/>Data Quality]
    
    L --> N{Documentation}
    M --> N
    
    N --> O[manifest.json<br/>metadata]
    N --> P[catalog.json<br/>column info]
    N --> Q[Lineage Graph<br/>dependencies]
    
    O --> R[Interactive Docs<br/>localhost:8080]
    P --> R
    Q --> R
    
    R --> S[End Users<br/>Analysts, BI Tools]
```

## Incremental Loading Strategy

```mermaid
sequenceDiagram
    participant dbt
    participant Target as Target Table<br/>(fct_ratings)
    participant Source as Source<br/>(src_ratings)

    Note over dbt,Source: First Run (Full Load)
    dbt->>Source: SELECT * FROM src_ratings
    Source-->>dbt: All historical data
    dbt->>Target: CREATE TABLE fct_ratings
    dbt->>Target: INSERT all rows
    
    Note over dbt,Source: Subsequent Runs (Incremental)
    dbt->>Target: SELECT MAX(rating_timestamp)
    Target-->>dbt: 2024-10-20 12:00:00
    
    dbt->>Source: SELECT * FROM src_ratings<br/>WHERE rating_timestamp > '2024-10-20 12:00:00'
    Source-->>dbt: Only new records
    
    dbt->>Target: INSERT new rows only
    
    Note over dbt,Target: Result: Fast updates, no full table scans
```

## Testing Framework Flow

```mermaid
graph TB
    A[dbt test] --> B{Test Types}
    
    B --> C[Schema Tests<br/>schema.yml]
    B --> D[Custom Tests<br/>tests/ directory]
    
    C --> E[unique]
    C --> F[not_null]
    C --> G[relationships]
    C --> H[accepted_values]
    
    D --> I[relevant_score_test.sql]
    D --> J[Custom macros]
    
    E --> K{Execute SQL}
    F --> K
    G --> K
    H --> K
    I --> K
    J --> K
    
    K --> L[Snowflake Query]
    L --> M{Results}
    
    M -->|0 rows| N[✓ PASS<br/>No violations]
    M -->|>0 rows| O[✗ FAIL<br/>Data quality issue]
    
    N --> P[Test Report]
    O --> P
    
    P --> Q[PASS=15<br/>WARN=0<br/>ERROR=0]
    
    style N fill:#90ee90
    style O fill:#ff6b6b
    style Q fill:#90ee90
```

---

## Quick Reference Commands

```bash
# Setup
dbt debug              # Test connection
dbt deps               # Install packages

# Build
dbt seed               # Load seed files
dbt run                # Build all models
dbt run --select model # Build specific model

# Test
dbt test               # Run all tests
dbt test --select model # Test specific model

# Incremental
dbt run --full-refresh # Force full rebuild

# Documentation
dbt docs generate      # Generate docs
dbt docs serve         # View docs (localhost:8080)

# Snapshots
dbt snapshot           # Run SCD Type 2 tracking
```
