# ==============================
# 🔹 REQUIRED VARIABLES
# ==============================

variable "aws_region" {
  description = "AWS Region for resource deployment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda deployment"
  type        = list(string)
  default     = ["subnet-098b8b06b31a1ec4c"]  # Use only the subnet with NAT Gateway route
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# ==============================
# 🔹 AWS SERVICE VARIABLES
# ==============================

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "CreditCardWorkflow"
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue"
  type        = string
}

variable "redis_host" {
  description = "Redis host address"
  type        = string
}

variable "redis_connection_string" {
  description = "Full Redis connection string"
  type        = string
}

# ==============================
# 🔹 REDIS VARIABLES
# ==============================

variable "redis_ami_id" {
  description = "AMI ID for Redis EC2 instance"
  type        = string
}

variable "redis_instance_type" {
  description = "Instance type for Redis EC2"
  type        = string
  default     = "t2.micro"
}

variable "redis_port" {
  description = "Port number for Redis server"
  type        = number
  default     = 6379
}

variable "redis_password" {
  description = "Password for Redis authentication"
  type        = string
  sensitive   = true
}

# ==============================
# 🔹 API ENDPOINTS
# ==============================

variable "cs_cards_endpoint" {
  description = "ClearScore cards API endpoint"
  type        = string
  default     = "https://api.clearscore.com/api/global/backend-tech-test/v1/cards"
}

variable "scored_cards_endpoint" {
  description = "Scored cards API endpoint"
  type        = string
  default     = "https://api.clearscore.com/api/global/backend-tech-test/v2/creditcards"
}

variable "public_subnet_id" {
  description = "Subnet ID for NAT Gateway (must be a public subnet)"
  type        = string
  default     = "subnet-077a487bc315c0e7e"  # Use subnet with IGW route
} 