
module "networking" {
  source = "../modules/networking"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "security" {
  source = "../modules/security"

  vpc_id     = module.networking.vpc_id
  admin_cidr = var.admin_cidr
}

module "compute" {
  source = "../modules/compute"

  subnet_id            = module.networking.public_subnet_id
  security_group_id    = module.security.security_group_id
  iam_instance_profile = module.observability.instance_profile_name
  user_data            = file("${path.module}/user-data.sh")
}

module "observability" {
  source = "../modules/observability"

  vpc_id = module.networking.vpc_id
}

module "monitoring" {
  source = "../modules/monitoring"

  instance_id = module.compute.instance_id
}
