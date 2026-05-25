variable "env" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnets" {
  type = map(list(string))
}

variable "az" {
  type = list(string)
}
