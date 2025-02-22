#!/bin/bash

# Colors for output
./cleanup.sh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LAMBDA_NAME="PublishToSNS"

echo -e "${YELLOW}Building and deploying $LAMBDA_NAME...${NC}"

# Clean directories
echo "Cleaning directories..."
rm -rf dist/$LAMBDA_NAME
mkdir -p dist/$LAMBDA_NAME

# Build optimization flags
export DOTNET_CLI_HOME="/tmp"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
export DOTNET_CLI_TELEMETRY_OPTOUT=true

# Build Lambda
echo "Building $LAMBDA_NAME..."
dotnet publish "../API/Lambdas/$LAMBDA_NAME/$LAMBDA_NAME.csproj" \
    -c Release \
    --runtime linux-x64 \
    --no-self-contained \
    -p:PublishReadyToRun=true \
    -o "dist/$LAMBDA_NAME" \
    -v n \
    --nologo

# Create zip
cd "dist/$LAMBDA_NAME"
echo "Creating zip for $LAMBDA_NAME..."
zip -j "../$LAMBDA_NAME.zip" \
    "$LAMBDA_NAME.dll" \
    "$LAMBDA_NAME.deps.json" \
    "$LAMBDA_NAME.runtimeconfig.json" \
    "Amazon.Lambda.Core.dll" \
    "Amazon.Lambda.Serialization.SystemTextJson.dll" \
    "API.dll" \
    "*.dll"
cd ../..

# Update Lambda
echo "Updating Lambda function..."
aws lambda update-function-code \
    --function-name $LAMBDA_NAME \
    --zip-file fileb://dist/$LAMBDA_NAME.zip

echo -e "${GREEN}✅ $LAMBDA_NAME deployment complete${NC}" 
./cleanup.sh