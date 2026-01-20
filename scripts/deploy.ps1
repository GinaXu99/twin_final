# Deploy script for AI Digital Twin (CloudFormation + Node.js)
# Usage: .\deploy.ps1 [environment]
# Example: .\deploy.ps1 dev

param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "twin"
$StackName = "$ProjectName-$Environment"
$AwsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }

Write-Host "========================================" -ForegroundColor Green
Write-Host "Deploying AI Digital Twin" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "Stack: $StackName" -ForegroundColor Green
Write-Host "Region: $AwsRegion" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Error: AWS CLI is not installed" -ForegroundColor Red
    exit 1
}

# Check if Node.js is installed
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is not installed" -ForegroundColor Red
    exit 1
}

# Step 1: Build Backend Lambda Package
Write-Host "`nStep 1: Building backend Lambda package..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\backend"

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..."
    npm install
}

# Build Lambda package
Write-Host "Building Lambda package..."
npm run build

# Create dist\data directory and copy data files
New-Item -ItemType Directory -Force -Path "dist\data" | Out-Null
Copy-Item -Recurse -Force "data\*" "dist\data\"

# Create zip file
if (Test-Path "lambda-deployment.zip") { Remove-Item "lambda-deployment.zip" }
Compress-Archive -Path "dist\*" -DestinationPath "lambda-deployment.zip" -Force

$LambdaSize = (Get-Item "lambda-deployment.zip").Length / 1KB
Write-Host "Lambda package created: lambda-deployment.zip ($([math]::Round($LambdaSize, 2)) KB)" -ForegroundColor Green

# Step 2: Build Frontend
Write-Host "`nStep 2: Building frontend..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\frontend"

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..."
    npm install
}

# Build frontend
npm run build
Write-Host "Frontend build complete" -ForegroundColor Green

# Step 3: Deploy CloudFormation Stack
Write-Host "`nStep 3: Deploying CloudFormation stack..." -ForegroundColor Yellow
Set-Location $ProjectRoot

# Check if stack exists
$StackExists = $false
try {
    aws cloudformation describe-stacks --stack-name $StackName --region $AwsRegion 2>&1 | Out-Null
    $StackExists = $true
} catch {
    $StackExists = $false
}

if (-not $StackExists) {
    Write-Host "Creating new stack..."
    aws cloudformation create-stack `
        --stack-name $StackName `
        --template-body "file://cloudformation/main.yaml" `
        --parameters "file://cloudformation/parameters/$Environment.json" `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $AwsRegion `
        --tags Key=Environment,Value=$Environment Key=Project,Value=$ProjectName

    Write-Host "Waiting for stack creation..."
    aws cloudformation wait stack-create-complete --stack-name $StackName --region $AwsRegion
} else {
    Write-Host "Updating existing stack..."
    try {
        aws cloudformation update-stack `
            --stack-name $StackName `
            --template-body "file://cloudformation/main.yaml" `
            --parameters "file://cloudformation/parameters/$Environment.json" `
            --capabilities CAPABILITY_NAMED_IAM `
            --region $AwsRegion

        Write-Host "Waiting for stack update..."
        aws cloudformation wait stack-update-complete --stack-name $StackName --region $AwsRegion
    } catch {
        Write-Host "No updates to perform or update in progress"
    }
}

Write-Host "CloudFormation stack deployed" -ForegroundColor Green

# Step 4: Get Stack Outputs
Write-Host "`nStep 4: Getting stack outputs..." -ForegroundColor Yellow
$Outputs = aws cloudformation describe-stacks --stack-name $StackName --region $AwsRegion --query 'Stacks[0].Outputs' | ConvertFrom-Json

$FrontendBucket = ($Outputs | Where-Object { $_.OutputKey -eq "FrontendBucketName" }).OutputValue
$LambdaFunction = ($Outputs | Where-Object { $_.OutputKey -eq "LambdaFunctionName" }).OutputValue
$CloudFrontUrl = ($Outputs | Where-Object { $_.OutputKey -eq "CloudFrontUrl" }).OutputValue
$CloudFrontId = ($Outputs | Where-Object { $_.OutputKey -eq "CloudFrontDistributionId" }).OutputValue
$ApiUrl = ($Outputs | Where-Object { $_.OutputKey -eq "ApiGatewayUrl" }).OutputValue

Write-Host "Frontend Bucket: $FrontendBucket"
Write-Host "Lambda Function: $LambdaFunction"
Write-Host "API Gateway URL: $ApiUrl"
Write-Host "CloudFront URL: $CloudFrontUrl"

# Step 5: Upload Lambda Code
Write-Host "`nStep 5: Uploading Lambda code..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\backend"

aws lambda update-function-code `
    --function-name $LambdaFunction `
    --zip-file "fileb://lambda-deployment.zip" `
    --region $AwsRegion

Write-Host "Lambda code uploaded" -ForegroundColor Green

# Step 6: Upload Frontend to S3
Write-Host "`nStep 6: Uploading frontend to S3..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\frontend"

aws s3 sync out/ "s3://$FrontendBucket/" --delete --region $AwsRegion

Write-Host "Frontend uploaded to S3" -ForegroundColor Green

# Step 7: Invalidate CloudFront Cache
Write-Host "`nStep 7: Invalidating CloudFront cache..." -ForegroundColor Yellow
$InvalidationId = aws cloudfront create-invalidation `
    --distribution-id $CloudFrontId `
    --paths "/*" `
    --query 'Invalidation.Id' `
    --output text

Write-Host "Invalidation ID: $InvalidationId"
Write-Host "CloudFront cache invalidation started" -ForegroundColor Green

# Done
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nYour Digital Twin is live at:" -ForegroundColor Green
Write-Host "$CloudFrontUrl" -ForegroundColor Yellow
Write-Host "`nAPI Endpoint:" -ForegroundColor Green
Write-Host "$ApiUrl" -ForegroundColor Yellow
Write-Host "`nHealth Check:" -ForegroundColor Green
Write-Host "$ApiUrl/health" -ForegroundColor Yellow
