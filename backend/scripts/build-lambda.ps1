# Build script for Lambda deployment package (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "Building Lambda deployment package..."

# Clean previous build
if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" }
if (Test-Path "lambda-deployment.zip") { Remove-Item -Force "lambda-deployment.zip" }

# Bundle with esbuild
Write-Host "Bundling TypeScript..."
npx esbuild src/index.ts `
  --bundle `
  --platform=node `
  --target=node20 `
  --outfile=dist/index.js `
  --external:@aws-sdk/*

# Copy data files
Write-Host "Copying data files..."
New-Item -ItemType Directory -Force -Path "dist/data" | Out-Null
Copy-Item -Recurse "data/*" "dist/data/"

# Create zip file
Write-Host "Creating zip file..."
Compress-Archive -Path "dist/*" -DestinationPath "lambda-deployment.zip" -Force

# Show package size
$size = (Get-Item "lambda-deployment.zip").Length / 1KB
Write-Host "Created lambda-deployment.zip ($([math]::Round($size, 2)) KB)"
Write-Host "Done!"
