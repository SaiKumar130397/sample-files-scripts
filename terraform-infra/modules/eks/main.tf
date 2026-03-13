module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name = var.cluster_name
  subnet_ids   = var.subnet_ids

  cluster_version = "1.29"

  vpc_id = var.vpc_id

}