
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "_%#&*!+-=" # caractères autorisés
  min_special      = 2
}

resource "aws_security_group" "rds" {
  name        = "${var.namespace}-rds-sg"
  description = "RDS MySQL SG"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.namespace}-rds-sg", Role = "database" }
}

resource "aws_security_group_rule" "mysql_from_web" {
  type                     = "ingress"
  description              = "MySQL depuis SG Web"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.web_sg_id
}

resource "aws_db_parameter_group" "mysql" {
  name        = "${var.namespace}-mysql-parameter-group"
  family      = "mysql8.0"
  description = "Paramètres MySQL pour WordPress"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.namespace}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # 👉 Consomme le DB Subnet Group créé par le module networking
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  backup_retention_period    = var.backup_retention_days
  backup_window              = "02:00-03:00"
  maintenance_window         = "Mon:03:00-Mon:04:00"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  performance_insights_enabled = false
  parameter_group_name         = aws_db_parameter_group.mysql.name

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.namespace}-mysql-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = { Name = "${var.namespace}-mysql", Role = "database", App = "wordpress" }
}
