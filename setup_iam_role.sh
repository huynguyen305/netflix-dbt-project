#!/bin/bash

# Script to create IAM role for Snowflake S3 access
# Run this after getting the STORAGE_AWS_IAM_USER_ARN from Snowflake

set -e

echo "================================================"
echo "Snowflake IAM Role Setup"
echo "================================================"
echo ""

# Configuration
ROLE_NAME="snowflake-s3-role"
BUCKET_NAME="netflix-dbt-data-20251025"
POLICY_NAME="snowflake-s3-policy"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}IMPORTANT: Before running this script, you need:${NC}"
echo "1. Run this in Snowflake: DESC STORAGE INTEGRATION s3_netflix_integration;"
echo "2. Copy the STORAGE_AWS_IAM_USER_ARN (e.g., arn:aws:iam::310373698391:user/jk6a1000-s)"
echo "3. Copy the STORAGE_AWS_EXTERNAL_ID"
echo ""

# Prompt for Snowflake values
read -p "Enter STORAGE_AWS_IAM_USER_ARN from Snowflake: " SNOWFLAKE_USER_ARN
read -p "Enter STORAGE_AWS_EXTERNAL_ID from Snowflake: " EXTERNAL_ID

if [ -z "$SNOWFLAKE_USER_ARN" ] || [ -z "$EXTERNAL_ID" ]; then
    echo -e "${RED}Error: Both values are required!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Creating IAM trust policy...${NC}"

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${SNOWFLAKE_USER_ARN}"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF

echo -e "${GREEN}✓ Trust policy created${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating/Updating IAM role...${NC}"

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "Role exists, updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document file:///tmp/trust-policy.json
else
    echo "Creating new role..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for Snowflake to access Netflix S3 data"
fi

echo -e "${GREEN}✓ IAM role configured${NC}"
echo ""

echo -e "${BLUE}Step 3: Attaching S3 access policy...${NC}"

# Create S3 access policy
cat > /tmp/s3-policy.json <<EOF
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

# Check if policy exists
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    echo "Creating new policy..."
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/s3-policy.json \
        --query 'Policy.Arn' \
        --output text)
else
    echo "Policy exists, creating new version..."
    # Delete old versions if at limit
    aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document file:///tmp/s3-policy.json \
        --set-as-default 2>/dev/null || {
        echo "Updating existing policy..."
        # Get old versions and delete non-default ones
        OLD_VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?!IsDefaultVersion].VersionId' --output text)
        for version in $OLD_VERSIONS; do
            aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$version"
        done
        aws iam create-policy-version \
            --policy-arn "$POLICY_ARN" \
            --policy-document file:///tmp/s3-policy.json \
            --set-as-default
    }
fi

# Attach policy to role
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

echo -e "${GREEN}✓ Policy attached to role${NC}"
echo ""

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo "================================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Role ARN: ${ROLE_ARN}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Go back to Snowflake"
echo "2. Run: LIST @s3_netflix_stage;"
echo "3. If successful, continue with the COPY INTO commands"
echo ""
echo "If you still get errors, wait 30-60 seconds for AWS IAM changes to propagate."
echo ""

# Cleanup
rm /tmp/trust-policy.json /tmp/s3-policy.json

echo -e "${GREEN}✓ Temporary files cleaned up${NC}"
