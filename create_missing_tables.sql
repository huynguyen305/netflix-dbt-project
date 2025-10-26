-- Additional Snowflake Setup - Create Missing Tables
-- Run this in your Snowflake worksheet

USE DATABASE MOVIELENS;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- Create RAW_RATINGS table (if you don't have ratings.csv data)
CREATE OR REPLACE TABLE RAW.RAW_RATINGS (
    userId INT,
    movieId INT,
    rating FLOAT,
    timestamp BIGINT
);

-- Create RAW_GENOME_SCORES table (if you don't have genome-scores.csv data)
CREATE OR REPLACE TABLE RAW.RAW_GENOME_SCORES (
    movieId INT,
    tagId INT,
    relevance FLOAT
);

-- Verify tables exist
SHOW TABLES IN SCHEMA RAW;

-- Check row counts (will be 0 if no data loaded)
SELECT 'RAW_MOVIES' as table_name, COUNT(*) as row_count FROM RAW.RAW_MOVIES
UNION ALL
SELECT 'RAW_TAGS', COUNT(*) FROM RAW.RAW_TAGS
UNION ALL
SELECT 'RAW_LINKS', COUNT(*) FROM RAW.RAW_LINKS
UNION ALL
SELECT 'RAW_GENOME_TAGS', COUNT(*) FROM RAW.RAW_GENOME_TAGS
UNION ALL
SELECT 'RAW_RATINGS', COUNT(*) FROM RAW.RAW_RATINGS
UNION ALL
SELECT 'RAW_GENOME_SCORES', COUNT(*) FROM RAW.RAW_GENOME_SCORES;
