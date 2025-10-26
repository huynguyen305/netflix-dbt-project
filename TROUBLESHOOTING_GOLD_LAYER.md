# Why Gold Layer Has No Data - Troubleshooting Guide

## 🔍 Problem Analysis

The gold layer models (like `DEV.MOVIE_ANALYSIS`) have **no data** because they depend on `fct_ratings`, which is empty.

## 🎯 Root Cause

### Data Dependency Chain:
```
RAW_RATINGS (EMPTY) 
    ↓
src_ratings (EMPTY)
    ↓
fct_ratings (EMPTY)
    ↓
Gold Layer Views (NO DATA)
    - movie_analysis
    - genre_ratings
    - user_engagement
    - monthly_trends
    - top10_by_genre
```

### Why RAW_RATINGS is Empty:

When we set up the project, we only had 4 CSV files:
- ✅ `movies.csv` → Loaded into `RAW_MOVIES`
- ✅ `tags.csv` → Loaded into `RAW_TAGS`
- ✅ `links.csv` → Loaded into `RAW_LINKS`
- ✅ `genome-tags.csv` → Loaded into `RAW_GENOME_TAGS`

**Missing files:**
- ❌ `ratings.csv` → `RAW_RATINGS` is **empty**
- ❌ `genome-scores.csv` → `RAW_GENOME_SCORES` is **empty**

We created the table structure but never loaded actual ratings data.

## 📊 Impact Assessment

### Models with Data:
- ✅ `dim_movies` - Has data (from movies.csv)
- ✅ `dim_genome_tags` - Has data (from genome-tags.csv)
- ✅ `release_trends` - Works (uses dim_movies only)

### Models without Data:
- ❌ `fct_ratings` - Empty (no source data)
- ❌ `fct_genome_score` - Empty (no genome-scores data)
- ❌ `dim_users` - Empty (derives from ratings)
- ❌ `movie_analysis` - Empty (needs fct_ratings)
- ❌ `genre_ratings` - Empty (needs fct_ratings)
- ❌ `user_engagement` - Empty (needs fct_ratings)
- ❌ `monthly_trends` - Empty (needs fct_ratings)
- ❌ `top10_by_genre` - Empty (needs fct_ratings)
- ❌ `tag_relevance` - Empty (needs fct_genome_score)

## 🔧 Solutions

### **Option 1: Generate Sample Data (Quick - for Testing)**

Run the generated SQL script in Snowflake:

```sql
-- File: generate_sample_data.sql
-- This creates 500 sample ratings (100 movies × 5 ratings each)
```

**Steps:**
1. Open Snowflake SQL worksheet
2. Copy contents from `generate_sample_data.sql`
3. Run the script
4. Re-run dbt models:
   ```bash
   cd /home/huyng/netflix-dbt-project/netflix-dbt-project
   source .venv/bin/activate
   cd netflix
   dbt run --full-refresh
   ```

**Result:**
- ✅ `RAW_RATINGS` will have ~500 rows
- ✅ `RAW_GENOME_SCORES` will have ~1000 rows
- ✅ Gold layer will populate with analytics

---

### **Option 2: Download Real MovieLens Dataset**

Get the complete MovieLens dataset with ratings:

**Source:** https://grouplens.org/datasets/movielens/

1. **Download MovieLens 25M Dataset:**
   ```bash
   wget https://files.grouplens.org/datasets/movielens/ml-25m.zip
   unzip ml-25m.zip
   ```

2. **Upload to S3:**
   ```bash
   aws s3 cp ml-25m/ratings.csv s3://netflix-dbt-data-20251025/raw-data/
   aws s3 cp ml-25m/genome-scores.csv s3://netflix-dbt-data-20251025/raw-data/
   ```

3. **Load into Snowflake:**
   ```sql
   COPY INTO RAW.RAW_RATINGS
   FROM @s3_netflix_stage/ratings.csv
   FILE_FORMAT = csv_format
   ON_ERROR = 'CONTINUE';

   COPY INTO RAW.RAW_GENOME_SCORES
   FROM @s3_netflix_stage/genome-scores.csv
   FILE_FORMAT = csv_format
   ON_ERROR = 'CONTINUE';
   ```

4. **Re-run dbt:**
   ```bash
   dbt run --full-refresh
   ```

**Result:**
- ✅ Real production-like data
- ✅ ~25 million ratings
- ✅ Complete analytics

---

### **Option 3: Modify Gold Models (Work with Available Data)**

Comment out models that need ratings and focus on what works:

```yaml
# dbt_project.yml - Add this to exclude models
models:
  netflix:
    gold:
      movie_analysis:
        +enabled: false
      genre_ratings:
        +enabled: false
      user_engagement:
        +enabled: false
      monthly_trends:
        +enabled: false
      top10_by_genre:
        +enabled: false
```

Then create new gold models using only available data (movies, tags, links).

---

## 🚀 Quick Fix Commands

### Check Current Data Status:
```sql
-- Run in Snowflake
SELECT 
    'RAW_MOVIES' as table_name, 
    COUNT(*) as row_count 
FROM MOVIELENS.RAW.RAW_MOVIES

UNION ALL

SELECT 'RAW_RATINGS', COUNT(*) 
FROM MOVIELENS.RAW.RAW_RATINGS

UNION ALL

SELECT 'RAW_TAGS', COUNT(*) 
FROM MOVIELENS.RAW.RAW_TAGS

UNION ALL

SELECT 'FCT_RATINGS', COUNT(*) 
FROM MOVIELENS.DEV.FCT_RATINGS;
```

### After Adding Data:
```bash
# Full refresh to reload everything
cd /home/huyng/netflix-dbt-project/netflix-dbt-project
source .venv/bin/activate
cd netflix

# Option 1: Full refresh of all models
dbt run --full-refresh

# Option 2: Refresh only ratings-dependent models
dbt run --full-refresh --select src_ratings fct_ratings+ gold
```

## 📊 Expected Results After Fix

Once you add rating data, you should see:

### `movie_analysis`:
```
| movie_title              | average_rating | total_ratings |
|-------------------------|----------------|---------------|
| The Shawshank Redemption| 4.5            | 150           |
| The Godfather           | 4.4            | 145           |
| ...                     | ...            | ...           |
```

### `genre_ratings`:
```
| genre    | average_rating | total_movies |
|----------|----------------|--------------|
| Drama    | 4.2            | 1500         |
| Comedy   | 3.8            | 1200         |
| ...      | ...            | ...          |
```

### `user_engagement`:
```
| user_id | number_of_ratings | average_rating_given |
|---------|-------------------|----------------------|
| 123     | 250               | 4.1                  |
| 456     | 180               | 3.9                  |
| ...     | ...               | ...                  |
```

## 🎓 Key Learnings

1. **Source Data is Critical:** dbt transforms data but needs source data first
2. **Empty Tables ≠ Schema Errors:** Models can build successfully with 0 rows
3. **Dependency Chain:** Understand upstream dependencies when troubleshooting
4. **Incremental Models:** Empty on first run if source is empty
5. **Testing:** Always verify source data before building downstream models

## 📝 Prevention for Future Projects

### Before running dbt:
```bash
# 1. Verify source data exists
SELECT COUNT(*) FROM RAW.RAW_RATINGS;  -- Should be > 0

# 2. Check all source tables
SELECT 
    table_name, 
    row_count 
FROM INFORMATION_SCHEMA.TABLES 
WHERE table_schema = 'RAW';

# 3. Then run dbt
dbt run
```

### Add data validation tests:
```yaml
# models/schema.yml
sources:
  - name: netflix
    tables:
      - name: r_ratings
        tests:
          - dbt_utils.recency:
              datepart: day
              field: timestamp
              interval: 365
```

---

## 🔗 Next Steps

Choose one of the solutions above:
1. **Generate sample data** (fastest - 5 minutes)
2. **Download real dataset** (most realistic - 30 minutes)
3. **Modify models** (work with what you have)

Let me know which option you'd like to pursue!
