terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Uncomment and configure to use an S3 remote backend for shared state
  # backend "s3" {
  #   bucket         = "scancall-terraform-state-<YOUR_ACCOUNT_ID>"
  #   key            = "scancall/<ENV>/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "scancall-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ScanCall"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# Locals: environment-aware sizing and shared service names
# ---------------------------------------------------------------------------
locals {
  service_names = ["api-gateway", "core-service", "call-service"]

  is_dev     = var.environment == "dev"
  is_staging = var.environment == "staging"
  is_prod    = var.environment == "prod"

  # ECS desired task counts per environment
  desired_count = {
    dev     = 1
    staging = 1
    prod    = 2
  }

  # ECS CPU per environment (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)
  ecs_cpu = {
    dev     = { api_gateway = 256, core_service = 512, call_service = 512 }
    staging = { api_gateway = 256, core_service = 512, call_service = 512 }
    prod    = { api_gateway = 512, core_service = 1024, call_service = 1024 }
  }

  # ECS Memory per environment (MB)
  ecs_memory = {
    dev     = { api_gateway = 512, core_service = 1024, call_service = 1024 }
    staging = { api_gateway = 512, core_service = 1024, call_service = 1024 }
    prod    = { api_gateway = 1024, core_service = 2048, call_service = 2048 }
  }

  # Standard RDS instance class per environment
  rds_instance_class = {
    dev     = "db.t4g.micro"
    staging = "db.t4g.small"
    prod    = "db.t3.medium"
  }

  # Redis node type per environment
  redis_node_type = {
    dev     = "cache.t4g.micro"
    staging = "cache.t4g.small"
    prod    = "cache.t4g.medium"
  }

  # LiveKit EC2 instance type per environment
  livekit_instance_type = {
    dev     = "t3.small"
    staging = "t3.medium"
    prod    = "t3.large"
  }
}
