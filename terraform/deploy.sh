#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Handle Ctrl+C (SIGINT) to exit gracefully
trap ctrl_c INT

ctrl_c() {
    echo -e "\n${RED}⚠️ Deployment interrupted. Cleaning up and exiting...${NC}"
    exit 1
}

check_required_tools

# Backup state file
echo -e "${YELLOW}Backing up terraform state...${NC}"
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
fi

echo -e "${YELLOW}Starting Terraform deployment...${NC}"

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Show planned changes first
echo -e "${YELLOW}Planning changes...${NC}"
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Prompt for confirmation
echo -e "${YELLOW}Review the plan above. Do you want to proceed? (y/n)${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

# Deploy VPC networking first
echo -e "${YELLOW}Deploying VPC networking...${NC}"
terraform apply -var-file="terraform.tfvars" \
  -target="aws_eip.nat" \
  -target="aws_nat_gateway.main" \
  -target="aws_route_table.private" \
  -target="aws_route_table_association.private" \
  --auto-approve

# Verify NAT Gateway is ready
echo -e "${YELLOW}Verifying NAT Gateway...${NC}"
NAT_ID=$(terraform output -raw nat_gateway_id 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$NAT_ID" ]; then
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID
    echo -e "${GREEN}NAT Gateway is ready${NC}"
else
    echo -e "${YELLOW}Waiting 30 seconds for NAT Gateway...${NC}"
    sleep 30
fi

# Then create VPC endpoints
echo -e "${YELLOW}Creating VPC endpoints...${NC}"
terraform apply -var-file="terraform.tfvars" \
  -target="aws_vpc_endpoint.lambda" \
  -target="aws_vpc_endpoint.sns" \
  -target="aws_vpc_endpoint.sqs" \
  -target="aws_vpc_endpoint.logs" \
  --auto-approve

# Deploy Lambda functions
echo -e "${YELLOW}Deploying Lambda functions...${NC}"
terraform apply -var-file="terraform.tfvars" \
  -target="aws_lambda_function.functions" \
  -target="aws_cloudwatch_log_group.lambda_logs" \
  --auto-approve

# Deploy Redis infrastructure
echo -e "${YELLOW}Deploying Redis infrastructure...${NC}"
terraform apply -var-file="terraform.tfvars" \
  -target="aws_key_pair.redis" \
  -target="aws_eip.redis" \
  -target="aws_instance.redis" \
  -target="aws_eip_association.redis" \
  --auto-approve

# Setup SNS subscriptions
echo -e "${YELLOW}Setting up SNS subscriptions...${NC}"
terraform apply -var-file="terraform.tfvars" \
  -target="aws_sns_topic_subscription.lambda_subscription" \
  -target="aws_lambda_permission.allow_sns_lambda" \
  --auto-approve

# Deploy state machine
echo -e "${YELLOW}Deploying Step Functions state machine...${NC}"

# Check if log group exists
if aws logs describe-log-groups --log-group-name-prefix "/aws/states/CreditCardWorkflow" | grep -q "logGroupName"; then
  echo -e "${YELLOW}Log group already exists, skipping creation...${NC}"
else
  echo -e "${YELLOW}Creating log group...${NC}"
  terraform apply -var-file="terraform.tfvars" \
    -target="aws_cloudwatch_log_group.stepfunction_logs" \
    --auto-approve
fi

# Deploy state machine with logging configuration
terraform apply -var-file="terraform.tfvars" \
  -target="aws_sfn_state_machine.credit_card_workflow" \
  --auto-approve

# Generate appsettings.json
echo -e "${YELLOW}Generating appsettings.json...${NC}"
# Export terraform outputs directly
export AWS_REGION=$(terraform output -raw aws_region)
export STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn)
export SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)
export SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url)
export VPC_ID=$(terraform output -raw vpc_id)
export SUBNET_IDS=$(terraform output -json subnet_ids | jq -c)
export SECURITY_GROUP_IDS=$(terraform output -json security_group_ids | jq -c)
export REDIS_HOST=$(terraform output -raw redis_host)
export REDIS_PORT=$(terraform output -raw redis_port)
export REDIS_PASSWORD=$(terraform output -raw redis_password)
export REDIS_CONNECTION_STRING=$(terraform output -raw redis_connection_string)
export CS_CARDS_ENDPOINT=$(terraform output -raw cs_cards_endpoint)
export SCORED_CARDS_ENDPOINT=$(terraform output -raw scored_cards_endpoint)

# Create appsettings.json from template
if [ ! -f "../API/appsettings.template.json" ]; then
    echo -e "${RED}Error: appsettings.template.json not found${NC}"
    exit 1
fi

envsubst < "../API/appsettings.template.json" > "../API/appsettings.json"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate appsettings.json${NC}"
    exit 1
fi

# Wait for state machine to be ready
echo -e "${YELLOW}Waiting for state machine to be ready...${NC}"
sleep 10

# Verify state machine exists
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query 'stateMachines[?name==`CreditCardWorkflow`].stateMachineArn' --output text)
if [ -z "$STATE_MACHINE_ARN" ]; then
  echo -e "${RED}Error: State machine not found${NC}"
  exit 1
fi
echo -e "${GREEN}State machine ARN: $STATE_MACHINE_ARN${NC}"

# Final verification
echo -e "${YELLOW}Running final verification...${NC}"
terraform plan -var-file="terraform.tfvars"

echo -e "${GREEN}All infrastructure deployed successfully!${NC}"

# Reminder about NAT Gateway costs
echo -e "${YELLOW}⚠️ Remember: NAT Gateway is running and will incur costs. Use cleanup.sh to destroy when done.${NC}" 