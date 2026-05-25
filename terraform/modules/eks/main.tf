data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "eks" {
  description             = "${var.env} EKS — secrets and EBS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EBS service"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.env}-eks-kms" })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.env}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_security_group" "cluster_extra" {
  name        = "${var.env}-eks-cluster-extra-sg"
  description = "Additional EKS cluster SG — allows bastion/peered VPC to reach API"
  vpc_id      = var.vpc_id

  ingress {
    description = "EKS API from bastion VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cluster_sg_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env}-eks-cluster-extra-sg" })
}

resource "aws_eks_cluster" "main" {
  name     = var.env
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster_extra.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(var.tags, { Name = "${var.env}-eks" })

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.4-eksbuild.1"

  tags = merge(var.tags, { Name = "${var.env}-pod-identity" })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  tags = merge(var.tags, { Name = "${var.env}-vpc-cni" })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = merge(var.tags, { Name = "${var.env}-kube-proxy" })
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  tags = merge(var.tags, { Name = "${var.env}-coredns" })

  depends_on = [aws_eks_node_group.main]
}

resource "aws_launch_template" "node" {
  name_prefix = "${var.env}-eks-node-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.eks.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.env}-eks-node" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.env}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  capacity_type   = var.node_capacity_type

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  tags = merge(var.tags, { Name = "${var.env}-node-group" })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
    aws_eks_addon.vpc_cni,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size, launch_template]
  }
}
