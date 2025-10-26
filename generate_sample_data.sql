-- Generate Sample Rating Data for Testing
-- Run this in Snowflake to populate the gold layer with data

USE DATABASE MOVIELENS;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- Generate sample ratings for existing movies
-- This creates ratings for the first 100 movies from 20 different users
INSERT INTO RAW_RATINGS (userId, movieId, rating, timestamp)
SELECT 
    (UNIFORM(1, 20, RANDOM()))::INT as userId,  -- 20 random users
    m.movieId,
    (UNIFORM(1, 5, RANDOM()) + UNIFORM(0, 1, RANDOM()))::DECIMAL(2,1) as rating,  -- Ratings between 1.0-5.0
    DATEDIFF(second, '1970-01-01', DATEADD(day, -UNIFORM(1, 365, RANDOM()), CURRENT_TIMESTAMP()))::BIGINT as timestamp
FROM 
    (SELECT DISTINCT movieId FROM RAW_MOVIES LIMIT 100) m
CROSS JOIN 
    (SELECT SEQ4() as seq FROM TABLE(GENERATOR(ROWCOUNT => 5))) g  -- 5 ratings per movie
WHERE m.movieId IS NOT NULL;

-- Verify the data
SELECT COUNT(*) as total_ratings FROM RAW_RATINGS;
SELECT COUNT(DISTINCT userId) as unique_users FROM RAW_RATINGS;
SELECT COUNT(DISTINCT movieId) as movies_rated FROM RAW_RATINGS;

-- Preview sample data
SELECT * FROM RAW_RATINGS LIMIT 10;

-- Optional: Generate genome scores as well
INSERT INTO RAW_GENOME_SCORES (movieId, tagId, relevance)
SELECT 
    m.movieId,
    t.tagId,
    (UNIFORM(0, 100, RANDOM()) / 100.0)::DECIMAL(4,3) as relevance
FROM 
    (SELECT DISTINCT movieId FROM RAW_MOVIES LIMIT 50) m
CROSS JOIN 
    (SELECT tagId FROM RAW_GENOME_TAGS LIMIT 20) t
WHERE m.movieId IS NOT NULL 
  AND t.tagId IS NOT NULL;

-- Verify genome scores
SELECT COUNT(*) as total_scores FROM RAW_GENOME_SCORES;
