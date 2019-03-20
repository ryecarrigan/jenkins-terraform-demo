provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  providers = { aws = "aws"}
  source    = "vpc"
}
