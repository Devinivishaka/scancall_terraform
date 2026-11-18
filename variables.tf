variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1" # Ireland — matches existing AWS account
}

variable "environment" {
  description = "Environment identifier: dev, staging, or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Name prefix for all resources (keep short — max 12 chars)"
  type        = string
  default     = "scancall"
}

# --- VPC ---
variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (2 AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private ECS subnets (2 AZs)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets — Aurora & Redis (2 AZs)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (true = cost-saving for dev, false = HA for prod)"
  type        = bool
  default     = true
}

# --- Database ---
variable "db_name" {
  description = "Aurora PostgreSQL database name"
  type        = string
  default     = "scancall_phase1"
}

variable "db_master_username" {
  description = "Aurora PostgreSQL master username"
  type        = string
  default     = "scancalladmin"
}

# --- SSH Key ---
variable "ssh_public_key" {
  description = "Optional SSH public key for the LiveKit EC2 instance. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

# --- Domain & SSL ---
variable "domain_name" {
  description = "Optional Route53 domain name (e.g. api.yourdomain.com). Leave empty to use plain HTTP ALB."
  type        = string
  default     = ""
}

# --- WAF ---
variable "enable_waf" {
  description = "Enable AWS WAFv2 on the Application Load Balancer (recommended for staging & prod)"
  type        = bool
  default     = false
}

# --- Application Secrets (Leave empty to use defaults/auto-generation or manage via Secrets Manager) ---
variable "internal_api_key" {
  description = "Shared internal API key across services. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "livekit_api_key" {
  description = "LiveKit API key. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "livekit_api_secret" {
  description = "LiveKit API secret. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "service_account_path" {
  description = "Firebase Service Account JSON string for push notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apns_auth_key" {
  description = "Apple Push Notification private auth key (.p8 format)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apns_team_id" {
  description = "Apple Developer Team ID for APNs"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apns_key_id" {
  description = "Apple Push Notification Key ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apns_bundle_id" {
  description = "Apple App Bundle ID"
  type        = string
  default     = "com.protonest.scancall"
}

variable "apns_host" {
  description = "Apple Push Notification Service Host URL"
  type        = string
  default     = "https://api.push.apple.com"
}

variable "app_aws_access_key" {
  description = "AWS Access Key ID used by backend application"
  type        = string
  default     = ""
  sensitive   = true
}

variable "app_aws_secret_key" {
  description = "AWS Secret Access Key used by backend application"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sms_api_key" {
  description = "SMS provider API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "relay_api_key" {
  description = "Relay webhook / service API key"
  type        = string
  default     = ""
  sensitive   = true
}
