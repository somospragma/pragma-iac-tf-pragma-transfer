######################################################################
# Variables Generales / Globales
######################################################################
client      = "pragma"
environment = "qa"
project     = "transfers"
region      = "us-east-1"

common_tags = {
  client      = "pragma"
  project     = "transfers"
  environment = "qa"
  owner       = "cloudops"
  territory   = "peru"
  country     = "pe"
  chapter     = "-"
  model       = "-"
  cost-center = "9952"
  agent       = "-"
  service     = "ms-transfers"
}

######################################################################
# Red (una sola zona, sin NAT)
######################################################################
availability_zone = "us-east-1a"
vpc_cidr          = "10.20.0.0/16"

######################################################################
# Cómputo (ECS Fargate)
######################################################################
ecr_repository_name = "pragma-ms-java-pragma-transfer"
bootstrap_image_tag = "latest"
ms_desired_count    = 2

######################################################################
# API Gateway (authorizer JWT)
######################################################################
jwt_issuer   = "https://idp.pragbank.pe/"
jwt_audience = "pragbank-app"
