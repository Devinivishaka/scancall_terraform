# Random Database Password
resource "random_password" "db_master_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Random JWT Secret
resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# Random Internal API Key (Shared between API Gateway, Core, and Call Service)
resource "random_password" "internal_api_key" {
  length  = 32
  special = false
}

# Random LiveKit API Key & Secret
resource "random_string" "livekit_api_key" {
  length  = 16
  special = false
}

resource "random_password" "livekit_api_secret" {
  length  = 48
  special = false
}

# Database Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/db-credentials-${var.environment}"
  description             = "Database master credentials for Aurora PostgreSQL"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-db-credentials-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master_password.result
    dbname   = var.db_name
    engine   = "postgres"
    port     = 5432
    host     = aws_db_instance.postgres.endpoint
  })
}

# Application Secrets Manager Secret
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}/app-secrets-${var.environment}"
  description             = "Application secrets for ScanCall backend services"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-app-secrets-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    jwt_secret         = random_password.jwt_secret.result
    internal_api_key   = random_password.internal_api_key.result
    livekit_api_key    = random_string.livekit_api_key.result
    livekit_api_secret = random_password.livekit_api_secret.result
  })
}
