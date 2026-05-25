env        = "prd"
aws_region = "us-east-1"

ami_id       = "ami-0220d79f3f480ecf5"
ec2_user     = "ec2-user"
ec2_password = "DevOps321"

ansible_repo_url = "https://github.com/nikkaushal/roboshop-v1.git"

# NOTE: 10.30.0.0/24 gives 62 IPs per EKS subnet; fine for 2-5 nodes.
# Consider /16 if you plan to scale pods significantly.
network = {
  prd = {
    vpc_cidr = "10.30.0.0/24"
    subnets = {
      public_subnets = ["10.30.0.0/27", "10.30.0.32/27"]
      app_subnets    = ["10.30.0.64/26", "10.30.0.128/26"]
      db_subnets     = ["10.30.0.192/27", "10.30.0.224/27"]
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

dns_domain  = "tek-nik.com"
dns_zone_id = "Z02807011OH2QBU9LL0MC"

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
