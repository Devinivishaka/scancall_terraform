# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster-${var.environment}"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Groups — one per service
resource "aws_cloudwatch_log_group" "ecs" {
  for_each = toset(local.service_names)
  name     = "/ecs/${var.project_name}-${each.key}-${var.environment}"

  # Shorter retention on dev/staging, longer on prod
  retention_in_days = local.is_prod ? 90 : 30

  tags = {
    Name    = "/ecs/${var.project_name}-${each.key}-${var.environment}"
    Service = each.key
  }
}

# AWS Cloud Map Private DNS Namespace — microservice-to-microservice communication
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "${var.project_name}-${var.environment}.local"
  description = "Private DNS for ScanCall ${var.environment} microservices"
  vpc         = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}.local"
  }
}

# Service Discovery: core-service.scancall-dev.local
resource "aws_service_discovery_service" "core_service" {
  name         = "core-service"
  namespace_id = aws_service_discovery_private_dns_namespace.internal.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-core-service-sd-${var.environment}"
  }
}

# Service Discovery: call-service.scancall-dev.local
resource "aws_service_discovery_service" "call_service" {
  name         = "call-service"
  namespace_id = aws_service_discovery_private_dns_namespace.internal.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-call-service-sd-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# IAM: ECS Task Execution Role — used by AWS to pull images & fetch secrets
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS execution role to read both secrets
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.project_name}-ecs-secrets-${var.environment}"
  description = "Allow ECS execution role to read Secrets Manager secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        aws_secretsmanager_secret.db_credentials.arn,
        aws_secretsmanager_secret.app_secrets.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

# ---------------------------------------------------------------------------
# IAM: ECS Task Role — used by the running container application
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Allow containers to send emails via SES
resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.project_name}-ecs-task-policy-${var.environment}"
  description = "Allow ECS tasks to use SES for email delivery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}
