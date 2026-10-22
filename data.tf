# ############################################################################
# # Data Sources
# ############################################################################

# data "aws_caller_identity" "current" {
#   provider = aws.principal
# }

# data "aws_region" "current" {
#   provider = aws.principal
# }

# ############################################################################
# # Red — creada por la capa de networking (pragma-iac-tf-pragma-networking).
# # Se lee por tag:Name.
# ############################################################################
# data "aws_vpc" "vpc" {
#   provider = aws.principal
#   filter {
#     name   = "tag:Name"
#     values = [var.vpc_name]
#   }
# }

# # Subredes privadas — donde corren las tareas Fargate y donde está el ALB interno
# data "aws_subnets" "private" {
#   provider = aws.principal
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.vpc.id]
#   }
#   filter {
#     name   = "tag:Name"
#     values = ["*private*"]
#   }
# }

# ############################################################################
# # Transversal (share) — creado por pragma-iac-tf-pragma-share. Se lee por nombre.
# ############################################################################

# # NLB interno — se usa su ARN para el VPC Link y el listener
# data "aws_lb" "nlb" {
#   provider = aws.principal
#   name     = var.nlb_name
# }

# # Cluster ECS compartido (capa share)
# data "aws_ecs_cluster" "cluster" {
#   provider     = aws.principal
#   cluster_name = var.ecs_cluster_name
# }

# # Namespace HTTP de Cloud Map para ECS Service Connect
# data "aws_service_discovery_http_namespace" "service_connect" {
#   provider = aws.principal
#   name     = var.cloudmap_namespace_name
# }

# ############################################################################
# # Repositorios ECR preexistentes (HU-00): se leen, nunca se crean aquí.
# # El pipeline del micro sube las imágenes :latest del micro y de mocks.
# ############################################################################
# data "aws_ecr_repository" "ms_transfers" {
#   provider = aws.principal
#   name     = var.ecr_repository_name
# }

# data "aws_ecr_repository" "mocks" {
#   provider = aws.principal
#   name     = var.ecr_mocks_repository_name
# }
