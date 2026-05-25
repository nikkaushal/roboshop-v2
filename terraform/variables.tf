variable "env" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ami_id" {
  type = string
}

variable "ec2_user" {
  type    = string
  default = "ec2-user"
}

variable "ec2_password" {
  type      = string
  sensitive = true
}

variable "ansible_repo_url" {
  type = string
}

variable "network" {
  type = map(object({
    vpc_cidr = string
    subnets  = map(list(string))
    az       = list(string)
  }))
}

variable "cluster_sg_ingress_cidr" {
  type        = string
  description = "CIDR allowed to reach EKS API (port 443) — set to default VPC CIDR for bastion access"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.xlarge"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "node_capacity_type" {
  type    = string
  default = "SPOT"
}

variable "dns_domain" {
  type        = string
  description = "Public domain for ingress (e.g. tek-nik.com)"
}

variable "dns_zone_id" {
  type        = string
  description = "Route53 public hosted zone ID for dns_domain — used by external-dns"
}

variable "db_instances" {
  type = map(object({
    component     = string
    subnet_index  = number
    instance_type = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
