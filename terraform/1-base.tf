# ==============================
# 🔹 SHARED CONFIGURATIONS
# ==============================

locals {
  # Base environment variables
  base_environment = {
    ASPNETCORE_ENVIRONMENT = "Production"
    AWS__Region           = var.aws_region
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
  }

  # Lambda-specific base environment
  lambda_base_environment = merge(local.base_environment, {
    AWS__Region = var.aws_region
  })
}

# ==============================
# 🔹 PROVIDERS
# ==============================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "eu-west-2"
}

# ==============================
# 🔹 IAM ROLES & POLICIES
# ==============================

# Unified Service Role
resource "aws_iam_role" "service_role" {
  name = "CreditCardServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { 
        Service = [
          "states.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Unified Service Policy
resource "aws_iam_role_policy" "unified_policy" {
  name = "CreditCardServicePolicy"
  role = aws_iam_role.service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Lambda
          "lambda:InvokeFunction",
          "lambda:GetFunction",
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          
          # SQS
          "sqs:*",
          
          # SNS
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          
          # CloudWatch
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          
          # Step Functions
          "states:StartExecution",
          "states:DescribeExecution",
          "states:GetExecutionHistory",
          "states:ListExecutions",
          "states:StopExecution",
          
          # EC2 (for Redis)
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
          
          # VPC
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          
          # Secrets Manager
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          
          # IAM
          "iam:PassRole",
          "iam:GetRole",
          
          # DLQ Permissions
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          
          # X-Ray Permissions
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          
          # CloudWatch Lambda Insights
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          
          # Step Functions Logging
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==============================
# 🔹 VPC ENDPOINTS
# ==============================

# Lambda VPC endpoint
resource "aws_vpc_endpoint" "lambda" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}

# CloudWatch Logs VPC endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}

# ==============================
# 🔹 LAMBDA SECURITY
# ==============================

# Lambda security group
resource "aws_security_group" "lambda_sg" {
  name_prefix = "lambda-sg-"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "lambda-security-group"
  }
}

# Alert topic
resource "aws_sns_topic" "alerts" {
  name = "lambda-alerts"
}

# ==============================
# 🔹 VPC NETWORKING
# ==============================

# Data source to find existing Internet Gateway
data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

# NAT Gateway requires an Elastic IP
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT Gateway in the public subnet (subnet with IGW route)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id  # This is subnet-077a487bc315c0e7e
  
  tags = {
    Name = "credit-card-nat-gateway"
  }

  depends_on = [data.aws_internet_gateway.main]
}

# Get the existing route table
data "aws_route_table" "existing" {
  subnet_id = var.subnet_ids[0]
}

# Add our NAT Gateway route to the existing route table
resource "aws_route" "nat_gateway" {
  route_table_id         = data.aws_route_table.existing.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

