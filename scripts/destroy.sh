#!/bin/bash
# Destroy script for AI Digital Twin infrastructure
# Usage: ./destroy.sh [environment]
# Example: ./destroy.sh dev

set -e

# Configuration
ENVIRONMENT="${1:-dev}"
PROJECT_NAME="twin"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}DESTROYING AI Digital Twin${NC}"
echo -e "${RED}Environment: ${ENVIRONMENT}${NC}"
echo -e "${RED}Stack: ${STACK_NAME}${NC}"
echo -e "${RED}Region: ${AWS_REGION}${NC}"
echo -e "${RED}========================================${NC}"

# Confirmation
read -p "Are you sure you want to destroy the ${ENVIRONMENT} environment? (type 'yes' to confirm): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    echo -e "${YELLOW}Stack ${STACK_NAME} does not exist.${NC}"
    exit 0
fi

# Get S3 bucket names before deletion
echo -e "\n${YELLOW}Getting S3 bucket names...${NC}"
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].Outputs')
FRONTEND_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FrontendBucketName") | .OutputValue')
MEMORY_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="MemoryBucketName") | .OutputValue')

# Empty S3 buckets (required before CloudFormation can delete them)
echo -e "\n${YELLOW}Emptying S3 buckets...${NC}"

if [ -n "$FRONTEND_BUCKET" ] && [ "$FRONTEND_BUCKET" != "null" ]; then
    echo "Emptying frontend bucket: $FRONTEND_BUCKET"
    aws s3 rm "s3://${FRONTEND_BUCKET}" --recursive --region "$AWS_REGION" 2>&1 || true
fi

if [ -n "$MEMORY_BUCKET" ] && [ "$MEMORY_BUCKET" != "null" ]; then
    echo "Emptying memory bucket: $MEMORY_BUCKET"
    # Delete all versions for versioned bucket
    aws s3api list-object-versions --bucket "$MEMORY_BUCKET" --region "$AWS_REGION" \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null | \
        jq -c 'select(.Objects != null) | .Objects[]' | while read obj; do
            KEY=$(echo "$obj" | jq -r '.Key')
            VERSION=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$MEMORY_BUCKET" --key "$KEY" --version-id "$VERSION" --region "$AWS_REGION" 2>&1 || true
        done

    # Delete delete markers
    aws s3api list-object-versions --bucket "$MEMORY_BUCKET" --region "$AWS_REGION" \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null | \
        jq -c 'select(.Objects != null) | .Objects[]' | while read obj; do
            KEY=$(echo "$obj" | jq -r '.Key')
            VERSION=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$MEMORY_BUCKET" --key "$KEY" --version-id "$VERSION" --region "$AWS_REGION" 2>&1 || true
        done
fi

echo -e "${GREEN}S3 buckets emptied${NC}"

# Delete CloudFormation stack
echo -e "\n${YELLOW}Deleting CloudFormation stack...${NC}"
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"

echo "Waiting for stack deletion (this may take 5-10 minutes)..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Destruction Complete!${NC}"
echo -e "${GREEN}Stack ${STACK_NAME} has been deleted.${NC}"
echo -e "${GREEN}========================================${NC}"
