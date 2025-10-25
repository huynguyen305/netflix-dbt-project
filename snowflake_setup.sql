-- Snowflake Setup Commands for Netflix dbt Project
-- Run these commands in your Snowflake worksheet

-- 1. Create database and schemas
CREATE DATABASE IF NOT EXISTS MOVIELENS;
USE DATABASE MOVIELENS;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS DEV;
CREATE SCHEMA IF NOT EXISTS SNAPSHOTS;

-- 2. Create warehouse
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
WITH WAREHOUSE_SIZE = 'X-SMALL' 
AUTO_SUSPEND = 300 
AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;

-- 3. Create storage integration for S3
CREATE OR REPLACE STORAGE INTEGRATION s3_netflix_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::046394857189:role/snowflake-s3-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://netflix-dbt-data-20251025/raw-data/');

-- 4. Get the AWS IAM User for Snowflake (IMPORTANT - Run this and note the output)
DESC STORAGE INTEGRATION s3_netflix_integration;
-- Copy the STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID values

-- 5. Create file format for CSV files
CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
  ESCAPE = 'NONE'
  ESCAPE_UNENCLOSED_FIELD = 'NONE'
  NULL_IF = ('NULL', 'null', '');

-- 6. Create external stage
CREATE OR REPLACE STAGE s3_netflix_stage
  STORAGE_INTEGRATION = s3_netflix_integration
  URL = 's3://netflix-dbt-data-20251025/raw-data/'
  FILE_FORMAT = csv_format;

-- 7. Test the stage
LIST @s3_netflix_stage;

-- 8. Create raw tables
CREATE OR REPLACE TABLE RAW.RAW_MOVIES (
    movieId INT,
    title STRING,
    genres STRING
);

CREATE OR REPLACE TABLE RAW.RAW_TAGS (
    userId INT,
    movieId INT,
    tag STRING,
    timestamp BIGINT
);

CREATE OR REPLACE TABLE RAW.RAW_LINKS (
    movieId INT,
    imdbId STRING,
    tmdbId STRING
);

CREATE OR REPLACE TABLE RAW.RAW_GENOME_TAGS (
    tagId INT,
    tag STRING
);

-- Note: You may need to create RAW_RATINGS and RAW_GENOME_SCORES tables
-- based on your data files if they exist

-- 9. Load data from S3 to Snowflake
COPY INTO RAW.RAW_MOVIES
FROM @s3_netflix_stage/movies.csv
FILE_FORMAT = csv_format
ON_ERROR = 'CONTINUE';

COPY INTO RAW.RAW_TAGS
FROM @s3_netflix_stage/tags.csv
FILE_FORMAT = csv_format
ON_ERROR = 'CONTINUE';

COPY INTO RAW.RAW_LINKS
FROM @s3_netflix_stage/links.csv
FILE_FORMAT = csv_format
ON_ERROR = 'CONTINUE';

COPY INTO RAW.RAW_GENOME_TAGS
FROM @s3_netflix_stage/genome-tags.csv
FILE_FORMAT = csv_format
ON_ERROR = 'CONTINUE';

-- 10. Verify loaded data
SELECT COUNT(*) as movie_count FROM RAW.RAW_MOVIES;
SELECT COUNT(*) as tag_count FROM RAW.RAW_TAGS;
SELECT COUNT(*) as link_count FROM RAW.RAW_LINKS;
SELECT COUNT(*) as genome_tag_count FROM RAW.RAW_GENOME_TAGS;

-- Done! Your raw data is now loaded in Snowflake
