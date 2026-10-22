# ############################################################################
# # Capa de funcionalidad (core) de ms-transfers · ambiente dev
# #
# # Red  → pragma-iac-tf-pragma-networking (data)
# # SG ALB, ALB, ECS cluster, CloudMap → pragma-iac-tf-pragma-share (data)
# # ECR → preexistentes HU-00 (data)
# #
# # Crea: KMS, DynamoDB, SNS/SQS, Secret vacío, SG ECS, IAM, ECS services
# #       (micro + mocks), ALB listener + target group y API Gateway REST
# #       con API key + VPC Link hacia el ALB interno.
# ############################################################################

# ############################################################################
# # 1. KMS — una llave por servicio (sm, dynamo)
# ############################################################################
# module "kms" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-kms-terraform?ref=v1.0.0"

#   providers = {
#     aws.project = aws.principal
#   }

#   client          = var.client
#   project         = var.project
#   environment     = var.environment
#   deploy_role_arn = var.deploy_role_arn

#   kms_config = local.kms_config
# }

# ############################################################################
# # 2. DynamoDB — transfers, idempotency (TTL), recipient-tokens (TTL 5 min)
# ############################################################################
# module "dynamo" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-dynamo-terraform?ref=v2.1.1"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment
#   application = "transfers"

#   dynamo_config = local.dynamo_config
# }

# ############################################################################
# # 3. SNS — transfers-events
# ############################################################################
# module "sns" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-sns-terraform?ref=v1.0.0"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment

#   sns_topics = local.sns_topics
# }

# ############################################################################
# # 4. SQS — notifications + DLQ (suscrita al SNS)
# ############################################################################
# module "sqs" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-sqs-terraform?ref=v1.0.4"

#   providers = {
#     aws.project = aws.principal
#   }

#   client        = var.client
#   environment   = var.environment
#   functionality = "transfers"

#   sqs_config = local.sqs_config

#   depends_on = [module.kms]
# }

# ############################################################################
# # 5. Secrets Manager — secreto vacío de las APIs
# #    El valor lo escribe el pipeline del micro (sin secret version aquí).
# #    kms_key_id inyectado por locals desde module.kms["sm"].
# ############################################################################
# module "sm" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-sm-terraform?ref=v1.0.0"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment

#   secrets_config = local.secrets_config

#   depends_on = [module.kms]
# }

# ############################################################################
# # 6. Security Group de las tareas ECS (micro + mocks)
# #    Ingress 8080 desde el SG del ALB y entre tareas (service connect).
# ############################################################################
# module "sg_ecs" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-sg-terraform?ref=v1.0.2"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment

#   sg_config = local.sg_ecs_config
# }

# ############################################################################
# # 7. IAM — execution y task role (permisos amplios para el micro)
# ############################################################################
# module "iam" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-iam-terraform?ref=v1.0.1"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment

#   iam_config = local.iam_config
# }

# ############################################################################
# # 8. ECS Services — ms-transfers (2 tareas) y mocks (1 tarea)
# ############################################################################
# module "ecs_services" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-ecs-service-terraform?ref=v1.0.3"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment
#   region      = var.region

#   ecs_services = local.ecs_services_config

#   depends_on = [module.iam, module.sg_ecs, module.elb_listener]
# }

# ############################################################################
# # 9. ALB Listener + Target Group — sobre el ALB interno del share
# ############################################################################
# module "elb_listener" {
#   source = "github.com/somospragma/cloudops-ref-repo-aws-elb-listener-terraform?ref=v1.0.4"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment

#   listener_config = local.listener_config
# }

# ############################################################################
# # 10. API Gateway REST — API key + usage plan + VPC Link hacia el NLB
# #
# # El VPC Link se crea como recurso propio (no con vpc_link.create del módulo)
# # porque el módulo v1.0.0 no inyecta el ID del VPC Link que crea en la
# # integración (deja connection_id vacío → PutIntegration falla). Creándolo
# # aquí, su ID ya existe y se pasa a la ruta vía vpc_link_id.
# ############################################################################
# resource "aws_api_gateway_vpc_link" "nlb" {
#   provider    = aws.principal
#   name        = "${local.name_prefix}-vpclink"
#   description = "VPC Link REST → NLB interno de ms-transfers"
#   target_arns = [data.aws_lb.nlb.arn]

#   tags = { Name = "${local.name_prefix}-vpclink" }
# }

# module "api_gateway" {
#   # feature branch: proxy passthrough automático para {proxy+} (VPC_LINK).
#   # Tras merge + tag nuevo (v1.0.1), apuntar a ese tag.
#   source = "github.com/somospragma/cloudops-ref-repo-aws-api-gateway-terraform?ref=feature/vpc-link-proxy-passthrough"

#   providers = {
#     aws.project = aws.principal
#   }

#   client      = var.client
#   project     = var.project
#   environment = var.environment
#   region      = var.region

#   api_config = local.api_config

#   depends_on = [module.elb_listener, aws_api_gateway_vpc_link.nlb]
# }

