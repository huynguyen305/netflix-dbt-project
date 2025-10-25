#!/bin/bash

# Netflix dbt Project - AWS S3 Setup Script
# This script creates an S3 bucket and uploads Netflix data files

set -e  # Exit on error

echo "================================================"
echo "Netflix dbt Project - AWS S3 Setup"
echo "================================================"
echo ""

# Configuration
BUCKET_NAME="netflix-dbt-data-$(date +%Y%m%d)"
REGION="us-east-1"
DATA_DIR="/home/huyng/netflix-dbt-project/netflix-dbt-project/data"
S3_PREFIX="raw-data"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Checking AWS CLI configuration...${NC}"
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${YELLOW}AWS not configured. Please run 'aws configure' first.${NC}"
    echo ""
    echo "You'll need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (suggested: us-east-1)"
    echo "  - Default output format (suggested: json)"
    echo ""
    read -p "Would you like to configure AWS now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws configure
    else
        echo "Exiting. Please run 'aws configure' and then run this script again."
        exit 1
    fi
fi

# Get AWS account info
echo -e "${GREEN}✓ AWS CLI configured${NC}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT"
echo ""

echo -e "${BLUE}Step 2: Creating S3 bucket: ${BUCKET_NAME}${NC}"
# Check if bucket already exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    # Create bucket
    if [ "$REGION" == "us-east-1" ]; then
        aws s3 mb "s3://${BUCKET_NAME}"
    else
        aws s3 mb "s3://${BUCKET_NAME}" --region "$REGION"
    fi
    echo -e "${GREEN}✓ Bucket created: ${BUCKET_NAME}${NC}"
else
    echo -e "${YELLOW}Bucket already exists or name conflict. Using existing bucket.${NC}"
fi
echo ""

echo -e "${BLUE}Step 3: Enabling versioning on bucket...${NC}"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"
echo ""

echo -e "${BLUE}Step 4: Setting bucket tags...${NC}"
aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging "TagSet=[{Key=Project,Value=netflix-dbt},{Key=Environment,Value=dev},{Key=ManagedBy,Value=script}]"
echo -e "${GREEN}✓ Tags applied${NC}"
echo ""

echo -e "${BLUE}Step 5: Uploading Netflix data files to S3...${NC}"
echo "Source: ${DATA_DIR}"
echo "Destination: s3://${BUCKET_NAME}/${S3_PREFIX}/"
echo ""

# Upload each file with progress
for file in "${DATA_DIR}"/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -n "Uploading ${filename}... "
        aws s3 cp "$file" "s3://${BUCKET_NAME}/${S3_PREFIX}/${filename}" --quiet
        echo -e "${GREEN}✓${NC}"
    fi
done
echo ""

echo -e "${BLUE}Step 6: Verifying uploaded files...${NC}"
aws s3 ls "s3://${BUCKET_NAME}/${S3_PREFIX}/" --human-readable
echo ""

echo -e "${BLUE}Step 7: Generating Snowflake integration commands...${NC}"
cat > /home/huyng/netflix-dbt-project/netflix-dbt-project/snowflake_setup.sql <<EOF
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
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::${AWS_ACCOUNT}:role/snowflake-s3-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://${BUCKET_NAME}/${S3_PREFIX}/');

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
  URL = 's3://${BUCKET_NAME}/${S3_PREFIX}/'
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
EOF

echo -e "${GREEN}✓ Snowflake setup SQL generated: snowflake_setup.sql${NC}"
echo ""

# Create AWS IAM policy document
cat > /home/huyng/netflix-dbt-project/netflix-dbt-project/aws_iam_policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

echo -e "${GREEN}✓ AWS IAM policy generated: aws_iam_policy.json${NC}"
echo ""

echo "================================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Next Steps:"
echo ""
echo "1. ${YELLOW}Set up AWS IAM Role for Snowflake:${NC}"
echo "   - Go to AWS IAM Console"
echo "   - Create a new role named 'snowflake-s3-role'"
echo "   - Use the policy in: aws_iam_policy.json"
echo "   - Note: You'll need the Snowflake IAM User ARN (from step 4 in Snowflake SQL)"
echo ""
echo "2. ${YELLOW}Run Snowflake Setup:${NC}"
echo "   - Open Snowflake SQL worksheet"
echo "   - Run commands from: snowflake_setup.sql"
echo "   - Complete the IAM role configuration"
echo ""
echo "3. ${YELLOW}Configure dbt:${NC}"
echo "   - Update ~/.dbt/profiles.yml with your Snowflake credentials"
echo "   - Run: cd netflix && dbt debug"
echo ""
echo "4. ${YELLOW}Run dbt project:${NC}"
echo "   - cd netflix"
echo "   - dbt deps"
echo "   - dbt seed"
echo "   - dbt run"
echo "   - dbt test"
echo ""
echo "================================================"
echo "S3 Bucket Details:"
echo "================================================"
echo "Bucket Name: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo "Data Location: s3://${BUCKET_NAME}/${S3_PREFIX}/"
echo "================================================"
echo ""
echo "Files uploaded:"
aws s3 ls "s3://${BUCKET_NAME}/${S3_PREFIX}/" --human-readable
echo ""
