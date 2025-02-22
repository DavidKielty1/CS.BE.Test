#!/bin/bash

# Exit on any error
set -e

# Clean up first
echo "Cleaning up old artifacts..."
./cleanup.sh

#!/bin/bash

# Set the solution directory (one level above)
SOLUTION_DIR="../API"
SOLUTION_NAME="API.sln"
SOLUTION_PATH="$SOLUTION_DIR/$SOLUTION_NAME"

# Ensure the solution directory exists
mkdir -p "$SOLUTION_DIR"

# Check if the solution file already exists
if [ -f "$SOLUTION_PATH" ]; then
    echo "⚠️ Solution file already exists: $SOLUTION_PATH"
    echo "Skipping creation. Use --force to overwrite."
else
    echo "🛠️ Creating solution file..."
    dotnet new sln -n API -o "$SOLUTION_DIR"
fi

# Array of project paths to add to the solution
PROJECTS=(
    "../API/API.csproj"
    "../API/Lambdas/FetchCreditCards/FetchCreditCards.csproj"
    "../API/Lambdas/NormalizeCreditCardData/NormalizeCreditCardData.csproj"
    "../API/Lambdas/StoreInRedis/StoreInRedis.csproj"
    "../API/Lambdas/PublishToSNS/PublishToSNS.csproj"
    "../API/Lambdas/PublishToSQS/PublishToSQS.csproj"
    "../API/Lambdas/ProcessFailedRequests/ProcessFailedRequests.csproj"
)

# Add each project to the solution
for project in "${PROJECTS[@]}"; do
    dotnet sln "$SOLUTION_DIR/$SOLUTION_NAME" add "$project"
done

echo "✅ Solution setup complete!"



echo "Building Lambda functions..."

# Clean directories
echo "Cleaning directories..."

rm -rf ../API/*/bin ../API/*/obj ../API/*/*/bin ../API/*/*/obj dist

# Update all Lambda project files
for lambda in "FetchCreditCards" "NormalizeCreditCardData" "StoreInRedis" "PublishToSNS" "PublishToSQS" "ProcessFailedRequests"
do
    cat > "../API/Lambdas/$lambda/$lambda.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>
    <AWSProjectType>Lambda</AWSProjectType>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="../../API.csproj" />
  </ItemGroup>
</Project>
EOF
done

# Clean obj and bin directories
find ../API -type d \( -name "bin" -o -name "obj" \) -exec rm -rf {} +

# Build optimization flags
export DOTNET_CLI_HOME="/tmp"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
export DOTNET_CLI_TELEMETRY_OPTOUT=true

# # Generate appsettings.json from template
# echo "Generating appsettings.json..."
# cat ../API/appsettings.template.json | \
#   sed "s|\${AWS_REGION}|$(terraform output -raw aws_region)|g" | \
#   sed "s|\${STATE_MACHINE_ARN}|$(terraform output -raw state_machine_arn)|g" | \
#   sed "s|\${SNS_TOPIC_ARN}|$(terraform output -raw sns_topic_arn)|g" | \
#   sed "s|\${SQS_QUEUE_URL}|$(terraform output -raw sqs_queue_url)|g" | \
#   sed "s|\${VPC_ID}|$(terraform output -raw vpc_id)|g" | \
#   sed "s|\${SUBNET_IDS}|$(terraform output -raw subnet_ids_json)|g" | \
#   sed "s|\${SECURITY_GROUP_IDS}|$(terraform output -raw security_group_ids_json)|g" | \
#   sed "s|\${REDIS_HOST}|$(terraform output -raw redis_host)|g" | \
#   sed "s|\${REDIS_PORT}|$(terraform output -raw redis_port)|g" | \
#   sed "s|\${REDIS_PASSWORD}|$(terraform output -raw redis_password)|g" | \
#   sed "s|\${REDIS_CONNECTION_STRING}|$(terraform output -raw redis_connection_string)|g" | \
#   sed "s|\${CS_CARDS_ENDPOINT}|$(terraform output -raw cs_cards_endpoint)|g" | \
#   sed "s|\${SCORED_CARDS_ENDPOINT}|$(terraform output -raw scored_cards_endpoint)|g" \
#   > ../API/appsettings.json

# Restore solution first
echo "Restoring solution..."
dotnet restore "../API/API.sln" -r linux-x64

# Build each Lambda
for lambda in "FetchCreditCards" "NormalizeCreditCardData" "StoreInRedis" "PublishToSNS" "PublishToSQS" "ProcessFailedRequests"
do
    echo "Building $lambda..."
    
    # Create Lambda directory
    mkdir -p "dist/$lambda"
    
    # Build with more verbosity
    echo "Publishing $lambda to dist/$lambda..."
    dotnet publish "../API/Lambdas/$lambda/$lambda.csproj" \
        -c Release \
        --runtime linux-x64 \
        --no-self-contained \
        -p:PublishReadyToRun=true \
        -o "dist/$lambda" \
        -v n \
        --nologo
    
    # Add more verbose error checking
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build $lambda"
        exit 1
    fi
    
    # Verify DLL exists
    if [ ! -f "dist/$lambda/$lambda.dll" ]; then
        echo "❌ Error: $lambda.dll not found in dist/$lambda!"
        echo "Build output directory contents:"
        ls -R "dist/$lambda"
        exit 1
    fi
    
    # Create zip
    cd "dist/$lambda"
    echo "Creating zip for $lambda..."
    zip -j "../$lambda.zip" \
        "$lambda.dll" \
        "$lambda.deps.json" \
        "$lambda.runtimeconfig.json" \
        "Amazon.Lambda.Core.dll" \
        "Amazon.Lambda.Serialization.SystemTextJson.dll" \
        "API.dll" \
        "*.dll"  # Include all DLLs
    cd ../..
    
    # Verify zip was created
    if [ ! -f "dist/$lambda.zip" ]; then
        echo "❌ Error: Failed to create zip for $lambda"
        exit 1
    fi
    
    echo "✅ $lambda completed"
done

echo "Build complete. Lambda packages:"
ls -lh dist/*.zip 



./update-lambdas.sh


# After creating zip files, create or update the Lambda functions
# for lambda in "${LAMBDA_FUNCTIONS[@]}"; do
#     echo "Deploying $lambda..."
    
#     # Add more verbose output
#     echo "Checking if $lambda exists..."
#     if aws lambda get-function --function-name "$lambda" 2>/dev/null; then
#         # Update existing Lambda
#         echo "Updating existing $lambda function..."
#         aws lambda update-function-code \
#             --function-name "$lambda" \
#             --zip-file "fileb://dist/$lambda.zip"
#     else
#         # Create new Lambda
#         echo "Creating new $lambda function..."
#         aws lambda create-function \
#             --function-name "$lambda" \
#             --runtime dotnet8 \
#             --handler "$(grep -A 1 "\"$lambda\"" ../terraform/3-lambda.tf | grep "handler" | cut -d'"' -f4)" \
#             --role "$(terraform output -raw lambda_role_arn)" \
#             --zip-file "fileb://dist/$lambda.zip" \
#             --vpc-config "SubnetIds=$(terraform output -json subnet_ids),SecurityGroupIds=[$(terraform output -raw lambda_sg_id)]" \
#             --environment "Variables={$(terraform output -raw lambda_environment_$lambda)}" \
#             --memory-size "$(grep -A 1 "\"$lambda\"" ../terraform/3-lambda.tf | grep "memory_size" | cut -d'=' -f2 | tr -d ' ')" \
#             --timeout "$(grep -A 1 "\"$lambda\"" ../terraform/3-lambda.tf | grep "timeout" | cut -d'=' -f2 | tr -d ' ')"
#     fi
    
#     # Verify the function exists after creation/update
#     if ! aws lambda get-function --function-name "$lambda" >/dev/null 2>&1; then
#         echo "❌ Error: Failed to verify $lambda function exists after deployment"
#         exit 1
#     fi
# done

