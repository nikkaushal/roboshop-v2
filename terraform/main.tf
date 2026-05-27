module "vpc" {
  for_each = var.network
  source   = "./modules/vpc"

  env      = var.env
  vpc_cidr = each.value.vpc_cidr
  subnets  = each.value.subnets
  az       = each.value.az
}

locals {
  network_key = var.env
  vpc         = module.vpc[local.network_key]

  dns_zone = "${var.env}.roboshop.internal"

  db_hosts = {
    mysql    = "mysql.${local.dns_zone}"
    mongodb  = "mongodb.${local.dns_zone}"
    valkey   = "valkey.${local.dns_zone}"
    rabbitmq = "rabbitmq.${local.dns_zone}"
  }
}

resource "aws_route53_zone" "private" {
  name = local.dns_zone

  vpc {
    vpc_id = local.vpc.vpc_id
  }

  tags = merge(var.tags, {
    Name = "${var.env}-roboshop-private-zone"
  })
}

resource "aws_security_group" "db" {
  name        = "${var.env}-roboshop-db-sg"
  description = "RoboShop DB tier - MySQL, MongoDB, Valkey, RabbitMQ"
  vpc_id      = local.vpc.vpc_id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "Valkey/Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "RabbitMQ AMQP"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "RabbitMQ management"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env}-db-sg" })
}

module "ec2" {
  source = "./modules/ec2"

  env                = var.env
  instances          = var.db_instances
  ami_id             = var.ami_id
  ec2_user           = var.ec2_user
  ec2_password       = var.ec2_password
  subnet_ids         = local.vpc.db_subnet_ids
  security_group_ids = [aws_security_group.db.id]
  route53_zone_id    = aws_route53_zone.private.zone_id
  dns_zone           = local.dns_zone
  tags               = var.tags
  ansible_repo_url   = var.ansible_repo_url
}

module "eks" {
  source = "./modules/eks"

  env                     = var.env
  subnet_ids              = local.vpc.app_subnet_ids
  vpc_id                  = local.vpc.vpc_id
  cluster_sg_ingress_cidr = var.cluster_sg_ingress_cidr
  node_instance_types     = var.node_instance_types
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  node_capacity_type      = var.node_capacity_type
  acm_certificate_arn     = var.acm_certificate_arn
  dns_domain              = var.dns_domain
  dns_zone_id             = var.dns_zone_id
  tags                    = var.tags

  depends_on = [module.ec2]
}
