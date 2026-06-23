# ─── Random password generation (initial; rotated via Secrets Manager) ─────────
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+"
}

# ─── Security Group ──────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.identifier}-sg"
  description = "RDS MySQL security group - allow only from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.identifier}-sg"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

# ─── Parameter Group (performance + security hardening) ────────────────────────
resource "aws_db_parameter_group" "this" {
  name   = "${var.identifier}-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "require_secure_transport"
    value = "ON"
    apply_method = "pending-reboot"
  }
}

# ─── KMS Key for Encryption at Rest ─────────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - ${var.identifier}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.identifier}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── RDS Instance ─────────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az               = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.identifier}-final-snapshot" : null
  copy_tags_to_snapshot     = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled = false
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true
  apply_immediately           = var.environment != "prod"

  tags = {
    Name = var.identifier
  }
}

# ─── Enhanced Monitoring Role ────────────────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.identifier}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ─── Secrets Manager: Store credentials ─────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "task-tracker/${var.environment}/db-credentials"
  description             = "RDS MySQL credentials for Task Tracker ${var.environment}"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.rds.arn
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    username = var.master_username
    password = random_password.master.result
    dbname   = var.database_name
  })
}
