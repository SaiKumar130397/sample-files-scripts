provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../modules/vpc"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

module "security_group" {
  source = "../../modules/iam"
  sg_name = "prod-sg"
  vpc_id  = module.vpc.vpc_id
}

module "ec2" {
  source = "../../modules/ec2"
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = module.vpc.subnet_id
  security_group = module.security_group.sg_id

  key_name      = var.key_name
  user_data     = file("../../scripts/setup.sh")
  instance_name = "prod-instance"
}

module "s3" {
  source = "../../modules/s3"
  bucket_name = var.bucket_name
}

module "eks" {
  source = "../../modules/eks"
  cluster_name = "prod-eks"
  subnet_ids = [module.vpc.subnet_id]
  vpc_id = module.vpc.vpc_id
}