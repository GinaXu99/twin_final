#!/bin/bash
# Build script for Lambda deployment package

set -e

echo "Building Lambda deployment package..."

# Clean previous build
rm -rf dist lambda-deployment.zip

# Bundle with esbuild
echo "Bundling TypeScript..."
npx esbuild src/index.ts \
  --bundle \
  --platform=node \
  --target=node20 \
  --outfile=dist/index.js \
  --external:@aws-sdk/*

# Copy data files
echo "Copying data files..."
mkdir -p dist/data
cp -r data/* dist/data/

# Create zip file
echo "Creating zip file..."
cd dist
zip -r ../lambda-deployment.zip .
cd ..

# Show package size
SIZE=$(ls -lh lambda-deployment.zip | awk '{print $5}')
echo "Created lambda-deployment.zip ($SIZE)"
echo "Done!"
