variable "name" {
  description = "Base name for the DB resources (DB instance, SG, subnet group)."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version (major.minor)."
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "RDS instance class (e.g., db.t4g.medium)."
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Autoscaling storage maximum in GB (0 to disable)."
  type        = number
  default     = 200
}

variable "storage_type" {
  description = "Storage type for RDS (gp2|gp3|io1)."
  type        = string
  default     = "gp3"
}

variable "publicly_accessible" {
  description = "Whether the instance is publicly accessible (should be false)."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Initial database name to create."
  type        = string
  default     = "app"
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "appuser"
}

variable "password" {
  description = "Master password. If null and create_random_password = true, a random password will be generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_name" {
  description = "Optional custom name for the Secrets Manager secret. If null, a name is derived from var.name."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for storage encryption (defaults to AWS managed if null)."
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights (optional)."
  type        = string
  default     = null
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)."
  type        = number
  default     = 0
}

variable "backup_window" {
  description = "Preferred backup window (UTC, e.g., 03:00-06:00)."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC, e.g., Sun:06:00-Sun:07:00)."
  type        = string
  default     = null
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (use true for dev, false for prod)."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier_prefix" {
  description = "Prefix for final snapshot identifier when skip_final_snapshot = false."
  type        = string
  default     = "final"
}

variable "iam_auth_enabled" {
  description = "Enable IAM database authentication."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where the DB will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "ingress_cidrs" {
  description = "List of CIDR blocks allowed to connect to the DB."
  type        = list(string)
  default     = []
}

variable "ingress_security_group_ids" {
  description = "List of security group IDs allowed to connect to the DB."
  type        = list(string)
  default     = []
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs."
  type        = list(string)
  default     = ["postgresql"]
}

variable "parameter_group_family" {
  description = "Optional override for parameter group family (e.g., postgres15). If null, derived from engine_version."
  type        = string
  default     = null
}

variable "parameters" {
  description = "List of parameter objects for the DB parameter group."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "apply_immediately" {
  description = "Apply changes immediately (may cause restarts)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
