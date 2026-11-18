output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Application Load Balancer public DNS hostname"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the API Gateway (via ALB)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_urls" {
  description = "Map of service name => ECR image repository URL"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "postgres_endpoint" {
  description = "Standard RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_database_name" {
  description = "Standard RDS PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis hostname"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "secrets_db_credentials_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secrets_app_secrets_arn" {
  description = "ARN of the Secrets Manager secret for app secrets (JWT, API keys, LiveKit)"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "db_password" {
  description = "Aurora PostgreSQL database master password (sensitive)"
  value       = random_password.db_master_password.result
  sensitive   = true
}

output "livekit_public_ip" {
  description = "LiveKit EC2 Elastic Public IP"
  value       = aws_eip.livekit.public_ip
}

output "livekit_wss_url" {
  description = "LiveKit WebSocket URL for the Call Service (LIVEKIT_URL)"
  value       = var.livekit_url != "" ? var.livekit_url : (var.domain_name != "" ? "wss://media.${var.domain_name}" : "ws://${aws_eip.livekit.public_ip}:7880")
}

output "livekit_ssh_command" {
  description = "SSH command to access the LiveKit EC2 VM"
  value       = "ssh -i terraform/scancall-livekit-key.pem ubuntu@${aws_eip.livekit.public_ip}"
}

output "livekit_private_key_file" {
  description = "Path to the generated SSH private key file (auto-generated only)"
  value       = var.ssh_public_key == "" ? "${path.module}/scancall-livekit-key.pem" : "User-supplied key — no file saved"
  sensitive   = true
}

