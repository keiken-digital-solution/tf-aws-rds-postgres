# tf-aws-rds-postgres

Reusable Terraform module to provision an AWS RDS PostgreSQL instance for product teams on the KPP platform. It follows platform conventions: private subnets, restrictive security groups, encryption, CloudWatch log exports, and optional Secrets Manager integration.

## Features

- Private RDS PostgreSQL instance (single or Multi‑AZ)
- DB subnet group from provided subnets
- Security group with controlled ingress (CIDRs and/or SG IDs)
- Parameter group with optional custom parameters
- Storage encryption (KMS), performance insights, enhanced monitoring
- Automated backups and maintenance windows
- Optional Secrets Manager secret with connection JSON
- Sensible defaults and outputs for app consumption

## Usage

Basic example (using platform outputs via remote state):

```hcl
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "keiken-dev-tfstate"
    key    = "tfstate-platform/primary.tfstate"
    region = "eu-west-3"
  }
}

module "app_db" {
  source = "git::https://github.com/keiken-digital-solution/tf-aws-rds-postgres.git"

  name           = "keiken-dev-myapp-db"
  vpc_id         = data.terraform_remote_state.platform.outputs.vpc_id
  subnet_ids     = data.terraform_remote_state.platform.outputs.private_subnets

  # Access from EKS nodes/pods via the VPC CIDR or from a specific SG
  ingress_cidrs               = ["10.10.0.0/16"]
  # ingress_security_group_ids = [aws_security_group.app_sg.id]

  # Sane defaults, override as needed
  engine_version             = "16.3"
  instance_class             = "db.t3.medium"
  multi_az                   = true
  backup_retention_days      = 7
  iam_auth_enabled           = false

  # Use module-managed random password + secret (recommended)
  create_random_password = true
  manage_secret          = true

  tags = {
    Product     = "myapp"
    Environment = "dev"
  }
}

output "db_endpoint" {
  value = module.app_db.endpoint
}
```

## Inputs

- name: Base name for resources (required)
- vpc_id: Target VPC ID (required)
- subnet_ids: Private subnet IDs (required)
- engine_version: Postgres version (default: 16.3)
- instance_class: RDS instance class (default: db.t3.medium)
- allocated_storage: Initial storage GB (default: 50)
- max_allocated_storage: Autoscaling max GB (default: 200)
- storage_type: gp3 by default
- multi_az: true by default
- publicly_accessible: false by default
- db_name: Initial DB name (default: app)
- username: Master username (default: appuser)
- password: Master password (optional if create_random_password=true)
- create_random_password: bool (default: true)
- manage_secret: Create Secrets Manager secret with connection JSON (default: true)
- secret_name: Custom secret name (optional)
- kms_key_id: KMS key for storage encryption (optional)
- performance_insights_enabled: bool (default: true)
- performance_insights_kms_key_id: KMS for PI (optional)
- monitoring_interval: Enhanced monitoring seconds (0 to disable; default 0)
- backup_retention_days: default 7
- backup_window: e.g., 03:00-06:00 (UTC)
- maintenance_window: e.g., Sun:06:00-Sun:07:00 (UTC)
- deletion_protection: default true
- skip_final_snapshot: default true (set to false in prod)
- final_snapshot_identifier_prefix: default "final"
- iam_auth_enabled: enable IAM DB auth (default false)
- ingress_cidrs: allowlist of CIDRs
- ingress_security_group_ids: allowlist of SG IDs
- enabled_cloudwatch_logs_exports: default ["postgresql"]
- parameter_group_family: override (else derived from engine_version)
- parameters: list of { name, value } for parameter group
- apply_immediately: default false
- tags: map of common tags

## Outputs

- db_instance_id: DB instance identifier
- endpoint: DNS endpoint
- port: Port number
- database_name: Initial DB name
- security_group_id: Attached SG ID
- subnet_group_name: DB subnet group name
- parameter_group_name: DB parameter group name
- secret_arn: Secrets Manager secret ARN (if managed)

## Secrets strategy

Recommended: let the module generate a strong password and store it in a managed Secrets Manager secret. Applications can read the secret at runtime or CI can inject it as needed. If you must control the password externally, set `create_random_password=false`, pass `password`, and optionally set `manage_secret=false` if you manage a separate secret.

Secret JSON shape:

```json
{
  "engine": "postgres",
  "host": "<endpoint>",
  "port": 5432,
  "dbname": "<db_name>",
  "username": "<username>",
  "password": "<password>",
  "jdbc": "jdbc:postgresql://<endpoint>:5432/<db_name>"
}
```

## Prod guidance

- Set `deletion_protection=true` and `skip_final_snapshot=false`.
- When `skip_final_snapshot=false`, ensure the final snapshot identifier is unique. Adjust `final_snapshot_identifier_prefix` or delete existing snapshots with the same id before destroy.
- Define `backup_window` and `maintenance_window` to avoid peak hours.
- Use Multi‑AZ. Ensure enough free IPs in private subnets.
- Pin a specific engine version and upgrade deliberately.
- Tag resources with Product and Environment labels.

## IAM auth (optional)

Enable `iam_auth_enabled=true` to allow IAM authentication to the database. You must then configure database users/roles and client-side IAM tokens. This is not a replacement for the master password.

## Migration from an existing DB

If restoring from a snapshot, this module currently focuses on fresh instances. For snapshot-based workflows, extend it with `snapshot_identifier` and manage engine compatibility as needed.

## Notes

- This module manages a single RDS instance (not Aurora). For Aurora Postgres, use a dedicated module.
- Ensure RDS network access: use `ingress_cidrs` or `ingress_security_group_ids` to allow from your app.
- The platform VPC exposes AWS APIs privately via VPC endpoints; RDS endpoints remain inside the VPC.
