#!/bin/bash
# Deploy script for AI Digital Twin (CloudFormation + Node.js)
# Usage: ./deploy.sh [environment]
# Example: ./deploy.sh dev

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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying AI Digital Twin${NC}"
echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}Stack: ${STACK_NAME}${NC}"
echo -e "${GREEN}Region: ${AWS_REGION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi

# Step 1: Build Backend Lambda Package
echo -e "\n${YELLOW}Step 1: Building backend Lambda package...${NC}"
cd "$PROJECT_ROOT/backend"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build Lambda package
echo "Building Lambda package..."
npm run build

# Create dist/data directory and copy data files
mkdir -p dist/data
cp -r data/* dist/data/

# Create zip file
cd dist
zip -r ../lambda-deployment.zip .
cd ..

LAMBDA_SIZE=$(ls -lh lambda-deployment.zip | awk '{print $5}')
echo -e "${GREEN}Lambda package created: lambda-deployment.zip ($LAMBDA_SIZE)${NC}"

# Step 2: Build Frontend
echo -e "\n${YELLOW}Step 2: Building frontend...${NC}"
cd "$PROJECT_ROOT/frontend"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build frontend
npm run build
echo -e "${GREEN}Frontend build complete${NC}"

# Step 3: Deploy CloudFormation Stack
echo -e "\n${YELLOW}Step 3: Deploying CloudFormation stack...${NC}"
cd "$PROJECT_ROOT"

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    echo "Creating new stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://cloudformation/main.yaml" \
        --parameters "file://cloudformation/parameters/${ENVIRONMENT}.json" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --tags Key=Environment,Value="$ENVIRONMENT" Key=Project,Value="$PROJECT_NAME"

    echo "Waiting for stack creation..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
else
    echo "Updating existing stack..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://cloudformation/main.yaml" \
        --parameters "file://cloudformation/parameters/${ENVIRONMENT}.json" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" 2>&1 || true

    echo "Waiting for stack update..."
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$AWS_REGION" 2>&1 || true
fi

echo -e "${GREEN}CloudFormation stack deployed${NC}"

# Step 4: Get Stack Outputs
echo -e "\n${YELLOW}Step 4: Getting stack outputs...${NC}"
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].Outputs')

FRONTEND_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FrontendBucketName") | .OutputValue')
LAMBDA_FUNCTION=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue')
CLOUDFRONT_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontUrl") | .OutputValue')
CLOUDFRONT_ID=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontDistributionId") | .OutputValue')
API_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiGatewayUrl") | .OutputValue')

echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "Lambda Function: $LAMBDA_FUNCTION"
echo "API Gateway URL: $API_URL"
echo "CloudFront URL: $CLOUDFRONT_URL"

# Step 5: Upload Lambda Code
echo -e "\n${YELLOW}Step 5: Uploading Lambda code...${NC}"
cd "$PROJECT_ROOT/backend"

aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION" \
    --zip-file "fileb://lambda-deployment.zip" \
    --region "$AWS_REGION"

echo -e "${GREEN}Lambda code uploaded${NC}"

# Step 6: Upload Frontend to S3
echo -e "\n${YELLOW}Step 6: Uploading frontend to S3...${NC}"
cd "$PROJECT_ROOT/frontend"

aws s3 sync out/ "s3://${FRONTEND_BUCKET}/" --delete --region "$AWS_REGION"

echo -e "${GREEN}Frontend uploaded to S3${NC}"

# Step 7: Invalidate CloudFront Cache
echo -e "\n${YELLOW}Step 7: Invalidating CloudFront cache...${NC}"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_ID" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

echo "Invalidation ID: $INVALIDATION_ID"
echo -e "${GREEN}CloudFront cache invalidation started${NC}"

# Done
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${GREEN}Your Digital Twin is live at:${NC}"
echo -e "${YELLOW}${CLOUDFRONT_URL}${NC}"
echo -e "\n${GREEN}API Endpoint:${NC}"
echo -e "${YELLOW}${API_URL}${NC}"
echo -e "\n${GREEN}Health Check:${NC}"
echo -e "${YELLOW}${API_URL}/health${NC}"
