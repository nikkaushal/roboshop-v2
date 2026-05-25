# ── Cluster IAM Role ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.env}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = merge(var.tags, { Name = "${var.env}-eks-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── Node IAM Role ────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.env}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = merge(var.tags, { Name = "${var.env}-eks-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow nodes to use the KMS key for encrypted EBS
resource "aws_iam_role_policy" "node_kms" {
  name = "${var.env}-eks-node-kms"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:CreateGrant",
      ]
      Resource = aws_kms_key.eks.arn
    }]
  })
}

# ── Cluster Autoscaler IAM Role (Pod Identity) ───────────────────────────────

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "autoscaler" {
  name               = "${var.env}-cluster-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = merge(var.tags, { Name = "${var.env}-cluster-autoscaler-role" })
}

resource "aws_iam_role_policy" "autoscaler" {
  name = "${var.env}-cluster-autoscaler"
  role = aws_iam_role.autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/kubernetes.io/cluster/${var.env}" = "owned"
          }
        }
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "autoscaler" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.autoscaler.arn

  depends_on = [aws_eks_addon.pod_identity]
}

# ── External DNS IAM Role (Pod Identity) ─────────────────────────────────────

resource "aws_iam_role" "external_dns" {
  name               = "${var.env}-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = merge(var.tags, { Name = "${var.env}-external-dns-role" })
}

resource "aws_iam_role_policy" "external_dns" {
  name = "${var.env}-external-dns"
  role = aws_iam_role.external_dns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/${var.dns_zone_id}"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources",
        ]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn

  depends_on = [aws_eks_addon.pod_identity]
}
