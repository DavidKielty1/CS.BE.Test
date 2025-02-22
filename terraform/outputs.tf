output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = var.vpc_id
}

output "subnet_ids" {
  value = var.subnet_ids
}

output "security_group_ids" {
  value = var.security_group_ids
}

output "redis_host" {
  value = aws_instance.redis.private_ip
}

output "redis_port" {
  value = var.redis_port
}

output "redis_password" {
  value = var.redis_password
  sensitive = true
}

output "redis_connection_string" {
  value = var.redis_connection_string
  sensitive = true
}

output "cs_cards_endpoint" {
  value = var.cs_cards_endpoint
}

output "scored_cards_endpoint" {
  value = var.scored_cards_endpoint
}

output "sns_topic_arn" {
  value = aws_sns_topic.credit_card_topic.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.credit_card_queue.url
}

output "lambda_role_arn" {
  value = aws_iam_role.service_role.arn
}

output "lambda_sg_id" {
  value = aws_security_group.lambda_sg.id
}

output "lambda_environment_FetchCreditCards" {
  value = join(",", [for k, v in local.lambda_environment.fetch_cards : "${k}=${v}"])
}

output "lambda_environment_publish_sqs" {
  value = try(
    join(",", [for k, v in local.lambda_environment.publish_sqs : "${k}=${v}"]),
    "environment not configured"
  )
}
