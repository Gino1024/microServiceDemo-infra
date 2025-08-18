provider "aws" {
  region = "ap-east-2"
}

module "apigateway_ecr" {
  source               = "./modules/ecr"
  name                 = "apigateway"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  tags = {
    Environment = "dev"
    Project     = "microservice-demo"
  }
}

module "userapi_ecr" {
  source               = "./modules/ecr"
  name                 = "userapi"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  tags = {
    Environment = "dev"
    Project     = "microservice-demo"
  }
}
