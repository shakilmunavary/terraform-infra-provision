terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket         = "ai-terraform-state-file"
    key            = "terraform-infra-provision/terraform-infra-provision.state"
    region         = "us-west-2"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC with public subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Security Group for ALB
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  name    = "alb-sg"
  vpc_id  = module.vpc.vpc_id

  ingress_rules        = ["http-80-tcp"]
  ingress_cidr_blocks  = ["10.0.1.43/32"]
}

# Security Group for EC2
module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  name    = "ec2-sg"
  vpc_id  = module.vpc.vpc_id

  ingress_rules        = ["ssh-tcp"]
  ingress_cidr_blocks  = ["0.0.0.0/0"]
}

# EC2 Instance
module "app_server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  name    = "app-server"
  ami     = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  associate_public_ip_address = false
  vpc_security_group_ids = [module.ec2_sg.security_group_id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              EOF
}

module "app_lb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.2.0"

  name               = "app-load-balancer"
  load_balancer_type = "application"
  internal           = false
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_sg.security_group_id]

  target_groups = {
    app_tg = {
      name_prefix      = "app-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      vpc_id           = module.vpc.vpc_id
      targets = [
        {
          target_id = module.app_server.id
          port      = 80
        }
      ]
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      default_action = {
        type               = "forward"
        target_group_index = 0
      }
    }
  }
}
