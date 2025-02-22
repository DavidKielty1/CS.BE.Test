#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FUNCTIONS=(
    "FetchCreditCards"
    "NormalizeCreditCardData"
    "StoreInRedis"
    "PublishToSNS"
    "PublishToSQS"
    "ProcessFailedRequests"
)

echo -e "${YELLOW}Starting Lambda function updates...${NC}"

for func in "${FUNCTIONS[@]}"; do
    echo -e "${YELLOW}Updating $func...${NC}"
    
    # Check if zip file exists
    if [ ! -f "./dist/${func}.zip" ]; then
        echo -e "${RED}Error: ./dist/${func}.zip not found${NC}"
        continue
    fi  # <--- FIXED: Missing 'fi' to close the 'if' statement

    # Update function code
    aws lambda update-function-code \
        --function-name "$func" \
        --zip-file "fileb://./dist/${func}.zip" \
        --publish

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully updated $func${NC}"
    else
        echo -e "${RED}✗ Failed to update $func${NC}"
    fi
done

echo -e "${GREEN}Lambda updates completed${NC}"

# Verify the state machine definition is correct
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query 'stateMachines[?contains(name, `CreditCardWorkflow`)].stateMachineArn' --output text)

if [ -n "$STATE_MACHINE_ARN" ]; then  # FIXED: Use '-n' to check non-empty strings properly
    echo -e "${YELLOW}Verifying state machine definition...${NC}"
    aws stepfunctions describe-state-machine --state-machine-arn "$STATE_MACHINE_ARN"
fi  # <--- FIXED: Correct closing 'fi' for the 'if' statement