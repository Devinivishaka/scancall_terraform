# DB Subnet Group for RDS (Private Data Subnets)
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-postgres-subnet-group-${var.environment}"
  description = "PostgreSQL subnet group - private data subnets"
  subnet_ids  = aws_subnet.private_data[*].id

  tags = {
    Name = "${var.project_name}-postgres-subnet-group-${var.environment}"
  }
}

# Standard RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-postgres-${var.environment}"
  engine                 = "postgres"
  engine_version         = "18"
  instance_class         = local.rds_instance_class[var.environment]
  
  # Storage
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true

  # Credentials & Networking
  db_name                = var.db_name
  username               = var.db_master_username
  password               = var.db_master_password != "" ? var.db_master_password : random_password.db_master_password.result
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Backups
  backup_retention_period = local.is_prod ? 7 : 1
  backup_window           = "02:00-03:00"

  # Safety: skip final snapshot on dev/staging to allow clean destroy
  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "${var.project_name}-postgres-final-snapshot-${var.environment}" : null
  deletion_protection       = local.is_prod

  # Only apply changes during maintenance window unless immediate is needed
  apply_immediately = true

  tags = {
    Name = "${var.project_name}-postgres-${var.environment}"
  }

  lifecycle {
    # Prevent accidental replacement of the DB when password changes
    ignore_changes = [password]
  }
}
