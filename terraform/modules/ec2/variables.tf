variable "env" {
  type = string
}

variable "instances" {
  type = map(object({
    component     = string
    subnet_index  = number
    instance_type = string
  }))
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

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "route53_zone_id" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "ansible_repo_url" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
