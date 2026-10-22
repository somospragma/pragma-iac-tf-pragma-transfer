# ######################################################################
# # Outputs
# #
# # El pipeline publica cada output (en MAYÚSCULAS, sin prefijo) como variable
# # en la library del micro (pragma-ms-java-pragma-transfer):
# #   ecs_service       -> ECS_SERVICE
# #   secret_apis_name  -> SECRET_APIS_NAME
# ######################################################################

# output "ecs_service" {
#   description = "Nombre del servicio ECS ms-transfers — publica ECS_SERVICE en la library del micro"
#   value       = module.ecs_services.ecs_services["ms-transfers"].name
# }

# output "secret_apis_name" {
#   description = "Nombre del secreto de las APIs — publica SECRET_APIS_NAME en la library del micro"
#   value       = module.sm.secret_names["apis"]
# }
