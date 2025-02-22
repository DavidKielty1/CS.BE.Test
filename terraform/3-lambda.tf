# ==============================
# 🔹 LAMBDA CONFIGURATIONS
# ==============================

locals {
  lambda_config = {
    FetchCreditCards = {
      handler     = "FetchCreditCards::API.Lambdas.FetchCreditCards.FetchCreditCardsHandler::FunctionHandler"
      memory_size = 512
      timeout     = 60
      environment = local.lambda_environment.fetch_cards
    }

    NormalizeCreditCardData = {
      handler     = "NormalizeCreditCardData::API.Lambdas.NormalizeCreditCardData.NormalizeCreditCardDataHandler::FunctionHandler"
      memory_size = 256
      timeout     = 30
      environment = local.lambda_environment.fetch_cards
    }

    StoreInRedis = {
      handler = "StoreInRedis::API.Lambdas.StoreInRedis.StoreInRedisHandler::FunctionHandler"
      memory_size = 256
      timeout = 30
      environment = local.lambda_environment.store_redis
    }

    PublishToSNS = {
      handler = "PublishToSNS::API.Lambdas.PublishToSNS.PublishToSNSHandler::FunctionHandler"
      memory_size = 256
      timeout = 30
      environment = local.lambda_environment.publish_sns
    }

    PublishToSQS = {
      handler = "PublishToSQS::API.Lambdas.PublishToSQS.PublishToSQSHandler::FunctionHandler"
      memory_size = 256
      timeout = 30
      environment = local.lambda_environment.publish_sqs
    }

    ProcessFailedRequests = {
      handler = "ProcessFailedRequests::API.Lambdas.ProcessFailedRequests.ProcessFailedRequestsHandler::FunctionHandler"
      memory_size = 256
      timeout = 30
      environment = local.lambda_environment.fetch_cards
    }
  }

  # Common Lambda environment variables
  lambda_environment = {
    fetch_cards = merge(local.lambda_base_environment, {
      AWS__Region = var.aws_region
      CSCARDS_ENDPOINT = var.cs_cards_endpoint
      SCOREDCARDS_ENDPOINT = var.scored_cards_endpoint
    })
    
    store_redis = merge(local.lambda_base_environment, {
      AWS__Region = var.aws_region
      REDIS__HOST = aws_instance.redis.private_ip
      REDIS__PORT = var.redis_port
      REDIS__PASSWORD = var.redis_password
    })
    
    publish_sns = merge(local.lambda_base_environment, {
      AWS__Region = var.aws_region
      AWS__SNSTOPICARN = aws_sns_topic.credit_card_topic.arn
    })
    
    publish_sqs = merge(local.lambda_base_environment, {
      AWS__Region = var.aws_region
      AWS__SQSQUEUEURL = aws_sqs_queue.credit_card_queue.url
    })
  }
}

# ==============================
# 🔹 MESSAGING QUEUES
# ==============================

# Comment out if queues are already created
resource "aws_sqs_queue" "credit_card_dlq" {
  name = "CreditCardProcessingDLQ"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "failed_requests" {
  name                       = "FailedRequestsQueue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.credit_card_dlq.arn
    maxReceiveCount     = 2
  })
}

resource "aws_sqs_queue" "credit_card_queue" {
  name                       = "CreditCardProcessingQueue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.credit_card_dlq.arn
    maxReceiveCount     = 2
  })
}

# ==============================
# 🔹 SNS TOPIC
# ==============================

# Comment out if SNS topic is already created
resource "aws_sns_topic" "credit_card_topic" {
  name = "CreditCardNotifications"
}

# Create Lambda functions
resource "aws_lambda_function" "functions" {
  for_each = local.lambda_config

  filename         = "dist/${each.key}.zip"
  function_name    = each.key
  role            = aws_iam_role.service_role.arn
  handler         = each.value.handler
  runtime         = "dotnet8"
  memory_size     = each.value.memory_size
  timeout         = each.value.timeout

  environment {
    variables = each.value.environment
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_iam_role_policy.unified_policy,
    aws_security_group.lambda_sg,
    aws_nat_gateway.main  # Make sure NAT Gateway is ready
  ]
}

# CloudWatch Log groups for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.lambda_config

  name              = "/aws/lambda/${each.key}"
  retention_in_days = 14
}

# SNS Topic subscription now references the resource instead of data source
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.credit_card_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.functions["StoreInRedis"].arn
}

resource "aws_lambda_permission" "allow_sns_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["StoreInRedis"].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.credit_card_topic.arn
}

# Comment out if DLQs are already created
resource "aws_sqs_queue" "lambda_dlq" {
  for_each = local.lambda_config
  name                       = "${each.key}-dlq"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 30
}

