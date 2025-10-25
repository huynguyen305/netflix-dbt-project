# Netflix dbt Project - Copilot Instructions

## Project Architecture

This is a **Netflix movie analytics pipeline** using the modern data stack: **AWS S3 → Snowflake → dbt**. The data flows through a layered architecture within the `/netflix/` directory:

- **Raw Layer**: Source data from Snowflake tables (`MOVIELENS.RAW.*`)
- **Staging Layer**: Basic cleaning in `models/staging/src_*.sql` 
- **Dimensional Layer**: Star schema with `models/dim/` (tables) and `models/fct/` (tables/incremental)
- **Gold Layer**: Analytics models in `models/gold/` for end-user consumption
- **Mart Layer**: Business-specific aggregations in `models/mart/`

## Key Patterns & Conventions

### Model Materialization Strategy
```yaml
# From dbt_project.yml - default views, but dims/facts are tables
models:
  netflix:
    +materialized: view
    dim:
      +materialized: table  
    fct:
      +materialized: table
```

### Incremental Loading Pattern
Fact tables use incremental loads with timestamp-based filtering:
```sql
-- Pattern used in fct_ratings.sql
{{
    config(
        materialized='incremental',
        on_schema_change='fail'
    )
}}
{% if is_incremental() %}
    AND rating_timestamp > (SELECT (MAX(rating_timestamp)) FROM {{ this }})
{% endif %}
```

### Source Configuration
All raw tables are defined in `models/sources.yml` with consistent naming:
- Source name: `netflix` 
- Schema: `raw`
- Table pattern: `r_*` identifier maps to `raw_*` actual table names

### Custom Macros
- `no_nulls_in_columns(model)`: Generates null checks for all columns in a model
- Used in custom tests like `tests/relevant_score_test.sql`

### Naming Conventions
- **Staging**: `src_*.sql` (views, basic cleaning)
- **Dimensions**: `dim_*.sql` (tables, star schema entities)  
- **Facts**: `fct_*.sql` (tables/incremental, measurements/events)
- **Gold**: Business analysis models for reporting
- **Column naming**: snake_case with descriptive suffixes (`movie_id`, `rating_timestamp`)

## Development Workflows

### Essential Commands
```bash
cd netflix/  # All dbt commands run from netflix/ subdirectory
dbt deps     # Install packages (dbt_utils required)
dbt seed     # Load seed_movie_release_dates.csv
dbt run      # Build all models (staging → dim → fct → gold)
dbt test     # Run schema tests and custom tests
dbt snapshot # Run SCD snapshots (snap_tags.sql)
```

### Data Quality Testing
- Schema tests in `models/schema.yml` (unique, not_null)
- Custom macro-based tests in `tests/` directory
- Snapshot strategy uses timestamp-based SCD Type 2 tracking

### Dependencies & Packages
- Requires `dbt-labs/dbt_utils` v1.3.0 for surrogate key generation in snapshots
- Snowflake connection via `profiles.yml` (not in repo)

## Integration Points

### External Systems
- **Source**: Snowflake warehouse `MOVIELENS` with schema `RAW`
- **Target**: Models deployed to `DEV` schema in Snowflake
- **Seeds**: Static reference data (`seed_movie_release_dates.csv`)

### Cross-Model Dependencies
- Staging models reference `{{ source('netflix', 'r_*') }}`
- Dimensional models use `{{ ref('src_*') }}`  
- Gold layer aggregates from `MOVIELENS.DEV.fct_*` and `MOVIELENS.DEV.dim_*`
- Snapshots track changes in `src_tags` with SCD Type 2

## Project-Specific Notes

- **Array handling**: Movie genres stored as pipe-delimited strings, converted to arrays in `dim_movies`
- **Incremental strategy**: Time-based on rating/tag timestamps, not ID-based
- **Schema references**: Gold models use direct schema references (`MOVIELENS.DEV.*`) instead of `{{ ref() }}`
- **Snapshot limitations**: Limited to 100 rows in `snap_tags.sql` for demo purposes
- **Test patterns**: Custom tests use macros rather than inline SQL for reusability