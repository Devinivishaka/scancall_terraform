# ---------------------------------------------------------------------------
# 1. API GATEWAY ECS SERVICE
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.project_name}-api-gateway-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(local.ecs_cpu[var.environment].api_gateway)
  memory                   = tostring(local.ecs_memory[var.environment].api_gateway)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-gateway"
      image     = "${aws_ecr_repository.services["api-gateway"].repository_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8000, hostPort = 8000, protocol = "tcp" }
      ]

      environment = [
        { name = "SERVER_PORT",          value = "8000" },
        { name = "CORE_SERVICE_URL",     value = "http://core-service.${aws_service_discovery_private_dns_namespace.internal.name}:8080" },
        { name = "CALLING_SERVICE_URL",  value = "http://call-service.${aws_service_discovery_private_dns_namespace.internal.name}:8081" },
        { name = "CORS_ALLOWED_ORIGINS", value = var.cors_allowed_origins }
      ]

      secrets = [
        { name = "INTERNAL_API_KEY", valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:internal_api_key::" },
        { name = "JWT_SECRET",       valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_secret::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["api-gateway"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "gateway"
        }
      }

      # Simple container health check
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-api-gateway-task-${var.environment}"
  }
}

resource "aws_ecs_service" "api_gateway" {
  name            = "${var.project_name}-api-gateway-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = local.desired_count[var.environment]
  launch_type     = "FARGATE"

  # Allow Terraform to update the service without waiting for tasks to drain
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private_app[*].id
    security_groups  = [aws_security_group.api_gateway.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_standard,
    aws_iam_role_policy_attachment.ecs_secrets_attach,
  ]

  tags = {
    Name = "${var.project_name}-api-gateway-service-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# 2. CORE SERVICE ECS SERVICE
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "core_service" {
  family                   = "${var.project_name}-core-service-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(local.ecs_cpu[var.environment].core_service)
  memory                   = tostring(local.ecs_memory[var.environment].core_service)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "core-service"
      image     = "${aws_ecr_repository.services["core-service"].repository_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8080, hostPort = 8080, protocol = "tcp" }
      ]

      environment = [
        { name = "SERVER_PORT",               value = "8080" },
        { name = "SPRING_DATASOURCE_URL",     value = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_master_username },
        { name = "SPRING_JPA_DDL_AUTO",       value = var.environment == "prod" ? "validate" : "update" },
        { name = "CALL_SERVICE_URL",          value = "http://call-service.${aws_service_discovery_private_dns_namespace.internal.name}:8081" },
        { name = "APP_BASE_URL",              value = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}" },
        { name = "WEBSOCKET_URL",             value = var.domain_name != "" ? "wss://${var.domain_name}/ws" : "ws://${aws_lb.main.dns_name}/ws" },
        { name = "AWS_REGION",                value = var.aws_region },
        { name = "ADMIN_FRONTEND_URL",        value = var.admin_frontend_url },
        { name = "FRONTEND_URL",              value = var.frontend_url },
        { name = "SUPER_ADMIN_FRONTEND_URL",  value = var.super_admin_frontend_url },
        { name = "JWT_EXPIRATION",            value = "21600000" },
        { name = "JWT_REFRESH_EXPIRATION",    value = "7776000000" },
        { name = "MAIL_FROM",                 value = var.mail_from },
        { name = "MAIL_FROM_NAME",            value = var.mail_from_name },
        { name = "RELAY_API_URL",             value = var.relay_api_url },
        { name = "SMS_API_URL",               value = var.sms_api_url }
      ]

      secrets = [
        { name = "SPRING_DATASOURCE_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" },
        { name = "JWT_SECRET",                 valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_secret::" },
        { name = "INTERNAL_API_KEY",           valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:internal_api_key::" },
        { name = "AWS_ACCESS_KEY",             valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:AWS_ACCESS_KEY::" },
        { name = "AWS_SECRET_KEY",             valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:AWS_SECRET_KEY::" },
        { name = "RELAY_API_KEY",              valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:RELAY_API_KEY::" },
        { name = "SMS_API_KEY",                valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:SMS_API_KEY::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["core-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "core"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8080/swagger-ui/index.html || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 90
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-core-service-task-${var.environment}"
  }
}

resource "aws_ecs_service" "core_service" {
  name            = "${var.project_name}-core-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.core_service.arn
  desired_count   = local.desired_count[var.environment]
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private_app[*].id
    security_groups  = [aws_security_group.core_service.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.core_service.arn
  }

  depends_on = [
    aws_db_instance.postgres,
    aws_iam_role_policy_attachment.ecs_execution_standard,
    aws_iam_role_policy_attachment.ecs_secrets_attach,
  ]

  tags = {
    Name = "${var.project_name}-core-service-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# 3. CALLING SERVICE ECS SERVICE
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "call_service" {
  family                   = "${var.project_name}-call-service-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(local.ecs_cpu[var.environment].call_service)
  memory                   = tostring(local.ecs_memory[var.environment].call_service)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "call-service"
      image     = "${aws_ecr_repository.services["call-service"].repository_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8081, hostPort = 8081, protocol = "tcp" }
      ]

      environment = [
        { name = "PORT",                            value = "8081" },
        { name = "CORE_SERVICE_URL",                value = "http://core-service.${aws_service_discovery_private_dns_namespace.internal.name}:8080" },
        { name = "LIVEKIT_URL",                     value = var.livekit_url != "" ? var.livekit_url : (var.domain_name != "" ? "wss://media.${var.domain_name}" : "ws://${aws_eip.livekit.public_ip}:7880") },
        { name = "WS_PATH",                         value = "/ws" },
        { name = "ACTIVE_CALL_DISCONNECT_GRACE_MS", value = "30000" },
        { name = "CALL_DELIVERY_TIMEOUT_MS",        value = "30000" },
        { name = "CALL_RING_TIMEOUT_MS",            value = "30000" },
        { name = "WS_PING_INTERVAL_MS",             value = "2000" },
        { name = "WS_PONG_TIMEOUT_MS",              value = "2000" },
        { name = "APNS_IP_FAMILY",                  value = "4" },
        { name = "SPRING_DATASOURCE_URL",           value = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME",      value = var.db_master_username }
      ]

      secrets = [
        { name = "INTERNAL_API_KEY",           valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:internal_api_key::" },
        { name = "LIVEKIT_API_KEY",            valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:livekit_api_key::" },
        { name = "LIVEKIT_API_SECRET",         valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:livekit_api_secret::" },
        { name = "SERVICE_ACCOUNT_PATH",       valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:SERVICE_ACCOUNT_PATH::" },
        { name = "APNS_AUTH_KEY",              valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APNS_AUTH_KEY::" },
        { name = "APNS_BUNDLE_ID",             valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APNS_BUNDLE_ID::" },
        { name = "APNS_HOST",                  valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APNS_HOST::" },
        { name = "APNS_KEY_ID",                valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APNS_KEY_ID::" },
        { name = "APNS_TEAM_ID",               valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APNS_TEAM_ID::" },
        { name = "SPRING_DATASOURCE_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["call-service"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "call"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8081/swagger-ui/index.html || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-call-service-task-${var.environment}"
  }
}

resource "aws_ecs_service" "call_service" {
  name            = "${var.project_name}-call-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.call_service.arn
  desired_count   = local.desired_count[var.environment]
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private_app[*].id
    security_groups  = [aws_security_group.call_service.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.call_service.arn
  }

  depends_on = [
    aws_instance.livekit,
    aws_db_instance.postgres,
    aws_iam_role_policy_attachment.ecs_execution_standard,
    aws_iam_role_policy_attachment.ecs_secrets_attach,
  ]

  tags = {
    Name = "${var.project_name}-call-service-${var.environment}"
  }
}
