# 1. Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Security group for external Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}

# 2. API Gateway ECS Security Group
resource "aws_security_group" "api_gateway" {
  name        = "${var.project_name}-api-gateway-sg-${var.environment}"
  description = "Security group for API Gateway ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Inbound from ALB on port 8000"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-api-gateway-sg-${var.environment}"
  }
}

# 3. Calling Service ECS Security Group
resource "aws_security_group" "call_service" {
  name        = "${var.project_name}-call-service-sg-${var.environment}"
  description = "Security group for Calling Service ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Inbound from API Gateway on port 8081"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-call-service-sg-${var.environment}"
  }
}

# 4. Core Service ECS Security Group
resource "aws_security_group" "core_service" {
  name        = "${var.project_name}-core-service-sg-${var.environment}"
  description = "Security group for Core Service ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Inbound from API Gateway on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  ingress {
    description     = "Inbound from Calling Service on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.call_service.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-core-service-sg-${var.environment}"
  }
}

# 5. Aurora PostgreSQL Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg-${var.environment}"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL port from Core Service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.core_service.id]
  }

  ingress {
    description     = "PostgreSQL port from Calling Service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.call_service.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg-${var.environment}"
  }
}

# 6. ElastiCache Redis Security Group
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg-${var.environment}"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis port from API Gateway (Rate Limiting)"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  ingress {
    description     = "Redis port from Calling Service"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.call_service.id]
  }

  ingress {
    description     = "Redis port from Core Service"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.core_service.id]
  }

  tags = {
    Name = "${var.project_name}-redis-sg-${var.environment}"
  }
}

# 7. LiveKit EC2 Security Group
resource "aws_security_group" "livekit" {
  name        = "${var.project_name}-livekit-sg-${var.environment}"
  description = "Security group for LiveKit WebRTC media server EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LiveKit HTTP / WebSocket Signaling"
    from_port   = 7880
    to_port     = 7880
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LiveKit RTC over TCP"
    from_port   = 7881
    to_port     = 7881
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LiveKit TURN over TLS"
    from_port   = 7882
    to_port     = 7882
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LiveKit TURN over UDP"
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LiveKit WebRTC UDP media ICE range"
    from_port   = 50000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-livekit-sg-${var.environment}"
  }
}
