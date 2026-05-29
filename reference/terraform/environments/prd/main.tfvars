env        = "prd"
aws_region = "us-east-1"

ami_id       = "ami-0220d79f3f480ecf5"
ec2_user     = "ec2-user"
ec2_password = "DevOps321"

ansible_repo_url = "https://github.com/nikkaushal/roboshop-v1.git"

# prd VPC: expanded to /16 so AWS CNI can assign IPs from /20 app subnets
# (t3.xlarge pre-warms up to 60 IPs/node; the old /26 had only 62 usable total)
network = {
  prd = {
    vpc_cidr = "10.30.0.0/16"
    subnets = {
      public_subnets = ["10.30.0.0/24", "10.30.1.0/24"]
      app_subnets    = ["10.30.16.0/20", "10.30.32.0/20"]
      db_subnets     = ["10.30.2.0/24", "10.30.3.0/24"]
    }
    az = ["us-east-1a", "us-east-1b"]
  }
}

# Default VPC CIDR — bastion lives here and needs to reach EKS private endpoint
cluster_sg_ingress_cidr = "172.31.0.0/16"

node_instance_types = ["t3.xlarge"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5
node_capacity_type  = "SPOT"

acm_certificate_arn = "arn:aws:acm:us-east-1:293222827824:certificate/9a14b239-9298-45a6-ab49-9a61b9e675a7"
dns_domain          = "tek-nik.com"
dns_zone_id         = "Z02807011OH2QBU9LL0MC"

db_instances = {
  mysql = {
    component     = "mysql"
    subnet_index  = 0
    instance_type = "t3.small"
  }
  mongodb = {
    component     = "mongodb"
    subnet_index  = 1
    instance_type = "t3.small"
  }
  valkey = {
    component     = "valkey"
    subnet_index  = 0
    instance_type = "t3.small"
  }
  rabbitmq = {
    component     = "rabbitmq"
    subnet_index  = 1
    instance_type = "t3.small"
  }
}

tags = {
  Project     = "roboshop"
  Environment = "prd"
  ManagedBy   = "terraform"
}
