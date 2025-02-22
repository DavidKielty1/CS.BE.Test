# ==============================
# 🔹 SECURITY GROUPS
# ==============================

# Get current IP address for SSH access
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# Redis security group
resource "aws_security_group" "redis_sg" {
  name_prefix = "redis-sg-"
  description = "Security group for Redis server"
  vpc_id      = var.vpc_id

  # Allow inbound Redis traffic from Lambda security group
  ingress {
    description     = "Allow Redis access from Lambda functions"
    security_groups = [aws_security_group.lambda_sg.id]
    protocol        = "tcp"
    from_port       = var.redis_port
    to_port         = var.redis_port
  }

  # Allow inbound Redis traffic from anywhere (for testing)
  ingress {
    description = "Redis access from development machine"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    protocol    = "tcp"
    from_port   = var.redis_port
    to_port     = var.redis_port
  }

  # Allow SSH access from current IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "SSH access from current IP"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================
# 🔹 REDIS EC2 INSTANCE
# ==============================

# SSH key pair for Redis instance
resource "aws_key_pair" "redis" {
  key_name   = "redis-key"
  public_key = fileexists("${path.module}/keys/redis.pub") ? file("${path.module}/keys/redis.pub") : ""

  lifecycle {
    precondition {
      condition     = fileexists("${path.module}/keys/redis.pub")
      error_message = "SSH public key file not found. Please run ./setup-keys.sh first."
    }
  }
}

# Elastic IP for Redis
resource "aws_eip" "redis" {
  domain = "vpc"
}

# Redis EC2 instance
resource "aws_instance" "redis" {
  ami           = var.redis_ami_id
  instance_type = "t2.micro"
  subnet_id     = var.subnet_ids[0]
  key_name      = aws_key_pair.redis.key_name
  
  vpc_security_group_ids = [aws_security_group.redis_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              
              # Update and install Redis
              apt-get update
              apt-get install -y redis-server

              # Backup original config
              cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

              # Configure Redis
              cat > /etc/redis/redis.conf <<EOL
              bind * -::*
              port ${var.redis_port}
              requirepass ${var.redis_password}
              maxmemory 256mb
              maxmemory-policy allkeys-lru
              appendonly yes
              protected-mode no
              tcp-keepalive 60
              timeout 300
EOL

              # Ensure Redis is enabled and started
              systemctl enable redis-server
              systemctl restart redis-server

              # Wait for Redis to start
              sleep 5
              
              # Verify Redis is running and accessible
              redis-cli -a "${var.redis_password}" ping
              
              # Add status check
              if systemctl is-active --quiet redis-server; then
                echo "Redis successfully configured and running"
              else
                echo "Redis failed to start" >&2
                exit 1
              fi
              EOF

  tags = {
    Name = "redis-server"
  }

  lifecycle {
    ignore_changes = [ebs_optimized]
  }
}

# Associate elastic IP with Redis instance
resource "aws_eip_association" "redis" {
  instance_id   = aws_instance.redis.id
  allocation_id = aws_eip.redis.id
}

# ==============================
# 🔹 MONITORING
# ==============================

# CloudWatch Alarm for DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "credit-card-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period             = "300"
  statistic          = "Average"
  threshold          = "0"
  alarm_description  = "This metric monitors DLQ for failed credit card requests"
  alarm_actions      = [aws_sns_topic.credit_card_topic.arn]

  dimensions = {
    QueueName = aws_sqs_queue.credit_card_dlq.name
  }
}

# ==============================
# 🔹 OUTPUTS
# ==============================

output "redis_ssh_command" {
  value = "ssh -i keys/redis ubuntu@${aws_eip.redis.public_ip}"
}