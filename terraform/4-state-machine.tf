# ==============================
# 🔹 SHARED RESOURCES
# ==============================

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ==============================
# 🔹 STATE MACHINE DEFINITION
# ==============================

locals {
  # State machine definition with Lambda ARNs
  state_machine_definition = {
    Comment = "Step function for processing credit card recommendations"
    StartAt = "FetchCreditCards"
    States = {
      FetchCreditCards = {
        Type = "Task"
        Resource = aws_lambda_function.functions["FetchCreditCards"].arn
        Next = "NormalizeCreditCardData"
        ResultPath = "$.fetchedCards"
        TimeoutSeconds = 60
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath = "$.error"
          Next = "ProcessFailedRequests"
        }]
      }
      NormalizeCreditCardData = {
        Type = "Task"
        Resource = aws_lambda_function.functions["NormalizeCreditCardData"].arn
        Next = "StoreInRedis"
        Parameters = {
          "cards": {
            "cards.$": "$.fetchedCards"
          }
        }
        ResultPath = "$.normalizedCards"
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath = "$.error"
          Next = "ProcessFailedRequests"
        }]
      }
      StoreInRedis = {
        Type = "Task"
        Resource = aws_lambda_function.functions["StoreInRedis"].arn
        Next = "PublishToSNS"
        Parameters = {
          "cards.$": "$.normalizedCards",
          "request.$": "$$.Execution.Input"
        }
        ResultPath = "$.redisResult"
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath = "$.error"
          Next = "ProcessFailedRequests"
        }]
      }
      PublishToSNS = {
        Type = "Task"
        Resource = aws_lambda_function.functions["PublishToSNS"].arn
        Next = "PublishToSQS"
        Parameters = {
          "cards.$": "$.normalizedCards",
          "request.$": "$$.Execution.Input",
          "notificationType": "SUCCESS",
          "message": "Credit card processing completed successfully"
        }
        ResultPath = "$.snsResult"
        Retry = [{
          ErrorEquals = ["States.ALL"]
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath = "$.error"
          Next = "ProcessFailedRequests"
        }]
      }
      PublishToSQS = {
        Type = "Task"
        Resource = aws_lambda_function.functions["PublishToSQS"].arn
        End = true
        Parameters = {
          "messageBody": {
            "cards.$": "$.normalizedCards",
            "request.$": "$$.Execution.Input"
          }
        }
        ResultPath = "$.sqsResult"
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath = "$.error"
          Next = "ProcessFailedRequests"
        }]
      }
      ProcessFailedRequests = {
        Type = "Task"
        Resource = aws_lambda_function.functions["ProcessFailedRequests"].arn
        End = true
        Parameters = {
          "error.$": "$.error",
          "request.$": "$$.Execution.Input"
        }
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts = 2
          BackoffRate = 2.0
        }]
      }
    }
  }
}

# ==============================
# 🔹 STATE MACHINE RESOURCES
# ==============================

# Comment out if the state machine is already created and you're just updating Lambdas
# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "stepfunction_logs" {
  name              = "/aws/states/${replace(var.state_machine_name, " ", "_")}"
  retention_in_days = 14
}

# Add data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Main state machine
# Comment out if the state machine is already created and you're just updating Lambdas
resource "aws_sfn_state_machine" "credit_card_workflow" {
  name     = "CreditCardWorkflow"
  role_arn = aws_iam_role.service_role.arn
  
  definition = jsonencode(local.state_machine_definition)

  logging_configuration {
    log_destination        = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/states/CreditCardWorkflow:*"
    include_execution_data = true
    level                 = "ALL"
  }

  depends_on = [
    aws_sqs_queue.credit_card_queue,
    aws_sns_topic.credit_card_topic,
    aws_instance.redis,
    aws_cloudwatch_log_group.stepfunction_logs
  ]

  tags = {
    Name = "CreditCardWorkflow"
    Environment = "Production"
  }
}

# ==============================
# 🔹 OUTPUTS
# ==============================

output "state_machine_arn" {
  value       = aws_sfn_state_machine.credit_card_workflow.arn
  description = "ARN of the Step Functions state machine"
}
