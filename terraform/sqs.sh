#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LAMBDA_NAME="PublishToSQS"

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

# First clean any existing builds
rm -rf "../API/Lambdas/$LAMBDA_NAME/bin"
rm -rf "../API/Lambdas/$LAMBDA_NAME/obj"

# Build Lambda
echo "Building $LAMBDA_NAME..."
echo "Restoring packages..."
dotnet restore "../API/Lambdas/$LAMBDA_NAME/$LAMBDA_NAME.csproj"

echo "Publishing $LAMBDA_NAME..."
dotnet publish "../API/Lambdas/$LAMBDA_NAME/$LAMBDA_NAME.csproj" \
    -c Release \
    --runtime linux-x64 \
    --no-self-contained \
    -p:PublishReadyToRun=true \
    -p:GenerateRuntimeConfigurationFiles=true \
    -o "dist/$LAMBDA_NAME" \
    -v minimal

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Verify files exist
echo "Checking build output..."
ls -la dist/$LAMBDA_NAME/

# Check specifically for required files
if [ ! -f "dist/$LAMBDA_NAME/$LAMBDA_NAME.dll" ]; then
    echo -e "${RED}❌ $LAMBDA_NAME.dll not found!${NC}"
    exit 1
fi

# Create zip
cd "dist/$LAMBDA_NAME"
echo "Creating zip for $LAMBDA_NAME..."
echo "Creating empty zip file first..."
touch empty.txt
zip "../$LAMBDA_NAME.zip" empty.txt
rm empty.txt

echo "Available DLLs:"
ls -la *.dll

zip -j "../$LAMBDA_NAME.zip" \
    "$LAMBDA_NAME.dll" \
    "$LAMBDA_NAME.deps.json" \
    "$LAMBDA_NAME.runtimeconfig.json" \
    "Amazon.Lambda.Core.dll" \
    "Amazon.Lambda.Serialization.SystemTextJson.dll" \
    "API.dll" \
    $(ls *.dll)
cd ../..

# Update Lambda
echo "Updating Lambda function..."

# Check if function exists
if aws lambda get-function --function-name $LAMBDA_NAME 2>/dev/null; then
  echo "Updating existing function..."
  aws lambda update-function-code \
      --function-name $LAMBDA_NAME \
      --zip-file fileb://dist/$LAMBDA_NAME.zip
else
  echo "Creating new function..."
  aws lambda create-function \
      --function-name $LAMBDA_NAME \
      --runtime dotnet8 \
      --handler "PublishToSQS::API.Lambdas.PublishToSQS.PublishToSQSHandler::FunctionHandler" \
      --role "arn:aws:iam::156041400555:role/CreditCardServiceRole" \
      --zip-file fileb://dist/$LAMBDA_NAME.zip \
      --timeout 30 \
      --memory-size 256 \
      --environment "Variables={ASPNETCORE_ENVIRONMENT=Production}" \
      --vpc-config SubnetIds=subnet-0c244a917533aaed9,subnet-0ab3aa1bc86bbd118,SecurityGroupIds=sg-0bb5b4768b2a39340
fi

# Verify the update
echo "Verifying Lambda update..."
aws lambda get-function --function-name $LAMBDA_NAME

echo -e "${GREEN}✅ $LAMBDA_NAME deployment complete${NC}" 