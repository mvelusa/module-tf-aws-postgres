provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "microservice-cluster" {
  name = var.eks_id
}

resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "${var.env_name}-rds-subnet-group"
  subnet_ids = ["${var.subnet_a_id}", "${var.subnet_b_id}"]
}

# Create a security group to allow traffic from the EKS cluster
resource "aws_security_group" "db-security-group" {
  name        = "${var.env_name}-allow-eks-db"
  description = "Allow traffic from EKS managed workloads"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow traffic from managed EKS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    # security_groups = data.aws_eks_cluster.microservice-cluster.vpc_config.0.security_group_ids
  }
}

# The default security group
data "aws_security_group" "default" {
  vpc_id = var.vpc_id
  name   = "default"
}

# Our RDS PostgreSQL database instance
resource "aws_db_instance" "postgres-db" {
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = "db.t3.micro"
  db_name           = var.postgres_database
  identifier        = "microservices-postgres"

  username             = var.postgres_user
  password             = var.postgres_password
  parameter_group_name = "default.postgres15"

  skip_final_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.rds-subnet-group.name
  vpc_security_group_ids = [var.eks_sg_id]
}

# Setup a Route53 DNS entry for RDS routing
data "aws_route53_zone" "private-zone" {
  zone_id      = var.route53_id
  private_zone = true
}

resource "aws_route53_record" "rds-instance" {
  zone_id = var.route53_id
  name    = "rds.${data.aws_route53_zone.private-zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.postgres-db.address]
}