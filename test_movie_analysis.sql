-- Test movie_analysis view
USE DATABASE MOVIELENS;
USE WAREHOUSE COMPUTE_WH;

-- Check if view exists and has data
SELECT COUNT(*) as total_movies 
FROM DEV.movie_analysis;

-- Preview the data
SELECT * 
FROM DEV.movie_analysis 
LIMIT 10;

-- Check the view definition
SHOW VIEWS LIKE 'MOVIE_ANALYSIS' IN SCHEMA DEV;

-- Get detailed info
SELECT 
    movie_title,
    ROUND(average_rating, 2) as avg_rating,
    total_ratings
FROM DEV.movie_analysis
ORDER BY average_rating DESC
LIMIT 20;
