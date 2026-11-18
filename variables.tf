variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1" # Ireland — matches existing AWS account
}

variable "environment" {
  description = "Environment identifier: dev, staging, or prod"
  type        = string
  default     = "prod"

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
  description = "CIDR blocks for private data subnets — RDS PostgreSQL (2 AZs)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (true = cost-saving for dev, false = HA for prod)"
  type        = bool
  default     = false
}

# --- Database ---
variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "scancall_database"
}

variable "db_master_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "scancalladmin"
}

variable "db_master_password" {
  description = "Optional master password for RDS PostgreSQL. Leave empty to auto-generate a secure 24-character password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t4g.micro, db.t4g.small, db.t3.medium)"
  type        = string
  default     = "db.t4g.micro"
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
  description = "Optional domain name (e.g. scancalldev.protonestpcb.store or api.scancalldev.protonestpcb.store)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "Optional pre-existing ACM Certificate ARN. If set, ALB HTTPS listener attaches directly to it without creating/validating a new cert in Route 53."
  type        = string
  default     = ""
}

variable "redirect_http_to_https" {
  description = "Redirect HTTP:80 to HTTPS:443 (recommended true for production)"
  type        = bool
  default     = true
}

variable "livekit_url" {
  description = "Optional custom LiveKit WebSocket URL (e.g. wss://media.scancalldev.protonestpcb.store). If empty, auto-derived from domain or EIP."
  type        = string
  default     = ""
}

# --- Application Configuration ---
variable "cors_allowed_origins" {
  description = "Comma-separated list of allowed CORS origins"
  type        = string
  default     = "http://localhost:3000,https://scancall.vercel.app,https://dev-s.d24yfw60t6z2zl.amplifyapp.com,https://dev-s.d2j3adjr6nsyxs.amplifyapp.com,https://dev-s.d4cyjimayhwag.amplifyapp.com"
}

variable "admin_frontend_url" {
  description = "Admin frontend URL"
  type        = string
  default     = "https://dev-s.d24yfw60t6z2zl.amplifyapp.com"
}

variable "frontend_url" {
  description = "User frontend URL"
  type        = string
  default     = "https://dev-s.d24yfw60t6z2zl.amplifyapp.com"
}

variable "super_admin_frontend_url" {
  description = "Super admin frontend URL"
  type        = string
  default     = "https://dev-s.d4cyjimayhwag.amplifyapp.com"
}

variable "mail_from" {
  description = "From email address for system emails"
  type        = string
  default     = "Scancall@entryphone.co.uk"
}

variable "mail_from_name" {
  description = "From email display name"
  type        = string
  default     = "ScanCall"
}

variable "relay_api_url" {
  description = "Relay controller endpoint URL"
  type        = string
  default     = "https://ops.entryphone.co.uk/ScanCall/mqtt/api/v1/trigger_relay.aspx"
}

variable "sms_api_url" {
  description = "SMS provider endpoint URL"
  type        = string
  default     = "https://ops.entryphone.co.uk/sms/api/v1/send_sms.aspx"
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
