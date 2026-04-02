provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/${var.cross_account_role_name}"
  }
}

provider "aws" {
  alias  = "hom"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.hom_account_id}:role/${var.cross_account_role_name}"
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/${var.cross_account_role_name}"
  }
}