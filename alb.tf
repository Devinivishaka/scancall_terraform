# ---------------------------------------------------------------------------
# Application Load Balancer (Public Subnets — internet-facing)
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  # Max 32 chars for ALB name
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Disable for dev/staging so terraform destroy doesn't fail; enable for prod
  enable_deletion_protection = local.is_prod

  tags = {
    Name = "${var.project_name}-alb-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# Target Group: API Gateway ECS Tasks (Port 8000)
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "api_gateway" {
  # Max 32 chars: "scancall-apigw-tg-dev" = 21 chars ✓
  name        = "${var.project_name}-apigw-tg-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  # Sticky sessions — disabled in live system to ensure even load distribution
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-apigw-tg-${var.environment}"
  }

  # Allow graceful replacement when TG properties change
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# HTTP Listener (Port 80)
# Default action: forwards directly to API Gateway target group (matches dev)
# Can optionally be set to redirect to HTTPS:443 via var.redirect_http_to_https
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.redirect_http_to_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.redirect_http_to_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.redirect_http_to_https ? null : aws_lb_target_group.api_gateway.arn
  }
}

# ---------------------------------------------------------------------------
# HTTPS Listener (Port 443)
# Enabled when var.certificate_arn is provided
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}
