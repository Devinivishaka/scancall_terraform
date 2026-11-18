# AWS WAFv2 Web ACL (Optional, enabled via var.enable_waf)
resource "aws_wafv2_web_acl" "alb" {
  count       = var.enable_waf ? 1 : 0
  name        = "${var.project_name}-waf-${var.environment}"
  description = "WAF protection for ScanCall Application Load Balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ScanCallCommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit1000"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ScanCallRateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-waf-${var.environment}"
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn
}
