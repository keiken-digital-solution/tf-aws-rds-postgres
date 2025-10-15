locals {
  # Derive parameter group family if not provided, e.g., engine 16.8 => postgres16
  engine_major             = try(element(split(".", var.engine_version), 0), "16")
  derived_parameter_family = "postgres${local.engine_major}"
  parameter_group_family   = coalesce(var.parameter_group_family, local.derived_parameter_family)

  # Secret name fallback
  secret_name = coalesce(var.secret_name, "${var.name}-credentials")
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnets" })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Access to ${var.name} Postgres"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

resource "aws_security_group_rule" "ingress_cidrs" {
  for_each          = toset(var.ingress_cidrs)
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.this.id
  description       = "Allow Postgres from CIDR ${each.value}"
}

resource "aws_security_group_rule" "ingress_sgs" {
  for_each                 = toset(var.ingress_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "Allow Postgres from SG ${each.value}"
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = local.parameter_group_family
  description = "Parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}

resource "random_password" "this" {
  count            = var.password == null && var.create_random_password ? 1 : 0
  length           = 24
  special          = true
  override_special = "!#-_+="
}

locals {
  master_password = coalesce(var.password, try(random_password.this[0].result, null))
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class = var.instance_class
  db_name        = var.db_name
  username       = var.username
  password       = local.master_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  port                   = 5432
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  monitoring_interval = var.monitoring_interval

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.name}"

  iam_database_authentication_enabled = var.iam_auth_enabled

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  apply_immediately = var.apply_immediately

  tags = merge(var.tags, { Name = var.name })
}

# Optional Secrets Manager secret with connection details
resource "aws_secretsmanager_secret" "this" {
  count       = var.manage_secret ? 1 : 0
  name        = local.secret_name
  description = "Credentials for ${var.name} Postgres"
  tags        = merge(var.tags, { Name = local.secret_name })
}

resource "aws_secretsmanager_secret_version" "this" {
  count     = var.manage_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.this[0].id
  secret_string = jsonencode({
    engine   = "postgres",
    host     = aws_db_instance.this.address,
    port     = aws_db_instance.this.port,
    dbname   = aws_db_instance.this.db_name,
    username = aws_db_instance.this.username,
    password = local.master_password,
    jdbc     = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}"
  })
  depends_on = [aws_db_instance.this]
}
