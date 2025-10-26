# Netflix dbt Project Integration Guide

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture Flowchart](#architecture-flowchart)
- [Prerequisites](#prerequisites)
- [Integration Steps](#integration-steps)
- [Data Flow](#data-flow)
- [Results & Outputs](#results--outputs)
- [Project Structure](#project-structure)

---

## 🎯 Overview

This project demonstrates a complete **modern data stack** implementation using:
- **AWS S3** → Raw data storage
- **Snowflake** → Cloud data warehouse
- **dbt (Data Build Tool)** → Data transformation & modeling

**Purpose**: Transform raw Netflix movie data into analytics-ready models using SQL-based transformations with version control, testing, and documentation.

---

## 🔄 Architecture Flowchart

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA PIPELINE FLOW                            │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│   RAW DATA       │
│   (Local CSV)    │
│                  │
│ • movies.csv     │
│ • tags.csv       │
│ • links.csv      │
│ • genome-tags.csv│
└────────┬─────────┘
         │
         │ Upload
         ▼
┌──────────────────┐
│   AWS S3 BUCKET  │
│                  │
│ netflix-dbt-data │
│   /raw-data/     │
└────────┬─────────┘
         │
         │ COPY INTO
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      SNOWFLAKE DATA WAREHOUSE                         │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  RAW SCHEMA (MOVIELENS.RAW)                                    │ │
│  │                                                                 │ │
│  │  • RAW_MOVIES          • RAW_RATINGS                           │ │
│  │  • RAW_TAGS            • RAW_GENOME_SCORES                     │ │
│  │  • RAW_LINKS           • RAW_GENOME_TAGS                       │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                         │
│                             │ dbt reads from (source)                 │
│                             ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  DEV SCHEMA (MOVIELENS.DEV) - dbt Managed                      │ │
│  │                                                                 │ │
│  │  ┌───────────────────────────────────────────────────────┐    │ │
│  │  │ STAGING LAYER (Views)                                  │    │ │
│  │  │ ┌─────────────────────────────────────────────────┐   │    │ │
│  │  │ │ • src_movies      • src_ratings                 │   │    │ │
│  │  │ │ • src_tags        • src_genome_scores           │   │    │ │
│  │  │ │ • src_genome_tags • src_link                    │   │    │ │
│  │  │ │                                                 │   │    │ │
│  │  │ │ Purpose: Basic cleaning & standardization      │   │    │ │
│  │  │ └─────────────────────────────────────────────────┘   │    │ │
│  │  └───────────────────────┬───────────────────────────────┘    │ │
│  │                          │ dbt ref()                           │ │
│  │                          ▼                                      │ │
│  │  ┌───────────────────────────────────────────────────────┐    │ │
│  │  │ DIMENSIONAL LAYER (Tables)                             │    │ │
│  │  │ ┌─────────────────────────────────────────────────┐   │    │ │
│  │  │ │ • dim_movies (with genre arrays)                │   │    │ │
│  │  │ │ • dim_users (unique users)                      │   │    │ │
│  │  │ │ • dim_genome_tags (tag labels)                  │   │    │ │
│  │  │ │                                                 │   │    │ │
│  │  │ │ Purpose: Star schema dimensions                │   │    │ │
│  │  │ └─────────────────────────────────────────────────┘   │    │ │
│  │  └───────────────────────┬───────────────────────────────┘    │ │
│  │                          │ dbt ref()                           │ │
│  │                          ▼                                      │ │
│  │  ┌───────────────────────────────────────────────────────┐    │ │
│  │  │ FACT LAYER (Tables/Incremental)                        │    │ │
│  │  │ ┌─────────────────────────────────────────────────┐   │    │ │
│  │  │ │ • fct_ratings (INCREMENTAL)                     │   │    │ │
│  │  │ │   → Timestamp-based incremental loading         │   │    │ │
│  │  │ │ • fct_genome_score                              │   │    │ │
│  │  │ │                                                 │   │    │ │
│  │  │ │ Purpose: Fact tables with metrics               │   │    │ │
│  │  │ └─────────────────────────────────────────────────┘   │    │ │
│  │  └───────────────────────┬───────────────────────────────┘    │ │
│  │                          │ dbt ref()                           │ │
│  │                          ▼                                      │ │
│  │  ┌───────────────────────────────────────────────────────┐    │ │
│  │  │ GOLD LAYER (Views - Analytics Ready)                   │    │ │
│  │  │ ┌─────────────────────────────────────────────────┐   │    │ │
│  │  │ │ • genre_ratings (avg by genre)                  │   │    │ │
│  │  │ │ • user_engagement (activity metrics)            │   │    │ │
│  │  │ │ • tag_relevance (tag analysis)                  │   │    │ │
│  │  │ │ • monthly_trends (time series)                  │   │    │ │
│  │  │ │ • top10_by_genre (rankings)                     │   │    │ │
│  │  │ │ • movie_analysis (detailed stats)               │   │    │ │
│  │  │ │                                                 │   │    │ │
│  │  │ │ Purpose: Business-ready analytics               │   │    │ │
│  │  │ └─────────────────────────────────────────────────┘   │    │ │
│  │  └───────────────────────┬───────────────────────────────┘    │ │
│  │                          │                                      │ │
│  │  ┌───────────────────────▼───────────────────────────────┐    │ │
│  │  │ MART LAYER (Tables)                                    │    │ │
│  │  │ • mart_movie_realeases (business-specific)             │    │ │
│  │  └────────────────────────────────────────────────────────┘    │ │
│  │                                                                 │ │
│  └─────────────────────────────────────────────────────────────── │ │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  SNAPSHOTS SCHEMA (MOVIELENS.SNAPSHOTS)                        │ │
│  │  • snap_tags (SCD Type 2 - Historical tracking)                │ │
│  └────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────┘
         │
         │ Query Results
         ▼
┌──────────────────┐
│  BI TOOLS /      │
│  ANALYSTS        │
│                  │
│ • Tableau        │
│ • PowerBI        │
│ • SQL Clients    │
└──────────────────┘
```

---

## 📌 Prerequisites

### 1. **Development Environment**
```bash
✅ WSL2 or Linux environment
✅ Python 3.8+ (we used 3.12.3)
✅ pip (Python package manager)
✅ Git for version control
```

### 2. **Cloud Services**
```bash
✅ AWS Account
   - IAM user with S3 permissions
   - Access Key & Secret Key

✅ Snowflake Account
   - Account identifier (e.g., abc12345.us-east-1)
   - Username & Password
   - ACCOUNTADMIN or similar role
```

### 3. **Required Tools**
```bash
✅ AWS CLI (for S3 operations)
✅ dbt-snowflake (for transformations)
✅ Text editor (VS Code recommended)
```

---

## 🛠️ Integration Steps

### **Phase 1: AWS S3 Setup**

#### Step 1.1: Install AWS CLI
```bash
sudo snap install aws-cli --classic
aws --version
```

#### Step 1.2: Configure AWS Credentials
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Region: us-east-1
# - Output: json
```

#### Step 1.3: Create S3 Bucket & Upload Data
```bash
cd /home/huyng/netflix-dbt-project/netflix-dbt-project
./setup_aws_s3.sh
```

**What happens:**
- Creates S3 bucket: `netflix-dbt-data-YYYYMMDD`
- Enables versioning
- Uploads CSV files from `/data/` directory
- Generates IAM policy for Snowflake access

**Result:**
```
✅ S3 Bucket created: s3://netflix-dbt-data-20251025/raw-data/
✅ Files uploaded:
   - genome-tags.csv (16.6 KB)
   - links.csv (530.1 KB)
   - movies.csv (1.3 MB)
   - tags.csv (15.4 MB)
```

---

### **Phase 2: Snowflake Setup**

#### Step 2.1: Create Database Structure
Run in Snowflake SQL worksheet:
```sql
-- Create database and schemas
CREATE DATABASE MOVIELENS;
CREATE SCHEMA MOVIELENS.RAW;
CREATE SCHEMA MOVIELENS.DEV;
CREATE SCHEMA MOVIELENS.SNAPSHOTS;

-- Create warehouse
CREATE WAREHOUSE COMPUTE_WH 
WITH WAREHOUSE_SIZE='X-SMALL' 
AUTO_SUSPEND=300 
AUTO_RESUME=TRUE;
```

#### Step 2.2: Configure S3 Integration
```sql
-- Create storage integration
CREATE STORAGE INTEGRATION s3_netflix_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR_ACCOUNT:role/snowflake-s3-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://netflix-dbt-data-20251025/raw-data/');

-- Get Snowflake IAM User ARN (for AWS IAM trust policy)
DESC STORAGE INTEGRATION s3_netflix_integration;
```

#### Step 2.3: Configure AWS IAM Role
```bash
cd /home/huyng/netflix-dbt-project/netflix-dbt-project
./setup_iam_role.sh
# Enter Snowflake's IAM User ARN and External ID when prompted
```

**What happens:**
- Creates IAM role: `snowflake-s3-role`
- Configures trust relationship with Snowflake
- Attaches S3 read permissions

#### Step 2.4: Create Staging & Load Data
```sql
-- Create file format
CREATE FILE FORMAT csv_format
  TYPE='CSV'
  FIELD_DELIMITER=','
  SKIP_HEADER=1
  FIELD_OPTIONALLY_ENCLOSED_BY='"'
  TRIM_SPACE=TRUE;

-- Create external stage
CREATE STAGE s3_netflix_stage
  STORAGE_INTEGRATION = s3_netflix_integration
  URL = 's3://netflix-dbt-data-20251025/raw-data/'
  FILE_FORMAT = csv_format;

-- Verify connection
LIST @s3_netflix_stage;

-- Create raw tables
CREATE TABLE RAW.RAW_MOVIES (movieId INT, title STRING, genres STRING);
CREATE TABLE RAW.RAW_TAGS (userId INT, movieId INT, tag STRING, timestamp BIGINT);
CREATE TABLE RAW.RAW_LINKS (movieId INT, imdbId STRING, tmdbId STRING);
CREATE TABLE RAW.RAW_GENOME_TAGS (tagId INT, tag STRING);
CREATE TABLE RAW.RAW_RATINGS (userId INT, movieId INT, rating FLOAT, timestamp BIGINT);
CREATE TABLE RAW.RAW_GENOME_SCORES (movieId INT, tagId INT, relevance FLOAT);

-- Load data from S3
COPY INTO RAW.RAW_MOVIES FROM @s3_netflix_stage/movies.csv FILE_FORMAT=csv_format;
COPY INTO RAW.RAW_TAGS FROM @s3_netflix_stage/tags.csv FILE_FORMAT=csv_format;
COPY INTO RAW.RAW_LINKS FROM @s3_netflix_stage/links.csv FILE_FORMAT=csv_format;
COPY INTO RAW.RAW_GENOME_TAGS FROM @s3_netflix_stage/genome-tags.csv FILE_FORMAT=csv_format;
```

**Result:**
```
✅ Raw tables created in MOVIELENS.RAW schema
✅ Data loaded from S3 into Snowflake
✅ Verified row counts for all tables
```

---

### **Phase 3: dbt Setup & Configuration**

#### Step 3.1: Install dbt
```bash
cd /home/huyng/netflix-dbt-project/netflix-dbt-project

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dbt-snowflake
pip install dbt-snowflake

# Verify installation
dbt --version
```

**Result:**
```
Core: 1.11.0-b3
Plugins:
  - snowflake: 1.10.2
```

#### Step 3.2: Configure dbt Profile
Create `~/.dbt/profiles.yml`:
```yaml
netflix:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: ORQFPMS-CE07071  # Your Snowflake account
      user: johnng305            # Your username
      password: ********         # Your password
      role: ACCOUNTADMIN
      database: MOVIELENS
      warehouse: COMPUTE_WH
      schema: DEV
      threads: 4
      client_session_keep_alive: False
```

#### Step 3.3: Test Connection
```bash
cd netflix
dbt debug
```

**Result:**
```
✅ profiles.yml file [OK found and valid]
✅ dbt_project.yml file [OK found and valid]
✅ Connection test: [OK connection ok]
✅ All checks passed!
```

---

### **Phase 4: dbt Execution**

#### Step 4.1: Install Dependencies
```bash
dbt deps
```

**What happens:**
- Installs `dbt_utils` package (v1.3.0)
- Used for surrogate key generation in snapshots

#### Step 4.2: Load Seed Data
```bash
dbt seed
```

**What happens:**
- Loads `seed_movie_release_dates.csv` into Snowflake
- Creates static reference table

**Result:**
```
✅ seed_movie_release_dates [INSERT 10 rows]
```

#### Step 4.3: Run All Models
```bash
dbt run
```

**Execution Order (automatically determined by dbt):**
1. **Staging Layer** (6 views)
   - `src_movies`, `src_tags`, `src_ratings`, `src_genome_scores`, `src_genome_tags`, `src_link`

2. **Dimensional Layer** (3 tables)
   - `dim_movies` (with genre arrays)
   - `dim_users` (from ratings + tags)
   - `dim_genome_tags` (cleaned tag labels)

3. **Fact Layer** (2 tables)
   - `fct_ratings` (incremental - only new ratings)
   - `fct_genome_score` (relevance scores)

4. **Gold Layer** (7 views)
   - `genre_ratings`, `user_engagement`, `tag_relevance`
   - `monthly_trends`, `movie_analysis`, `top10_by_genre`
   - `release_trends`

5. **Mart Layer** (1 table)
   - `mart_movie_realeases` (business-specific)

**Result:**
```
✅ Done. PASS=20 WARN=0 ERROR=0 SKIP=0 TOTAL=20
⏱️ Finished in 6.32 seconds
```

#### Step 4.4: Run Tests
```bash
dbt test
```

**What tests run:**
- **Schema tests** (from `models/schema.yml`):
  - `unique` checks (user_id, tag_id)
  - `not_null` checks (primary keys, required fields)
  - `relationships` checks (foreign key integrity)
  
- **Custom tests** (from `tests/` directory):
  - `relevant_score_test` (using custom macro)

**Result:**
```
✅ Done. PASS=15 WARN=0 ERROR=0 SKIP=0 TOTAL=15
```

#### Step 4.5: Run Snapshots (Optional)
```bash
dbt snapshot
```

**What happens:**
- Creates SCD Type 2 tracking for `src_tags`
- Tracks historical changes with validity timestamps
- Limited to 100 rows for demo

#### Step 4.6: Generate Documentation
```bash
dbt docs generate
dbt docs serve --port 8080
```

**What's included:**
- Interactive lineage graph (DAG)
- Model descriptions & column definitions
- Test coverage visualization
- Source data documentation
- Compiled SQL code

**Result:**
```
✅ Documentation available at http://localhost:8080
```

---

## 📊 Data Flow Details

### **1. Staging Layer**
```sql
-- Example: src_movies.sql
WITH raw_movies AS (
    SELECT * FROM MOVIELENS.RAW.RAW_MOVIES
)
SELECT
    movieId AS movie_id,
    title,
    genres
FROM raw_movies
```

**Purpose:**
- Clean field names (camelCase → snake_case)
- Basic filtering (WHERE conditions)
- No business logic yet

**Materialization:** Views (no data storage, always fresh)

---

### **2. Dimensional Layer**
```sql
-- Example: dim_movies.sql
WITH src_movies AS (
    SELECT * FROM {{ ref('src_movies') }}
)
SELECT
    movie_id,
    INITCAP(TRIM(title)) AS movie_title,
    SPLIT(genres, '|') AS genre_array,  -- Convert to array
    genres
FROM src_movies
```

**Purpose:**
- Apply business logic (title formatting)
- Create derived fields (genre arrays)
- Build star schema dimensions

**Materialization:** Tables (faster queries, updated on each run)

---

### **3. Fact Layer**
```sql
-- Example: fct_ratings.sql (INCREMENTAL)
{{
    config(
        materialized='incremental',
        on_schema_change='fail'
    )
}}

WITH src_ratings AS (
    SELECT * FROM {{ ref('src_ratings') }}
)

SELECT
    user_id,
    movie_id,
    rating,
    rating_timestamp
FROM src_ratings
WHERE rating IS NOT NULL

{% if is_incremental() %}
    -- Only load new ratings
    AND rating_timestamp > (SELECT MAX(rating_timestamp) FROM {{ this }})
{% endif %}
```

**Purpose:**
- Store metrics & measurements
- Incremental loading for performance
- Timestamp-based change detection

**Materialization:** Table (incremental updates)

---

### **4. Gold Layer**
```sql
-- Example: genre_ratings.sql
SELECT
    g.value::string AS genre,
    AVG(r.rating) AS average_rating,
    COUNT(DISTINCT m.movie_id) AS total_movies
FROM {{ ref('fct_ratings') }} r
JOIN {{ ref('dim_movies') }} m 
    ON r.movie_id = m.movie_id,
    LATERAL FLATTEN(input => m.genre_array) g
GROUP BY genre
ORDER BY average_rating DESC
```

**Purpose:**
- Business-ready analytics
- Pre-aggregated metrics
- Optimized for BI tools

**Materialization:** Views (always current, no storage)

---

## 🎯 Results & Outputs

### **1. Snowflake Objects Created**

```
MOVIELENS Database
├── RAW Schema (6 tables)
│   ├── RAW_MOVIES
│   ├── RAW_TAGS
│   ├── RAW_LINKS
│   ├── RAW_GENOME_TAGS
│   ├── RAW_RATINGS
│   └── RAW_GENOME_SCORES
│
├── DEV Schema (20 objects)
│   ├── Staging Views (6)
│   ├── Dimension Tables (3)
│   ├── Fact Tables (2)
│   ├── Gold Views (7)
│   ├── Mart Tables (1)
│   └── Seed Tables (1)
│
└── SNAPSHOTS Schema
    └── snap_tags (SCD Type 2)
```

### **2. dbt Artifacts Generated**

```
netflix/target/
├── manifest.json       # Full project metadata
├── catalog.json        # Column-level metadata
├── run_results.json    # Execution results
├── compiled/           # Compiled SQL (with refs resolved)
└── run/               # Executed SQL statements
```

### **3. Key Metrics**

| Metric | Value |
|--------|-------|
| **Total Models** | 21 |
| **Data Tests** | 15 |
| **Sources** | 6 |
| **Snapshots** | 1 |
| **Seeds** | 1 |
| **Build Time** | ~6 seconds |
| **Test Time** | ~4 seconds |
| **Success Rate** | 100% |

---

## 📁 Project Structure

```
netflix-dbt-project/
├── data/                          # Raw CSV files
│   ├── movies.csv
│   ├── tags.csv
│   ├── links.csv
│   └── genome-tags.csv
│
├── netflix/                       # dbt project root
│   ├── dbt_project.yml           # Project configuration
│   ├── packages.yml              # Package dependencies
│   │
│   ├── models/                   # SQL models
│   │   ├── sources.yml          # Source definitions
│   │   ├── schema.yml           # Model documentation & tests
│   │   │
│   │   ├── staging/             # Staging layer
│   │   │   ├── src_movies.sql
│   │   │   ├── src_tags.sql
│   │   │   ├── src_ratings.sql
│   │   │   ├── src_genome_scores.sql
│   │   │   ├── src_genome_tags.sql
│   │   │   └── src_link.sql
│   │   │
│   │   ├── dim/                 # Dimensions
│   │   │   ├── dim_movies.sql
│   │   │   ├── dim_users.sql
│   │   │   └── dim_genome_tags.sql
│   │   │
│   │   ├── fct/                 # Facts
│   │   │   ├── fct_ratings.sql (incremental)
│   │   │   ├── fct_genome_score.sql
│   │   │   └── ep_movie_with_tags.sql (ephemeral)
│   │   │
│   │   ├── gold/                # Analytics
│   │   │   ├── genre_ratings.sql
│   │   │   ├── user_engagement.sql
│   │   │   ├── tag_relevance.sql
│   │   │   ├── monthly_trends.sql
│   │   │   ├── movie_analysis.sql
│   │   │   ├── top10_by_genre.sql
│   │   │   └── release_trends.sql
│   │   │
│   │   └── mart/                # Business marts
│   │       └── mart_movie_realeases.sql
│   │
│   ├── seeds/                   # Static data
│   │   └── seed_movie_release_dates.csv
│   │
│   ├── snapshots/               # SCD tracking
│   │   └── snap_tags.sql
│   │
│   ├── tests/                   # Custom tests
│   │   └── relevant_score_test.sql
│   │
│   ├── macros/                  # Reusable SQL
│   │   └── no_nulls_in_columns.sql
│   │
│   └── analyses/                # Ad-hoc queries
│       └── movie_analysis.sql
│
├── .github/
│   └── copilot-instructions.md  # AI agent guidance
│
├── setup_aws_s3.sh              # AWS automation script
├── setup_iam_role.sh            # IAM role automation
├── snowflake_setup.sql          # Snowflake SQL commands
└── aws_iam_policy.json          # IAM policy document
```

---

## 🔑 Key Integration Features

### **1. Materialization Strategy**
```yaml
# dbt_project.yml
models:
  netflix:
    +materialized: view      # Default: views
    dim:
      +materialized: table   # Dimensions: tables
    fct:
      +materialized: table   # Facts: tables
```

### **2. Incremental Loading**
```sql
-- Only loads new data based on timestamp
{% if is_incremental() %}
    AND rating_timestamp > (SELECT MAX(rating_timestamp) FROM {{ this }})
{% endif %}
```

### **3. Testing Framework**
- **Built-in tests**: unique, not_null, relationships, accepted_values
- **Custom tests**: Using macros for reusable logic
- **Data quality**: Automated validation on each run

### **4. Documentation**
- **Auto-generated**: From code comments and schema.yml
- **Lineage graph**: Visual DAG of dependencies
- **Column-level**: Descriptions and data types

### **5. Version Control**
- Git for tracking changes
- Modular SQL files
- Reproducible builds

---

## 🚀 Ongoing Operations

### **Daily Operations**
```bash
# Activate environment
source .venv/bin/activate
cd netflix

# Run incremental updates
dbt run --select fct_ratings

# Run all models (fresh build)
dbt run

# Validate data quality
dbt test
```

### **Data Refresh**
```bash
# Full refresh of incremental models
dbt run --full-refresh --select fct_ratings

# Run specific model and dependencies
dbt run --select +dim_movies
```

### **Monitoring**
```bash
# Check run results
dbt run-operation list_models

# View compiled SQL
cat target/compiled/netflix/models/gold/genre_ratings.sql
```

---

## 📈 Benefits of This Integration

1. **Modularity**: Each model is a separate SQL file
2. **Testability**: Automated data quality checks
3. **Documentation**: Self-documenting with lineage
4. **Version Control**: Git-based workflow
5. **Performance**: Incremental loading, materialization options
6. **Reproducibility**: Consistent builds across environments
7. **Collaboration**: Clear dependencies and logic

---

## 🎓 Learning Resources

- **dbt Docs**: https://docs.getdbt.com/
- **Snowflake Docs**: https://docs.snowflake.com/
- **Project README**: `/README.md` (detailed tutorial)
- **Medium Article**: [Building an End-to-End Data Pipeline](https://medium.com/@codegnerdev/building-an-end-to-end-data-pipeline-with-dbt-snowflake-aws-the-netflix-data-analysis-project-bc26c1825e52)

---

**End of Integration Guide** 🎬
