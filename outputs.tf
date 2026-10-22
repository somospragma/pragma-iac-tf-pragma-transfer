######################################################################
# Outputs
######################################################################
# La HU-02 expone estos outputs; se copian a la library
# pragma-ms-java-pragma-transfer después del primer apply:
#
#   ecs_cluster_name  -> ECS_CLUSTER
#   ecs_service_name  -> ECS_SERVICE
#   task_family       -> ECS_TASK_FAMILY
#   app_secret_name   -> APP_SECRET_ID
#   api_base_url      -> API_BASE_URL

output "aws_account_id" {
  description = "Cuenta AWS donde se despliega"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR preexistente del micro"
  value       = data.aws_ecr_repository.ms_transfers.repository_url
}
