output "vpc_id" {
  value = local.vpc.vpc_id
}

output "vpc_cidr" {
  value = local.vpc.vpc_cidr
}

output "public_subnet_ids" {
  value = local.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  value = local.vpc.app_subnet_ids
}

output "db_subnet_ids" {
  value = local.vpc.db_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "db_private_ips" {
  value = module.ec2.private_ips
}

output "private_dns_zone" {
  value = local.dns_zone
}
