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

  # Sticky sessions — needed for WebSocket connections
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
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
# When a domain is configured: redirects to HTTPS
# When no domain:              forwards directly to API Gateway target group
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.domain_name != "" ? "redirect" : "forward"

    # Redirect block — only present when domain is set
    dynamic "redirect" {
      for_each = var.domain_name != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # Forward — only set when there is NO redirect (null is valid when type = redirect)
    target_group_arn = var.domain_name != "" ? null : aws_lb_target_group.api_gateway.arn
  }
}

# ---------------------------------------------------------------------------
# Optional: HTTPS Listener + ACM Certificate + Route 53 record
# Only created when var.domain_name is non-empty
# ---------------------------------------------------------------------------
data "aws_route53_zone" "selected" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert-${var.environment}"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected[0].zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_lb_listener" "https" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.cert[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

resource "aws_route53_record" "alb_alias" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
