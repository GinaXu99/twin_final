# AI Digital Twin - Setup Guide

This guide covers how to run the AI Digital Twin project locally and deploy it to AWS.

## Prerequisites

- Node.js 20.x or higher
- AWS CLI configured with credentials
- AWS account with Bedrock access enabled

---

## Local Development

### Prerequisites for Local Development

The backend calls AWS Bedrock directly, so you need:

1. **AWS credentials configured locally**:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, and region (us-east-1)
   ```

2. **Bedrock model access enabled** in your AWS account (see AWS Deployment Step 2)

The AWS SDK automatically reads credentials from `~/.aws/credentials` when running locally.

### 1. Backend Setup

```bash
cd week2-conversion/backend

# Install dependencies
npm install

# Create data files (customize with your information)
# Edit the files in backend/data/:
#   - facts.json    (your personal info)
#   - summary.txt   (background summary)
#   - style.txt     (communication style)
#   - me.txt        (detailed bio)
#   - linkedin.txt  (LinkedIn profile text)

# Run the backend server
npm run dev
```

The backend will start at `http://localhost:8000`.

**Available endpoints:**
- `GET /` - API info
- `GET /health` - Health check
- `POST /chat` - Send a message
- `GET /conversation/:sessionId` - Get conversation history

### 2. Frontend Setup

```bash
cd week2-conversion/frontend

# Install dependencies
npm install

# Create .env.local file
echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > .env.local

# Run the frontend dev server
npm run dev
```

The frontend will start at `http://localhost:3000`.

### 3. Test the Application

1. Open `http://localhost:3000` in your browser
2. Type a message in the chat input
3. The AI Digital Twin should respond

---

## AWS Deployment

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI (if not already done)
aws configure

# Verify credentials
aws sts get-caller-identity
```

### Step 2: Enable Bedrock Model Access

1. Go to AWS Console > Amazon Bedrock
2. Navigate to "Model access" in the left sidebar
3. Click "Manage model access"
4. Enable "Amazon Nova Lite" (or your preferred model)
5. Wait for access to be granted (usually instant)

### Step 3: Deploy Infrastructure with CloudFormation

```bash
cd week2-conversion

# Deploy to dev environment
./scripts/deploy.sh dev

# Or on Windows:
# .\scripts\deploy.ps1 -Environment dev
```

This creates:
- S3 bucket for conversation memory
- S3 bucket for frontend hosting
- Lambda function for the backend
- API Gateway HTTP API
- CloudFront distribution
- IAM roles and policies

### Step 4: Build and Deploy Backend

```bash
cd week2-conversion/backend

# Build the Lambda deployment package
npm run build:lambda

# Get the Lambda function name from CloudFormation outputs
FUNCTION_NAME=$(aws cloudformation describe-stacks \
  --stack-name ai-digital-twin-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
  --output text)

# Deploy to Lambda
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://lambda-deployment.zip
```

### Step 5: Build and Deploy Frontend

```bash
cd week2-conversion/frontend

# Get the API URL from CloudFormation outputs
API_URL=$(aws cloudformation describe-stacks \
  --stack-name ai-digital-twin-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

# Create production .env file
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

# Build the frontend
npm run build

# Get the frontend S3 bucket name
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ai-digital-twin-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

# Deploy to S3
aws s3 sync out/ s3://$FRONTEND_BUCKET --delete

# Get CloudFront distribution ID and invalidate cache
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name ai-digital-twin-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"
```

### Step 6: Access Your Deployed Application

```bash
# Get the CloudFront URL
aws cloudformation describe-stacks \
  --stack-name ai-digital-twin-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontUrl`].OutputValue' \
  --output text
```

Open the URL in your browser to access your deployed AI Digital Twin.

---

## Environment Variables

### Backend

| Variable | Description | Default |
|----------|-------------|---------|
| `CORS_ORIGINS` | Comma-separated allowed origins | `http://localhost:3000` |
| `DEFAULT_AWS_REGION` | AWS region | `us-east-1` |
| `BEDROCK_MODEL_ID` | Bedrock model to use | `amazon.nova-lite-v1:0` |
| `USE_S3` | Use S3 for memory storage | `false` |
| `S3_BUCKET` | S3 bucket for memory | (required if USE_S3=true) |
| `PORT` | Local server port | `8000` |

### Frontend

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | Backend API URL | `http://localhost:8000` |

---

## Bedrock Model Options

| Model ID | Description |
|----------|-------------|
| `amazon.nova-micro-v1:0` | Fastest, cheapest |
| `amazon.nova-lite-v1:0` | Balanced (default) |
| `amazon.nova-pro-v1:0` | Most capable |

To change the model, set the `BEDROCK_MODEL_ID` environment variable.

---

## Troubleshooting

### "Access denied to Bedrock model"
- Ensure you've enabled model access in the AWS Bedrock console
- Verify your IAM role has `bedrock:InvokeModel` permission

### "Cannot connect to backend"
- Check the backend is running: `curl http://localhost:8000/health`
- Verify `NEXT_PUBLIC_API_URL` is set correctly
- Check CORS origins include your frontend URL

### "Empty response from Bedrock"
- Check CloudWatch logs for the Lambda function
- Verify the model ID is correct
- Ensure conversation context isn't too long

### Local memory not persisting
- Memory is stored in `backend/memory/` directory by default
- Ensure the directory is writable

---

## Cleanup

To delete all AWS resources:

```bash
cd week2-conversion

# Destroy the stack
./scripts/destroy.sh dev

# Or on Windows:
# .\scripts\destroy.ps1 -Environment dev
```

Note: You may need to empty the S3 buckets first if they contain data.
