variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "App/private subnets for EKS nodes"
}

variable "cluster_sg_ingress_cidr" {
  type        = string
  description = "CIDR allowed to reach the EKS API (port 443)"
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
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN attached to the NLB for TLS termination"
}

variable "tags" {
  type    = map(string)
  default = {}
}
