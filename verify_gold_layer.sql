-- Verify Gold Layer Data
-- Run this in Snowflake to check that data flowed from RAW to GOLD

USE DATABASE MOVIELENS;
USE WAREHOUSE COMPUTE_WH;

-- Check data counts at each layer
SELECT 'RAW LAYER' as layer, 'RAW_RATINGS' as table_name, COUNT(*) as row_count 
FROM RAW.RAW_RATINGS

UNION ALL

SELECT 'RAW LAYER', 'RAW_GENOME_SCORES', COUNT(*) 
FROM RAW.RAW_GENOME_SCORES

UNION ALL

SELECT 'STAGING LAYER', 'src_ratings', COUNT(*) 
FROM DEV.src_ratings

UNION ALL

SELECT 'FACT LAYER', 'fct_ratings', COUNT(*) 
FROM DEV.fct_ratings

UNION ALL

SELECT 'FACT LAYER', 'fct_genome_score', COUNT(*) 
FROM DEV.fct_genome_score

UNION ALL

SELECT 'DIMENSION LAYER', 'dim_users', COUNT(*) 
FROM DEV.dim_users

UNION ALL

SELECT 'GOLD LAYER', 'movie_analysis', COUNT(*) 
FROM DEV.movie_analysis

UNION ALL

SELECT 'GOLD LAYER', 'genre_ratings', COUNT(*) 
FROM DEV.genre_ratings

UNION ALL

SELECT 'GOLD LAYER', 'user_engagement', COUNT(*) 
FROM DEV.user_engagement

UNION ALL

SELECT 'GOLD LAYER', 'tag_relevance', COUNT(*) 
FROM DEV.tag_relevance

ORDER BY layer, table_name;

-- Preview gold layer data
SELECT '=== MOVIE ANALYSIS ===' as section;
SELECT * FROM DEV.movie_analysis LIMIT 10;

SELECT '=== GENRE RATINGS ===' as section;
SELECT * FROM DEV.genre_ratings;

SELECT '=== USER ENGAGEMENT ===' as section;
SELECT * FROM DEV.user_engagement LIMIT 10;

SELECT '=== TAG RELEVANCE ===' as section;
SELECT * FROM DEV.tag_relevance LIMIT 10;

SELECT '=== TOP 10 BY GENRE ===' as section;
SELECT * FROM DEV.top10_by_genre LIMIT 20;
