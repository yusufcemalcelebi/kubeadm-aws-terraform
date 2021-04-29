provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"
  
  name = "assignment-vpc"

  cidr                  = "10.0.0.0/16"
  secondary_cidr_blocks = ["10.1.0.0/16", "10.2.0.0/16"]

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.1.2.0/24", "10.2.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.1.102.0/24", "10.2.103.0/24"]

  enable_ipv6 = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "public-subnet"
  }
  private_subnet_tags = {
    Name = "private-subnet"
  }
  tags = {
    Owner       = "yusuf"
    Environment = "assignment"
  }
  vpc_tags = {
    Name = "bion-assignment"
  }
}