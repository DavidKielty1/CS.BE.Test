##Deprecated#


# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#     http = {
#       source  = "hashicorp/http"
#       version = "~> 3.0"
#     }
#     local = {
#       source  = "hashicorp/local"
#       version = "~> 2.0"
#     }
#   }
# }

# # Configure AWS Providers
# provider "aws" {
#   region = var.aws_region
#   alias  = "eu-west-2"
# }

# # ==============================
# # 🔹 LOCALS
# # ==============================

# locals {
#   # Common configuration from appsettings.json
#   shared_config = jsondecode(file("${path.module}/../src/Core/Core.Infrastructure/Configuration/appsettings.json"))

#   # Base environment variables (no dependencies)
#   base_environment = {
#     Redis__ConnectionString = "${aws_eip.redis.public_ip}:${var.redis_port}"
#     Redis__Password        = var.redis_password
#     ASPNETCORE_ENVIRONMENT = "Production"
#     AWS__Region           = var.aws_region
#     DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#   }

#   # Function-specific base configs (no resource dependencies)
#   lambda_config = {
#     FetchCreditCards = {
#       handler     = "FetchCreditCards::API.Lambdas.FetchCreditCards.FetchCreditCardsHandler::HandleAsync"
#       memory_size = 256
#       timeout     = 30
#       environment = local.base_environment
#     }
#     NormalizeCreditCardData = {
#       handler     = "NormalizeCreditCardData::API.Lambdas.NormalizeCreditCardData.NormalizeCreditCardHandler::FunctionHandler"
#       memory_size = 256
#       timeout     = 30
#       environment = local.base_environment
#     }
#     StoreInRedis = {
#       handler = "StoreInRedis::API.Lambdas.StoreInRedis.StoreInRedisHandler::FunctionHandler"
#       memory_size = 256
#       timeout = 30
#       environment = {
#         DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#         REDIS_HOST = aws_eip.redis.public_ip
#         REDIS_PORT = tostring(local.shared_config.Redis.Port)
#         REDIS_PASSWORD = local.shared_config.Redis.Password
#         AWS__Region = local.shared_config.AWS.Region
#       }
#     }
#     PublishToSNS = {
#       handler = "PublishToSNS::API.Lambdas.PublishToSNS.PublishToSNSHandler::FunctionHandler"
#       memory_size = 256
#       timeout = 30
#       environment = {
#         DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#         AWS__Region = local.shared_config.AWS.Region
#         AWS__SnsTopicArn = aws_sns_topic.credit_card_topic.arn
#         AWS__SqsQueueUrl = aws_sqs_queue.credit_card_queue.url
#       }
#     }
#     PublishToSQS = {
#       handler = "PublishToSQS::API.Lambdas.PublishToSQS.PublishToSQSHandler::FunctionHandler"
#       memory_size = 256
#       timeout = 30
#       environment = {
#         DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#         AWS__Region = local.shared_config.AWS.Region
#         AWS__SqsQueueUrl = aws_sqs_queue.credit_card_queue.url
#       }
#     }
#     ProcessFailedRequests = {
#       handler = "ProcessFailedRequests::API.Lambdas.ProcessFailedRequests.ProcessFailedRequestsHandler::FunctionHandler"
#       memory_size = 256
#       timeout = 30
#       environment = {
#         DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#         AWS__Region = local.shared_config.AWS.Region
#         AWS__SnsTopicArn = aws_sns_topic.credit_card_topic.arn
#       }
#     }
#   }
# }

# # ==============================
# # 🔹 IAM ROLES & POLICIES
# # ==============================

# # Unified Service Role
# resource "aws_iam_role" "service_role" {
#   name = "CreditCardServiceRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = { 
#         Service = [
#           "states.amazonaws.com",
#           "lambda.amazonaws.com"
#         ]
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # Unified Service Policy
# resource "aws_iam_role_policy" "unified_policy" {
#   name = "CreditCardServicePolicy"
#   role = aws_iam_role.service_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           # Lambda
#           "lambda:InvokeFunction",
#           "lambda:GetFunction",
#           "lambda:CreateFunction",
#           "lambda:UpdateFunctionCode",
#           "lambda:UpdateFunctionConfiguration",
          
#           # SQS
#           "sqs:*",
          
#           # SNS
#           "sns:Publish",
#           "sns:Subscribe",
#           "sns:Unsubscribe",
          
#           # CloudWatch
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogStreams",
#           "cloudwatch:PutMetricData",
#           "cloudwatch:GetMetricData",
          
#           # Step Functions
#           "states:StartExecution",
#           "states:DescribeExecution",
#           "states:GetExecutionHistory",
#           "states:ListExecutions",
#           "states:StopExecution",
          
#           # EC2 (for Redis)
#           "ec2:CreateNetworkInterface",
#           "ec2:DescribeNetworkInterfaces",
#           "ec2:DeleteNetworkInterface",
#           "ec2:AssignPrivateIpAddresses",
#           "ec2:UnassignPrivateIpAddresses",
          
#           # VPC
#           "ec2:CreateNetworkInterfacePermission",
#           "ec2:DescribeVpcs",
#           "ec2:DescribeSubnets",
#           "ec2:DescribeSecurityGroups",
          
#           # Secrets Manager
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret",
          
#           # IAM
#           "iam:PassRole",
#           "iam:GetRole",
          
#           # DLQ Permissions
#           "sqs:SendMessage",
#           "sqs:GetQueueAttributes",
#           "sqs:GetQueueUrl",
          
#           # X-Ray Permissions
#           "xray:PutTraceSegments",
#           "xray:PutTelemetryRecords",
          
#           # CloudWatch Lambda Insights
#           "cloudwatch:PutMetricData",
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# # ==============================
# # 🔹 LAMBDA FUNCTIONS
# # ==============================

# # Security Groups
# resource "aws_security_group" "lambda_sg" {
#   name        = "lambda-security-group"
#   description = "Security group for Lambda functions"
#   vpc_id      = var.vpc_id

#   # Allow outbound internet access
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Allow inbound access from VPC
#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = [data.aws_vpc.selected.cidr_block]
#   }

#   tags = {
#     Name = "lambda-sg"
#   }
# }

# # Get VPC details
# data "aws_vpc" "selected" {
#   id = var.vpc_id
# }

# # Lambda function resource
# resource "aws_lambda_function" "functions" {
#   for_each = local.lambda_config
  
#   filename         = "./dist/${each.key}.zip"
#   function_name    = each.key
#   role            = aws_iam_role.service_role.arn
#   handler         = each.value.handler
#   runtime         = "dotnet8"
#   memory_size     = each.value.memory_size
#   timeout         = each.value.timeout
  
  
#   # Add source_code_hash to trigger updates when code changes
#   source_code_hash = filebase64sha256("./dist/${each.key}.zip")

#   vpc_config {
#     subnet_ids         = var.subnet_ids
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }

#   environment {
#     variables = merge(local.base_environment, {
#       AWS__StateMachineArn = aws_sfn_state_machine.credit_card_workflow.arn
#       AWS__SnsTopicArn     = aws_sns_topic.credit_card_topic.arn
#       AWS__SqsQueueUrl     = aws_sqs_queue.credit_card_queue.url
#     })
#   }

#   dead_letter_config {
#     target_arn = aws_sqs_queue.lambda_dlq[each.key].arn
#   }

#   tracing_config {
#     mode = "Active"
#   }

#   # Add lifecycle block to handle replacement
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ==============================
# # 🔹 SQS QUEUE
# # ==============================

# resource "aws_sqs_queue" "credit_card_dlq" {
#   name = "CreditCardProcessingDLQ"
#   message_retention_seconds = 1209600 # 14 days
# }

# resource "aws_sqs_queue" "credit_card_queue" {
#   name                       = "CreditCardProcessingQueue"
#   visibility_timeout_seconds = 30
#   message_retention_seconds  = 86400
#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.credit_card_dlq.arn
#     maxReceiveCount     = 2
#   })
# }

# # ==============================
# # 🔹 SNS TOPIC
# # ==============================

# resource "aws_sns_topic" "credit_card_topic" {
#   name = "CreditCardNotifications"
# }

# resource "aws_sns_topic_subscription" "lambda_subscription" {
#   topic_arn = aws_sns_topic.credit_card_topic.arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.functions["StoreInRedis"].arn
# }

# resource "aws_lambda_permission" "allow_sns_lambda" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.functions["StoreInRedis"].function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.credit_card_topic.arn
# }

# # ==============================
# # 🔹 AWS STEP FUNCTION
# # ==============================

# # Create Step Functions state machine without Lambda ARNs initially
# resource "aws_sfn_state_machine" "credit_card_workflow" {
#   name     = "CreditCardWorkflow"
#   role_arn = aws_iam_role.service_role.arn
  
#   definition = jsonencode({
#     # Basic state machine definition without Lambda ARNs
#     StartAt = "FetchCreditCards"
#     States = {
#       FetchCreditCards = {
#         Type = "Pass"
#         End  = true
#       }
#     }
#   })
# }

# # Update Step Functions state machine with Lambda ARNs after functions are created
# resource "aws_sfn_state_machine" "credit_card_workflow_update" {
#   depends_on = [aws_lambda_function.functions]
  
#   name     = "CreditCardWorkflow"
#   role_arn = aws_iam_role.service_role.arn
  
#   definition = jsonencode({
#     # Full state machine definition with Lambda ARNs
#     StartAt = "FetchCreditCards"
#     States = {
#       FetchCreditCards = {
#         Type     = "Task"
#         Resource = aws_lambda_function.functions["FetchCreditCards"].arn
#         Next     = "NormalizeCreditCardData"
#       }
#       NormalizeCreditCardData = {
#         Type     = "Task"
#         Resource = aws_lambda_function.functions["NormalizeCreditCardData"].arn
#         End      = true
#       }
#     }
#   })

#   lifecycle {
#     replace_triggered_by = [aws_lambda_function.functions]
#   }
# }

# # Output the ARN for use in the application
# output "state_machine_arn" {
#   value = aws_sfn_state_machine.credit_card_workflow.arn
#   description = "ARN of the Step Functions state machine"
# }

# # Get current IP address
# data "http" "my_ip" {
#   url = "https://api.ipify.org"
# }

# # Then define Redis security group that references Lambda
# resource "aws_security_group" "redis_sg" {
#   name_prefix = "redis-sg-"
#   description = "Security group for Redis server"
#   vpc_id      = local.shared_config.AWS.VPC.Id

#   ingress {
#     from_port       = local.shared_config.Redis.Port
#     to_port         = local.shared_config.Redis.Port
#     protocol        = "tcp"
#     security_groups = [aws_security_group.lambda_sg.id]
#     description     = "Allow Redis access from Lambda functions"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Add SSH access with dynamic IP
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
#     description = "SSH access from current IP"
#   }
# }

# # CloudWatch Alarm for DLQ
# resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
#   alarm_name          = "credit-card-dlq-not-empty"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "ApproximateNumberOfMessagesVisible"
#   namespace           = "AWS/SQS"
#   period             = "300"
#   statistic          = "Average"
#   threshold          = "0"
#   alarm_description  = "This metric monitors DLQ for failed credit card requests"
#   alarm_actions      = [aws_sns_topic.credit_card_topic.arn]

#   dimensions = {
#     QueueName = aws_sqs_queue.credit_card_dlq.name
#   }
# }

# # ==============================
# # 🔹 VPC NETWORKING
# # ==============================

# # Data source to find existing Internet Gateway
# data "aws_internet_gateway" "main" {
#   filter {
#     name   = "attachment.vpc-id"
#     values = [var.vpc_id]
#   }
# }

# # NAT Gateway requires an Elastic IP
# resource "aws_eip" "nat" {
#   domain = "vpc"
# }

# # NAT Gateway in the public subnet
# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = var.subnet_ids[0]
# }

# # Route table for private subnets (for Lambda)
# resource "aws_route_table" "private" {
#   vpc_id = var.vpc_id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.main.id
#   }
# }

# # Associate route table with Lambda's subnet
# resource "aws_route_table_association" "lambda_subnet" {
#   subnet_id      = var.subnet_ids[0]
#   route_table_id = aws_route_table.private.id
# }

# # First create networking components
# resource "aws_vpc_endpoint" "lambda" {
#   vpc_id             = var.vpc_id
#   service_name       = "com.amazonaws.${var.aws_region}.lambda"
#   vpc_endpoint_type  = "Interface"
#   subnet_ids         = var.subnet_ids
#   security_group_ids = [aws_security_group.lambda_sg.id]
# }

# resource "aws_vpc_endpoint" "sns" {
#   vpc_id             = var.vpc_id
#   service_name       = "com.amazonaws.${var.aws_region}.sns"
#   vpc_endpoint_type  = "Interface"
#   subnet_ids         = var.subnet_ids
#   security_group_ids = [aws_security_group.lambda_sg.id]
# }

# resource "aws_vpc_endpoint" "sqs" {
#   vpc_id             = var.vpc_id
#   service_name       = "com.amazonaws.${var.aws_region}.sqs"
#   vpc_endpoint_type  = "Interface"
#   subnet_ids         = var.subnet_ids
#   security_group_ids = [aws_security_group.lambda_sg.id]
# }

# resource "aws_vpc_endpoint" "logs" {
#   vpc_id             = var.vpc_id
#   service_name       = "com.amazonaws.${var.aws_region}.logs"
#   vpc_endpoint_type  = "Interface"
#   subnet_ids         = var.subnet_ids
#   security_group_ids = [aws_security_group.lambda_sg.id]
# }

# # Add CloudWatch Alarms for Lambda metrics
# resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
#   for_each = local.lambda_config

#   alarm_name          = "${each.key}-errors"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = local.shared_config.Monitoring.Alerts.LambdaErrors.EvaluationPeriods
#   metric_name         = "Errors"
#   namespace           = "AWS/Lambda"
#   period             = local.shared_config.Monitoring.Alerts.LambdaErrors.Period
#   statistic          = "Sum"
#   threshold          = local.shared_config.Monitoring.Alerts.LambdaErrors.Threshold
#   alarm_description  = "Lambda function error rate exceeded"
#   alarm_actions      = [aws_sns_topic.alerts.arn]

#   dimensions = {
#     FunctionName = aws_lambda_function.functions[each.key].function_name
#   }
# }

# resource "aws_lambda_function" "publish_to_sqs" {
#   function_name    = "PublishToSQS"
#   role             = aws_iam_role.service_role.arn
#   runtime          = "dotnet8"
#   handler          = "PublishToSQS::API.Lambdas.PublishToSQS.PublishToSQSHandler::FunctionHandler"
#   filename         = "../API/LambdaZips/PublishToSQS.zip"

#   environment {
#     variables = {
#       DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"
#       AWS__SqsQueueUrl = aws_sqs_queue.credit_card_queue.url
#     }
#   }

#   vpc_config {
#     subnet_ids         = var.subnet_ids
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }
# }

# # ==============================
# # 🔹 MONITORING & ALERTS
# # ==============================

# # Lambda Concurrent Executions
# resource "aws_cloudwatch_metric_alarm" "lambda_concurrency" {
#   for_each = local.lambda_config

#   alarm_name          = "${each.key}-concurrent-executions"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = local.shared_config.Monitoring.Alerts.LambdaConcurrency.EvaluationPeriods
#   metric_name         = "ConcurrentExecutions"
#   namespace           = "AWS/Lambda"
#   period             = local.shared_config.Monitoring.Alerts.LambdaConcurrency.Period
#   statistic          = "Maximum"
#   threshold          = local.shared_config.Monitoring.Alerts.LambdaConcurrency.Threshold
#   alarm_description  = "Lambda function concurrent executions too high"
#   alarm_actions      = [aws_sns_topic.alerts.arn]

#   dimensions = {
#     FunctionName = aws_lambda_function.functions[each.key].function_name
#   }
# }

# # Dead Letter Queue for each Lambda
# resource "aws_sqs_queue" "lambda_dlq" {
#   for_each = local.lambda_config

#   name                       = "${each.key}-dlq"
#   message_retention_seconds  = 1209600 # 14 days
#   visibility_timeout_seconds = 30
# }

# # DLQ Alarms
# resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
#   for_each = aws_sqs_queue.lambda_dlq

#   alarm_name          = "${each.key}-dlq-not-empty"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = local.shared_config.Monitoring.Alerts.DLQMessages.EvaluationPeriods
#   metric_name         = "ApproximateNumberOfMessagesVisible"
#   namespace           = "AWS/SQS"
#   period             = local.shared_config.Monitoring.Alerts.DLQMessages.Period
#   statistic          = "Maximum"
#   threshold          = local.shared_config.Monitoring.Alerts.DLQMessages.Threshold
#   alarm_description  = "Messages detected in DLQ"
#   alarm_actions      = [aws_sns_topic.alerts.arn]

#   dimensions = {
#     QueueName = each.value.name
#   }
# }

# # Alert Topic
# resource "aws_sns_topic" "alerts" {
#   name = "lambda-alerts"
# }

# # ==============================
# # 🔹 REDIS EC2 INSTANCE
# # ==============================

# # Create key pair for Redis instance
# resource "aws_key_pair" "redis" {
#   key_name   = "my-key-pair.pem"
#   public_key = fileexists("${path.module}/keys/redis.pub") ? file("${path.module}/keys/redis.pub") : ""

#   lifecycle {
#     precondition {
#       condition     = fileexists("${path.module}/keys/redis.pub")
#       error_message = "SSH public key file not found. Please run ./setup-keys.sh first."
#     }
#   }
# }

# # Elastic IP for Redis (existing)
# resource "aws_eip" "redis" {
#   # Remove instance association since we're importing existing
#   domain   = "vpc"
#   # The address will be set when we import
# }

# # Create an EC2 instance for Redis
# resource "aws_instance" "redis" {
#   ami           = var.redis_ami_id  # Ubuntu 20.04 LTS
#   instance_type = "t2.micro"        # From your appsettings.json
#   subnet_id     = var.subnet_ids[0]
#   key_name      = aws_key_pair.redis.key_name
  
#   vpc_security_group_ids = [aws_security_group.redis_sg.id]
  
#   user_data = <<-EOF
#               #!/bin/bash
              
#               # Update and install Redis
#               apt-get update
#               apt-get install -y redis-server

#               # Backup original config
#               cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

#               # Configure Redis
#               cat > /etc/redis/redis.conf <<EOL
#               bind 0.0.0.0
#               port ${var.redis_port}
#               requirepass ${var.redis_password}
#               maxmemory 256mb
#               maxmemory-policy allkeys-lru
#               appendonly yes
#               EOL

#               # Ensure Redis is enabled and started
#               systemctl enable redis-server
#               systemctl restart redis-server

#               # Add status check
#               if systemctl is-active --quiet redis-server; then
#                 echo "Redis successfully configured and running"
#               else
#                 echo "Redis failed to start" >&2
#                 exit 1
#               fi
#               EOF

#   tags = {
#     Name = "redis-server"
#   }

#   # Associate with existing elastic IP
#   lifecycle {
#     ignore_changes = [ebs_optimized]
#   }
# }

# # Associate the elastic IP with the instance
# resource "aws_eip_association" "redis" {
#   instance_id   = aws_instance.redis.id
#   allocation_id = aws_eip.redis.id
# }

# # Output connection details
# output "redis_ssh_command" {
#   value = "ssh -i keys/redis.pem ubuntu@${aws_eip.redis.public_ip}"
# }