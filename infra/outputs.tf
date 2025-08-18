output "apigateway_ecr_url" {
  value = module.apigateway_ecr.repository_url
}

output "userapi_ecr_url" {
  value = module.userapi_ecr.repository_url
}
