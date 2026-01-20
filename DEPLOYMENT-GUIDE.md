# AWS CloudFormation + GitHub Actions Deployment Guide

This guide explains line-by-line how the deployment system works and how all the pieces connect together.

---

## Overview: How It All Connects

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT FLOW                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    Push to main    ┌──────────────────────┐          │
│  │   GitHub     │ ──────────────────►│  GitHub Actions      │          │
│  │   Repository │                    │  (deploy.yml)        │          │
│  └──────────────┘                    └──────────┬───────────┘          │
│                                                 │                       │
│                                    Uses OIDC to assume                  │
│                                    IAM role (no secrets!)               │
│                                                 │                       │
│                                                 ▼                       │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         AWS CLOUD                                 │  │
│  │                                                                   │  │
│  │  ┌─────────────────┐     Creates/Updates    ┌─────────────────┐  │  │
│  │  │ CloudFormation  │ ◄───────────────────── │ GitHub Actions  │  │  │
│  │  │ (main.yaml)     │                        │ IAM Role        │  │  │
│  │  └────────┬────────┘                        └─────────────────┘  │  │
│  │           │                                                       │  │
│  │           │ Creates these resources:                              │  │
│  │           ▼                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │ S3 Buckets  │  │   Lambda    │  │ API Gateway │              │  │
│  │  │ (Frontend + │  │  Function   │  │  HTTP API   │              │  │
│  │  │  Memory)    │  │             │  │             │              │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │  │
│  │                                                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐                                │  │
│  │  │ CloudFront  │  │  IAM Roles  │                                │  │
│  │  │    CDN      │  │             │                                │  │
│  │  └─────────────┘  └─────────────┘                                │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Two Ways to Deploy (Pick One)

You have **two independent options** - they do the same thing, pick whichever fits your workflow:

```
┌─────────────────────────────────────────────────────────────────┐
│                    TWO WAYS TO DEPLOY                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  OPTION A: Local (deploy.sh)         OPTION B: GitHub Actions   │
│  ─────────────────────────           ───────────────────────── │
│                                                                 │
│  Your Machine                        Your Machine               │
│       │                                   │                     │
│       ▼                                   ▼                     │
│  ./scripts/deploy.sh                 git push origin main       │
│       │                                   │                     │
│       ▼                                   ▼                     │
│  AWS (direct)                        GitHub                     │
│                                           │                     │
│                                           ▼                     │
│                                      deploy.yml runs            │
│                                           │                     │
│                                           ▼                     │
│                                      AWS                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Option A: Local Deployment (deploy.sh)

**No GitHub needed.** Run directly from your machine.

#### Step 1: Install Prerequisites

```bash
# Check if AWS CLI is installed
aws --version
# If not: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Check if Node.js is installed (need v20+)
node --version
# If not: https://nodejs.org/
```

#### Step 2: Configure AWS Credentials

```bash
aws configure
```

It will prompt for:
```
AWS Access Key ID: AKIA...............
AWS Secret Access Key: xxxxxxxxxxxxxxxxxxxxxxxx
Default region name: us-east-1
Default output format: json
```

**Where to get these keys:**
1. Go to AWS Console → IAM → Users → Your User
2. Click **Security credentials** tab
3. Click **Create access key**
4. Copy the Access Key ID and Secret Access Key

**Verify credentials work:**
```bash
aws sts get-caller-identity
```
Should return your account ID and user ARN:
```json
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

#### Step 3: Required AWS Permissions

Your AWS user needs these permissions:

| Service | Why |
|---------|-----|
| CloudFormation | Create/update infrastructure stacks |
| S3 | Create buckets, upload frontend files |
| Lambda | Create/update serverless functions |
| API Gateway | Create HTTP APIs |
| CloudFront | Create CDN distribution |
| IAM | Create roles for Lambda |
| Bedrock | Invoke AI models |

**Quick option for testing:** Attach `AdministratorAccess` policy to your IAM user.

**For production:** Create a custom policy with only the required permissions.

#### Step 4: Run the Deployment

```bash
# IMPORTANT: Start from week2-conversion folder (not root production-main)
cd /Users/gina/Downloads/production-main/week2-conversion

# Run the deploy script
./scripts/deploy.sh dev      # Deploy to dev environment
./scripts/deploy.sh prod     # Deploy to prod environment
```

#### Quick Command Summary

| Step | Command | Expected Output |
|------|---------|-----------------|
| Check AWS CLI | `aws --version` | `aws-cli/2.x.x ...` |
| Check Node.js | `node --version` | `v20.x.x` |
| Configure AWS | `aws configure` | Prompts for keys |
| Verify credentials | `aws sts get-caller-identity` | Shows account info |
| Go to project | `cd week2-conversion` | - |
| Deploy | `./scripts/deploy.sh dev` | Deployment output |

**When to use local deployment:**
- Quick testing during development
- You don't have GitHub set up yet
- One-off deployments

---

### Option B: GitHub Actions (deploy.yml)

**Automatic deployment** when you push code.

**First-time setup required:**
1. Push your code to GitHub repository
2. Deploy the OIDC stack to AWS (one-time, from terminal)
3. Add `AWS_ROLE_ARN` secret in GitHub UI (one-time)

**After setup, just push:**
```bash
git add .
git commit -m "Update feature"
git push origin main          # deploy.yml runs automatically!
```

**When to use:**
- Team workflows (everyone pushes, auto-deploys)
- CI/CD pipelines
- You want deployment history in GitHub

---

### Which runs first?

They're **alternatives, not a sequence**. Pick one:

| Scenario | What runs |
|----------|-----------|
| You run `./scripts/deploy.sh` | Only `deploy.sh` (local) |
| You push to GitHub | Only `deploy.yml` (GitHub Actions) |

`deploy.yml` is basically `deploy.sh` translated to GitHub Actions syntax - they do the same thing.

**Recommendation:** Start with `deploy.sh` locally to test everything works, then set up GitHub Actions for automated deployments.

---

## File 1: `cloudformation/main.yaml` - Infrastructure Template

This file defines ALL your AWS resources as code. CloudFormation reads this and creates the resources.

### Parameters Section (Lines 4-36)

```yaml
Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - test
      - prod
```

**What it does:** Defines input variables that customize the deployment.

| Parameter | Purpose |
|-----------|---------|
| `Environment` | Which environment (dev/test/prod) - affects resource naming |
| `ProjectName` | Base name for all resources (default: "twin") |
| `BedrockModelId` | Which AI model to use |
| `LambdaMemory` | How much RAM for Lambda (128-3008 MB) |
| `LambdaTimeout` | Max execution time (1-900 seconds) |

**How it connects:** These values come from `parameters/dev.json`, `parameters/test.json`, or `parameters/prod.json` when you deploy.

---

### S3 Buckets (Lines 38-87)

#### Frontend Bucket
```yaml
FrontendBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketName: !Sub '${ProjectName}-${Environment}-frontend-${AWS::AccountId}'
    WebsiteConfiguration:
      IndexDocument: index.html
      ErrorDocument: 404.html
```

**Line-by-line:**
- `Type: AWS::S3::Bucket` - Creates an S3 bucket
- `BucketName: !Sub '...'` - `!Sub` substitutes variables. Result: `twin-dev-frontend-123456789012`
- `WebsiteConfiguration` - Enables static website hosting
- `IndexDocument: index.html` - Default page when visiting the site
- `PublicAccessBlockConfiguration: false` - Allows public read access (needed for website)

#### Frontend Bucket Policy (Lines 63-74)
```yaml
FrontendBucketPolicy:
  Type: AWS::S3::BucketPolicy
  Properties:
    PolicyDocument:
      Statement:
        - Effect: Allow
          Principal: '*'
          Action: s3:GetObject
          Resource: !Sub '${FrontendBucket.Arn}/*'
```

**What it does:** Allows anyone (`Principal: '*'`) to read files (`s3:GetObject`) from the bucket.

**Why needed:** Without this, visitors couldn't load your website files.

#### Memory Bucket (Lines 76-87)
```yaml
MemoryBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketName: !Sub '${ProjectName}-${Environment}-memory-${AWS::AccountId}'
    VersioningConfiguration:
      Status: Enabled
```

**What it does:** Stores conversation history for the AI.

**Why versioning:** `Status: Enabled` keeps history of all file changes - you can recover deleted conversations.

---

### IAM Role for Lambda (Lines 89-126)

```yaml
LambdaExecutionRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Service: lambda.amazonaws.com
          Action: sts:AssumeRole
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      - arn:aws:iam::aws:policy/AmazonBedrockFullAccess
    Policies:
      - PolicyName: S3MemoryAccess
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:DeleteObject
                - s3:ListBucket
              Resource:
                - !GetAtt MemoryBucket.Arn
                - !Sub '${MemoryBucket.Arn}/*'
```

**Line-by-line:**
- `AssumeRolePolicyDocument` - Defines WHO can use this role
  - `Service: lambda.amazonaws.com` - Only Lambda can assume this role
- `ManagedPolicyArns` - Pre-built AWS policies attached:
  - `AWSLambdaBasicExecutionRole` - Allows Lambda to write logs
  - `AmazonBedrockFullAccess` - Allows calling AI models
- `Policies` - Custom policy for S3 access:
  - `s3:GetObject/PutObject/DeleteObject` - Read, write, delete conversations
  - Only to the Memory bucket (principle of least privilege)

**How it connects:** Lambda function references this role via `Role: !GetAtt LambdaExecutionRole.Arn`

---

### Lambda Function (Lines 128-160)

```yaml
LambdaFunction:
  Type: AWS::Lambda::Function
  Properties:
    FunctionName: !Sub '${ProjectName}-${Environment}-api'
    Runtime: nodejs20.x
    Handler: index.handler
    Role: !GetAtt LambdaExecutionRole.Arn
    MemorySize: !Ref LambdaMemory
    Timeout: !Ref LambdaTimeout
    Environment:
      Variables:
        DEFAULT_AWS_REGION: !Ref AWS::Region
        BEDROCK_MODEL_ID: !Ref BedrockModelId
        USE_S3: 'true'
        S3_BUCKET: !Ref MemoryBucket
        CORS_ORIGINS: !Sub 'https://${CloudFrontDistribution.DomainName}'
    Code:
      ZipFile: |
        exports.handler = async (event) => {
          return { statusCode: 200, body: '{"message": "Placeholder"}' };
        };
```

**Line-by-line:**
- `Runtime: nodejs20.x` - Uses Node.js 20
- `Handler: index.handler` - Entry point: `handler` function in `index.js`
- `Role: !GetAtt LambdaExecutionRole.Arn` - Uses the IAM role we created above
- `MemorySize/Timeout` - References parameters (512MB/30s for dev)
- `Environment.Variables` - Environment variables available in your code:
  - `CORS_ORIGINS` - Automatically set to CloudFront URL (circular reference - CloudFormation handles this!)
- `Code.ZipFile` - **Placeholder code** - Gets replaced by deploy script with real code

**Why placeholder?** CloudFormation needs SOMETHING to create the function. The deploy script uploads the real code after.

---

### Lambda Permission (Lines 162-169)

```yaml
LambdaPermission:
  Type: AWS::Lambda::Permission
  Properties:
    FunctionName: !Ref LambdaFunction
    Action: lambda:InvokeFunction
    Principal: apigateway.amazonaws.com
    SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${HttpApi}/*'
```

**What it does:** Grants API Gateway permission to invoke the Lambda function.

**Why needed:** Without this, API Gateway would get "Access Denied" when trying to call Lambda.

---

### API Gateway (Lines 171-255)

#### HTTP API
```yaml
HttpApi:
  Type: AWS::ApiGatewayV2::Api
  Properties:
    Name: !Sub '${ProjectName}-${Environment}-api'
    ProtocolType: HTTP
    CorsConfiguration:
      AllowOrigins:
        - !Sub 'https://${CloudFrontDistribution.DomainName}'
      AllowMethods:
        - GET
        - POST
        - OPTIONS
```

**What it does:** Creates the API endpoint that receives HTTP requests.

**CORS Configuration:** Allows requests from your CloudFront domain (prevents other websites from calling your API).

#### Lambda Integration (Lines 194-201)
```yaml
HttpApiIntegration:
  Type: AWS::ApiGatewayV2::Integration
  Properties:
    ApiId: !Ref HttpApi
    IntegrationType: AWS_PROXY
    IntegrationUri: !GetAtt LambdaFunction.Arn
    PayloadFormatVersion: '2.0'
```

**What it does:** Connects API Gateway to Lambda.

- `AWS_PROXY` - Passes the full HTTP request to Lambda, Lambda returns full HTTP response
- `PayloadFormatVersion: '2.0'` - Modern format with simpler event structure

#### Routes (Lines 203-244)
```yaml
RouteHealth:
  Type: AWS::ApiGatewayV2::Route
  Properties:
    ApiId: !Ref HttpApi
    RouteKey: 'GET /health'
    Target: !Sub 'integrations/${HttpApiIntegration}'
```

**What it does:** Maps URL paths to the Lambda integration.

| Route | Purpose |
|-------|---------|
| `GET /` | Root endpoint |
| `GET /health` | Health check |
| `POST /chat` | Send chat messages |
| `GET /conversation/{sessionId}` | Get conversation history |
| `OPTIONS /{proxy+}` | CORS preflight requests |
| `ANY /{proxy+}` | Catch-all for any other requests |

---

### CloudFront Distribution (Lines 257-305)

```yaml
CloudFrontDistribution:
  Type: AWS::CloudFront::Distribution
  Properties:
    DistributionConfig:
      Enabled: true
      DefaultRootObject: index.html
      PriceClass: PriceClass_100
      Origins:
        - Id: S3Origin
          DomainName: !Sub '${FrontendBucket}.s3-website-${AWS::Region}.amazonaws.com'
          CustomOriginConfig:
            OriginProtocolPolicy: http-only
      DefaultCacheBehavior:
        TargetOriginId: S3Origin
        ViewerProtocolPolicy: redirect-to-https
        CachePolicyId: 658327ea-f89d-4fab-a63d-7e88639e58f6
      CustomErrorResponses:
        - ErrorCode: 404
          ResponseCode: 200
          ResponsePagePath: /index.html
```

**Line-by-line:**
- `PriceClass_100` - Only edge locations in North America/Europe (cheapest option)
- `Origins` - Where CloudFront gets content from (your S3 bucket)
- `ViewerProtocolPolicy: redirect-to-https` - Forces HTTPS
- `CachePolicyId: 658327...` - AWS managed "CachingOptimized" policy
- `CustomErrorResponses` - **SPA routing fix**: When S3 returns 404 (page not found), serve `index.html` instead. This lets client-side routing work.

**Why CloudFront?**
1. HTTPS support
2. Global CDN (faster for users worldwide)
3. Caching
4. DDoS protection

---

### Outputs Section (Lines 307-352)

```yaml
Outputs:
  FrontendBucketName:
    Value: !Ref FrontendBucket
    Export:
      Name: !Sub '${ProjectName}-${Environment}-frontend-bucket'
```

**What it does:** Exports values for use by other stacks or scripts.

**How it connects:** The deploy script reads these outputs to know:
- Which S3 bucket to upload frontend files to
- Which Lambda function to update
- What the CloudFront URL is

---

## File 2: `cloudformation/github-oidc.yaml` - GitHub Authentication

This template sets up secure authentication between GitHub Actions and AWS (no stored credentials!).

### OIDC Provider (Lines 18-34)

```yaml
GitHubOIDCProvider:
  Type: AWS::IAM::OIDCProvider
  Properties:
    Url: https://token.actions.githubusercontent.com
    ClientIdList:
      - sts.amazonaws.com
    ThumbprintList:
      - 6938fd4d98bab03faadb97b34396831e3780aea1
```

**What it does:** Tells AWS to trust identity tokens from GitHub.

**How OIDC works:**
1. GitHub Actions runs and gets a token from GitHub
2. Token says "I am repo X running on branch Y"
3. AWS verifies the token signature matches GitHub's thumbprint
4. AWS grants temporary credentials

**Why better than secrets?** No long-lived credentials to leak or rotate!

### GitHub Actions IAM Role (Lines 40-92)

```yaml
GitHubActionsRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Federated: !Ref GitHubOIDCProvider
          Action: sts:AssumeRoleWithWebIdentity
          Condition:
            StringEquals:
              token.actions.githubusercontent.com:aud: sts.amazonaws.com
            StringLike:
              token.actions.githubusercontent.com:sub: !Sub 'repo:${GitHubOrg}/${GitHubRepo}:*'
```

**Security conditions:**
- `StringEquals: aud: sts.amazonaws.com` - Token must be intended for AWS
- `StringLike: sub: repo:your-org/your-repo:*` - Only YOUR repo can assume this role

**Attached permissions:** Full access to Lambda, S3, API Gateway, CloudFront, Bedrock, DynamoDB, CloudFormation, and IAM (scoped to project roles).

---

## File 3: `scripts/deploy.sh` - Local Deployment Script

Run this to deploy from your local machine.

### Configuration (Lines 1-18)

```bash
#!/bin/bash
set -e  # Exit immediately if any command fails

ENVIRONMENT="${1:-dev}"          # First argument, defaults to "dev"
PROJECT_NAME="twin"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"  # e.g., "twin-dev"
AWS_REGION="${AWS_REGION:-us-east-1}"        # Use env var or default
```

**What `set -e` does:** If any command fails, the script stops. Prevents partial deployments.

### Step 1: Build Backend (Lines 43-67)

```bash
cd "$PROJECT_ROOT/backend"

if [ ! -d "node_modules" ]; then
    npm install
fi

npm run build

mkdir -p dist/data
cp -r data/* dist/data/

cd dist
zip -r ../lambda-deployment.zip .
```

**Line-by-line breakdown:**

```bash
npm run build
```
- Runs the build script defined in `package.json`
- Uses **esbuild** to compile TypeScript (`.ts`) → JavaScript (`.js`)
- Bundles all code into a single file for Lambda
- Output goes to `dist/` folder
- Excludes AWS SDK (Lambda provides it, reduces bundle size)

```bash
mkdir -p dist/data
cp -r data/* dist/data/
```
- `mkdir -p` - Creates `dist/data/` directory (`-p` = no error if exists, create parents)
- `cp -r` - Recursively copies everything from `data/` to `dist/data/`
- **Why?** The `data/` folder contains AI persona files (personality, knowledge base). Lambda needs these at runtime but esbuild doesn't bundle non-JS files automatically.

```bash
cd dist
zip -r ../lambda-deployment.zip .
```
- `cd dist` - Move into the dist folder
- `zip -r` - Recursively zip (`-r` = include subdirectories)
- `../lambda-deployment.zip` - Create zip one level up (in `backend/`)
- `.` - Zip everything in current directory (dist/)
- **Result:** A flat zip where `index.js` is at the root (Lambda requirement - handler must be at top level)

**Directory structure before zip:**
```
backend/
├── dist/
│   ├── index.js        ← Compiled Lambda handler
│   └── data/
│       └── persona.json
└── lambda-deployment.zip  ← Created here
```

**Inside the zip:**
```
lambda-deployment.zip
├── index.js            ← At root level (required!)
└── data/
    └── persona.json
```

### Step 2: Build Frontend (Lines 69-81)

```bash
cd "$PROJECT_ROOT/frontend"
npm install
npm run build
```

**Line-by-line breakdown:**

```bash
npm install
```
- Downloads all dependencies from `package.json`
- Creates `node_modules/` folder with React, Next.js, etc.

```bash
npm run build
```
- Runs Next.js build process
- Compiles React components → optimized HTML/CSS/JS
- **Static Export:** Configured for `output: 'export'` in `next.config.js`
- Output goes to `out/` folder (not `.next/`)

**Why static export?**
- Regular Next.js needs a Node.js server
- Static export = pure HTML/CSS/JS files
- Can be hosted on S3 + CloudFront (no server needed, cheaper)

**Directory structure after build:**
```
frontend/
└── out/
    ├── index.html       ← Main page
    ├── 404.html         ← Error page
    ├── _next/
    │   ├── static/
    │   │   ├── css/     ← Stylesheets
    │   │   └── chunks/  ← JavaScript bundles
    │   └── data/        ← Pre-rendered data
    └── [other pages].html
```

**What gets uploaded to S3:** Everything in `out/` → serves your website.

### Step 3: Deploy CloudFormation (Lines 83-115)

```bash
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://cloudformation/main.yaml" \
        --parameters "file://cloudformation/parameters/${ENVIRONMENT}.json" \
        --capabilities CAPABILITY_NAMED_IAM

    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
else
    aws cloudformation update-stack ...
    aws cloudformation wait stack-update-complete ...
fi
```

**What happens:**
1. Check if stack exists
2. If new: `create-stack`, if existing: `update-stack`
3. `--template-body file://...` - Points to main.yaml
4. `--parameters file://...` - Points to dev.json/test.json/prod.json
5. `--capabilities CAPABILITY_NAMED_IAM` - Required because template creates IAM roles
6. `wait stack-...-complete` - Blocks until CloudFormation finishes

### Step 4: Get Outputs (Lines 117-130)

```bash
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs')

FRONTEND_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FrontendBucketName") | .OutputValue')
LAMBDA_FUNCTION=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue')
```

**What happens:** Retrieves the values CloudFormation exported (bucket names, function names, URLs).

### Step 5: Upload Lambda Code (Lines 132-141)

```bash
aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION" \
    --zip-file "fileb://lambda-deployment.zip"
```

**What happens:** Replaces the placeholder code with your actual backend code.

**Note:** `fileb://` means "file, binary mode" - required for zip files.

### Step 6: Upload Frontend (Lines 143-149)

```bash
aws s3 sync out/ "s3://${FRONTEND_BUCKET}/" --delete
```

**What happens:**
- `sync` - Only uploads changed files
- `--delete` - Removes files from S3 that don't exist locally

### Step 7: Invalidate CloudFront (Lines 151-160)

```bash
aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_ID" \
    --paths "/*"
```

**What happens:** Tells CloudFront to fetch fresh files from S3.

**Why needed:** CloudFront caches files for performance. Without invalidation, users might see old files.

---

## File 4: `.github/workflows/deploy.yml` - CI/CD Pipeline

Automates deployment when you push code.

### Triggers (Lines 1-17)

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options:
          - dev
          - test
          - prod
```

**What happens:**
- `push: branches: main` - Auto-deploy when code is pushed to main
- `workflow_dispatch` - Manual trigger from GitHub UI with environment dropdown

### Permissions (Lines 23-25)

```yaml
permissions:
  id-token: write   # Required for OIDC authentication
  contents: read    # Required to checkout code
```

**Why `id-token: write`?** GitHub needs to create an identity token to send to AWS.

### AWS Credentials (Lines 37-41)

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

**What happens:**
1. GitHub generates OIDC token
2. AWS validates token
3. AWS returns temporary credentials
4. Credentials set as environment variables for subsequent steps

**`secrets.AWS_ROLE_ARN`:** The role ARN from `github-oidc.yaml` output, stored in GitHub repository secrets.

### Build Steps (Lines 52-70)

```yaml
- name: Build backend
  working-directory: backend
  run: |
    npm run build
    mkdir -p dist/data
    cp -r data/* dist/data/
    cd dist && zip -r ../lambda-deployment.zip .
```

Same as local script, but in GitHub Actions syntax.

### Deploy CloudFormation (Lines 79-103)

Same logic as local script - check if stack exists, create or update.

### Get Outputs & Deploy Code (Lines 105-133)

```yaml
- name: Get stack outputs
  id: outputs
  run: |
    echo "frontend_bucket=$(echo $OUTPUTS | jq ...)" >> $GITHUB_OUTPUT

- name: Upload Lambda code
  run: |
    aws lambda update-function-code \
      --function-name "${{ steps.outputs.outputs.lambda_function }}" \
      --zip-file fileb://lambda-deployment.zip
```

**How steps connect:**
- `id: outputs` - Names this step for reference
- `>> $GITHUB_OUTPUT` - Saves values for later steps
- `${{ steps.outputs.outputs.lambda_function }}` - References saved value

---

## Parameter Files Explained

### `parameters/dev.json`
```json
[
  { "ParameterKey": "Environment", "ParameterValue": "dev" },
  { "ParameterKey": "LambdaMemory", "ParameterValue": "512" },
  { "ParameterKey": "LambdaTimeout", "ParameterValue": "30" },
  { "ParameterKey": "BedrockModelId", "ParameterValue": "amazon.nova-lite-v1:0" }
]
```

### `parameters/prod.json`
```json
[
  { "ParameterKey": "Environment", "ParameterValue": "prod" },
  { "ParameterKey": "LambdaMemory", "ParameterValue": "1024" },
  { "ParameterKey": "LambdaTimeout", "ParameterValue": "60" },
  { "ParameterKey": "BedrockModelId", "ParameterValue": "amazon.nova-lite-v1:0" }
]
```

**Difference:** Production gets more memory (1024 vs 512 MB) and longer timeout (60 vs 30 seconds).

---

## Setup Steps (One-Time)

These steps connect GitHub to AWS. You only do this once per repository.

```
┌─────────────────┐                      ┌─────────────────┐
│      AWS        │                      │     GitHub      │
│                 │                      │                 │
│  OIDC Provider  │◄─── trusts ──────────│  Actions Runner │
│       +         │                      │                 │
│  IAM Role ──────┼─── role ARN ────────►│  Repository     │
│                 │    (manual copy)     │  Secret         │
└─────────────────┘                      └─────────────────┘
```

### 1. Deploy OIDC Stack First

Run this from your terminal (requires AWS CLI configured):

```bash
aws cloudformation deploy \
  --template-file cloudformation/github-oidc.yaml \
  --stack-name twin-github-oidc \
  --parameter-overrides GitHubOrg=YOUR_USERNAME GitHubRepo=YOUR_REPO \
  --capabilities CAPABILITY_NAMED_IAM
```

**What this creates:**
- OIDC Provider - tells AWS to trust tokens from GitHub
- IAM Role - defines what permissions GitHub Actions will have

### 2. Get the Role ARN

```bash
aws cloudformation describe-stacks \
  --stack-name twin-github-oidc \
  --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsRoleArn`].OutputValue' \
  --output text
```

**Output looks like:**
```
arn:aws:iam::123456789012:role/twin-github-actions-role
```

Copy this value - you'll need it in the next step.

### 3. Add to GitHub Secrets (Manual Step)

**Why is this manual?** AWS has no built-in way to push values to GitHub. Automating this would require GitHub API credentials, which creates another chicken-and-egg problem. This is a one-time setup, so manual is fine.

**Steps:**

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret** (green button)
5. Fill in:
   - **Name:** `AWS_ROLE_ARN`
   - **Secret:** paste the ARN from step 2
6. Click **Add secret**

**Screenshot location:**
```
GitHub Repo → Settings → Secrets and variables → Actions → New repository secret
```

### 4. Push to main branch

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will automatically:
1. Detect the push
2. Request OIDC token from GitHub
3. Exchange token for AWS credentials using your secret
4. Deploy everything to AWS

**Verify it worked:** Go to **Actions** tab in GitHub to see the workflow run.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Stack does not exist" during update | First deployment | Normal - will create stack |
| "CAPABILITY_NAMED_IAM" error | Missing flag | Add `--capabilities CAPABILITY_NAMED_IAM` |
| CORS errors in browser | Wrong origin | Check `CORS_ORIGINS` env var in Lambda |
| CloudFront shows old content | Cache | Run CloudFront invalidation |
| GitHub Actions "Access Denied" | OIDC not set up | Deploy `github-oidc.yaml` first |
| Lambda timeout | Memory/timeout too low | Increase values in parameters file |

---

## Quick Reference

### Deploy Locally
```bash
./scripts/deploy.sh dev      # Deploy to dev
./scripts/deploy.sh prod     # Deploy to prod
```

### Destroy Infrastructure
```bash
./scripts/destroy.sh dev     # Destroy dev (requires confirmation)
```

### View Logs
```bash
aws logs tail /aws/lambda/twin-dev-api --follow
```

### Test API
```bash
curl https://YOUR_API_URL/health
```
