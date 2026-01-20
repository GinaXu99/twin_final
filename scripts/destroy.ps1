# Destroy script for AI Digital Twin infrastructure
# Usage: .\destroy.ps1 [environment]
# Example: .\destroy.ps1 dev

param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "twin"
$StackName = "$ProjectName-$Environment"
$AwsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }

Write-Host "========================================" -ForegroundColor Red
Write-Host "DESTROYING AI Digital Twin" -ForegroundColor Red
Write-Host "Environment: $Environment" -ForegroundColor Red
Write-Host "Stack: $StackName" -ForegroundColor Red
Write-Host "Region: $AwsRegion" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

# Confirmation
$Confirm = Read-Host "Are you sure you want to destroy the $Environment environment? (type 'yes' to confirm)"
if ($Confirm -ne "yes") {
    Write-Host "Cancelled."
    exit 0
}

# Check if stack exists
$StackExists = $false
try {
    aws cloudformation describe-stacks --stack-name $StackName --region $AwsRegion 2>&1 | Out-Null
    $StackExists = $true
} catch {
    $StackExists = $false
}

if (-not $StackExists) {
    Write-Host "Stack $StackName does not exist." -ForegroundColor Yellow
    exit 0
}

# Get S3 bucket names before deletion
Write-Host "`nGetting S3 bucket names..." -ForegroundColor Yellow
$Outputs = aws cloudformation describe-stacks --stack-name $StackName --region $AwsRegion --query 'Stacks[0].Outputs' | ConvertFrom-Json
$FrontendBucket = ($Outputs | Where-Object { $_.OutputKey -eq "FrontendBucketName" }).OutputValue
$MemoryBucket = ($Outputs | Where-Object { $_.OutputKey -eq "MemoryBucketName" }).OutputValue

# Empty S3 buckets (required before CloudFormation can delete them)
Write-Host "`nEmptying S3 buckets..." -ForegroundColor Yellow

if ($FrontendBucket) {
    Write-Host "Emptying frontend bucket: $FrontendBucket"
    aws s3 rm "s3://$FrontendBucket" --recursive --region $AwsRegion 2>&1 | Out-Null
}

if ($MemoryBucket) {
    Write-Host "Emptying memory bucket: $MemoryBucket"
    # Delete all versions for versioned bucket
    $versions = aws s3api list-object-versions --bucket $MemoryBucket --region $AwsRegion --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>$null | ConvertFrom-Json
    foreach ($obj in $versions) {
        if ($obj) {
            aws s3api delete-object --bucket $MemoryBucket --key $obj.Key --version-id $obj.VersionId --region $AwsRegion 2>&1 | Out-Null
        }
    }

    # Delete delete markers
    $markers = aws s3api list-object-versions --bucket $MemoryBucket --region $AwsRegion --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>$null | ConvertFrom-Json
    foreach ($obj in $markers) {
        if ($obj) {
            aws s3api delete-object --bucket $MemoryBucket --key $obj.Key --version-id $obj.VersionId --region $AwsRegion 2>&1 | Out-Null
        }
    }
}

Write-Host "S3 buckets emptied" -ForegroundColor Green

# Delete CloudFormation stack
Write-Host "`nDeleting CloudFormation stack..." -ForegroundColor Yellow
aws cloudformation delete-stack --stack-name $StackName --region $AwsRegion

Write-Host "Waiting for stack deletion (this may take 5-10 minutes)..."
aws cloudformation wait stack-delete-complete --stack-name $StackName --region $AwsRegion

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Destruction Complete!" -ForegroundColor Green
Write-Host "Stack $StackName has been deleted." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
