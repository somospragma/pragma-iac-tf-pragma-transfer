# ############################################################################
# # Local Values
# ############################################################################
# locals {
#   # Nomenclatura: {client}-{project}-{environment}
#   name_prefix = "${var.client}-${var.project}-${var.environment}"
#   account_id  = data.aws_caller_identity.current.account_id

#   #########################################################################
#   # KMS — reemplaza ACCOUNT_ID_PLACEHOLDER en las condiciones
#   #########################################################################
#   kms_config = {
#     for key, config in var.kms_config : key => merge(config, {
#       statements = [
#         for stmt in config.statements : merge(stmt, {
#           identifiers = [
#             for id in stmt.identifiers :
#             id == "ACCOUNT_ID_PLACEHOLDER" ? "arn:aws:iam::${local.account_id}:root" : id
#           ]
#           condition = [
#             for cond in stmt.condition : merge(cond, {
#               values = [
#                 for val in cond.values :
#                 replace(val, "ACCOUNT_ID_PLACEHOLDER", local.account_id)
#               ]
#             })
#           ]
#         })
#       ]
#     })
#   }

#   #########################################################################
#   # DynamoDB — inyecta la llave KMS "dynamo" en server_side_encryption
#   # (map(object); server_side_encryption es un objeto, no lista)
#   #########################################################################
#   dynamo_config = {
#     for key, table in var.dynamo_config : key => merge(table, {
#       server_side_encryption = merge(table.server_side_encryption, {
#         kms_key_arn = try(table.server_side_encryption.kms_key_arn, "") != "" ? table.server_side_encryption.kms_key_arn : module.kms.kms_info["dynamo"].key_arn
#       })
#     })
#   }

#   #########################################################################
#   # SNS — topic transfers-events (cifrado con KMS "sns") con suscripción a SQS
#   #########################################################################
#   sns_topics = {
#     for key, topic in var.sns_topics : key => merge(topic, {
#       kms_master_key_id = module.kms.kms_info["sns"].key_arn
#       subscriptions = {
#         "notifications" = {
#           protocol             = "sqs"
#           endpoint             = module.sqs.queue_arns["notifications"]
#           raw_message_delivery = false
#         }
#       }
#     })
#   }

#   #########################################################################
#   # SQS — inyecta la KMS "sqs" (CMK) en cada cola si viene vacía
#   #########################################################################
#   sqs_config = {
#     for key, cfg in var.sqs_config : key => merge(cfg, {
#       kms_master_key_id = cfg.kms_master_key_id != "" ? cfg.kms_master_key_id : module.kms.kms_info["sqs"].key_arn
#     })
#   }

#   #########################################################################
#   # Secrets Manager — inyecta la llave KMS "sm" si viene vacía
#   #########################################################################
#   secrets_config = {
#     for key, config in var.secrets_config : key => merge(config, {
#       kms_key_id = config.kms_key_id != "" ? config.kms_key_id : module.kms.kms_info["sm"].key_arn
#     })
#   }

#   #########################################################################
#   # SG de las tareas ECS — ingress 8080 desde el SG del ALB y entre tareas
#   #########################################################################
#   sg_ecs_config = {
#     "ecs" = {
#       description     = "SG for ms-transfers ECS tasks - port ${var.container_port} (micro y mocks)"
#       vpc_id          = data.aws_vpc.vpc.id
#       additional_tags = { "application-tier" = "backend" }
#       ingress = [
#         {
#           from_port       = var.container_port
#           to_port         = var.container_port
#           protocol        = "tcp"
#           cidr_blocks     = [data.aws_vpc.vpc.cidr_block]
#           security_groups = []
#           prefix_list_ids = []
#           self            = false
#           description     = "Port ${var.container_port} from VPC (NLB y VPC Link)"
#         },
#         {
#           from_port       = var.container_port
#           to_port         = var.container_port
#           protocol        = "tcp"
#           cidr_blocks     = []
#           security_groups = []
#           prefix_list_ids = []
#           self            = true
#           description     = "Port ${var.container_port} service connect"
#         }
#       ]
#       egress = [
#         {
#           from_port       = 0
#           to_port         = 0
#           protocol        = "-1"
#           cidr_blocks     = ["0.0.0.0/0"]
#           prefix_list_ids = []
#           security_groups = []
#           self            = false
#           description     = "Allow all outbound"
#         }
#       ]
#     }
#   }

#   #########################################################################
#   # IAM — execution role y task role (permisos amplios para el micro)
#   #########################################################################
#   iam_config = {
#     "trf-execution" = {
#       functionality        = "trf"
#       application          = "transfers"
#       service              = "execution"
#       path                 = "/service-role/"
#       type                 = "Service"
#       identifiers          = ["ecs-tasks.amazonaws.com"]
#       principal_conditions = []
#       policies = [
#         {
#           policy_description = "ECS Execution — ECR, Logs, Secrets, KMS"
#           policy_statements = [
#             {
#               sid       = "ECRAccess"
#               actions   = ["ecr:GetDownloadUrlForLayer", "ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "LogsAccess"
#               actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "SecretsAndKms"
#               actions   = ["secretsmanager:GetSecretValue", "kms:Decrypt", "kms:DescribeKey"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             }
#           ]
#         }
#       ]
#       managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
#       additional_tags     = { "role-type" = "execution" }
#     }

#     "trf-task" = {
#       functionality        = "trf"
#       application          = "transfers"
#       service              = "task"
#       path                 = "/service-role/"
#       type                 = "Service"
#       identifiers          = ["ecs-tasks.amazonaws.com"]
#       principal_conditions = []
#       policies = [
#         {
#           policy_description = "ECS Task — DynamoDB, SNS, SQS, Secrets, KMS, Logs"
#           policy_statements = [
#             {
#               sid       = "DynamoDBAccess"
#               actions   = ["dynamodb:*"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "SnsAccess"
#               actions   = ["sns:Publish", "sns:GetTopicAttributes", "sns:ListTopics"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "SqsAccess"
#               actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "SecretsAndKms"
#               actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "LogsAccess"
#               actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             },
#             {
#               sid       = "EcsExecSsmMessages"
#               actions   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
#               resources = ["*"]
#               effect    = "Allow"
#               condition = []
#             }
#           ]
#         }
#       ]
#       managed_policy_arns = []
#       additional_tags     = { "role-type" = "task" }
#     }
#   }

#   #########################################################################
#   # ALB Listener + Target Group — listener HTTP:80 → target group del micro
#   #########################################################################
#   listener_config = {
#     "transfers" = {
#       load_balancer_arn = data.aws_lb.nlb.arn
#       application_id    = "transfers"

#       listeners = [
#         {
#           protocol                = "TCP"
#           port                    = "80"
#           certificate             = ""
#           default_target_group_id = "trf"
#           additional_tags         = {}
#           rules                   = []
#         }
#       ]

#       target_groups = [
#         {
#           target_application_id = "trf"
#           port                  = tostring(var.container_port)
#           protocol              = "TCP"
#           vpc_id                = data.aws_vpc.vpc.id
#           target_type           = "ip"
#           healthy_threshold     = "3"
#           interval              = "30"
#           path                  = ""
#           unhealthy_threshold   = "3"
#           matcher               = ""
#           additional_tags       = { Name = "${local.name_prefix}-tg-trf" }
#         }
#       ]
#     }
#   }

#   #########################################################################
#   # ECS Services — ms-transfers (2 tareas) y mocks (1 tarea)
#   #########################################################################
#   ecs_services_config = {
#     "ms-transfers" = {
#       cluster_name              = data.aws_ecs_cluster.cluster.cluster_name
#       desired_count             = var.ms_desired_count
#       enable_execute_command    = true
#       task_cpu                  = 512
#       task_memory               = 1024
#       subnets                   = data.aws_subnets.private.ids
#       security_groups           = [module.sg_ecs.sg_ids["ecs"]]
#       execution_role_arn        = module.iam.iam_roles_info["trf-execution"].role_arn
#       task_role_arn             = module.iam.iam_roles_info["trf-task"].role_arn
#       health_check_grace_period = 60
#       assign_public_ip          = false

#       load_balancer = {
#         target_group_arn = module.elb_listener.target_group_arns["trf"]
#         container_name   = "ms-transfers"
#         container_port   = var.container_port
#       }

#       service_connect_config = {
#         enabled   = true
#         namespace = data.aws_service_discovery_http_namespace.service_connect.arn
#         service = {
#           port_name      = "ms-transfers"
#           discovery_name = "ms-transfers"
#           client_alias = [
#             { port = var.container_port, dns_name = "ms-transfers" }
#           ]
#         }
#       }

#       containers = {
#         "ms-transfers" = {
#           image     = "${data.aws_ecr_repository.ms_transfers.repository_url}:${var.bootstrap_image_tag}"
#           cpu       = 256
#           memory    = 768
#           essential = true
#           port_mappings = [
#             { name = "ms-transfers", container_port = var.container_port, host_port = var.container_port, protocol = "tcp" }
#           ]
#           environment = [
#             { name = "CORE_BASE_URL", value = "http://mocks:${var.container_port}" },
#             { name = "FRAUD_BASE_URL", value = "http://mocks:${var.container_port}" },
#             { name = "DIRECTORY_BASE_URL", value = "http://mocks:${var.container_port}" },
#             { name = "ENVIRONMENT", value = var.environment }
#           ]
#           secrets = []
#           log_configuration = {
#             log_driver = "awslogs"
#             options = {
#               "awslogs-group"         = "/aws/ecs/${local.name_prefix}-ms-transfers"
#               "awslogs-region"        = var.region
#               "awslogs-stream-prefix" = "ecs"
#               "awslogs-create-group"  = "true"
#             }
#           }
#         }
#       }
#       log_retention_days = 7
#       additional_tags    = { "component" = "core" }
#     }

#     "mocks" = {
#       cluster_name              = data.aws_ecs_cluster.cluster.cluster_name
#       desired_count             = var.mocks_desired_count
#       enable_execute_command    = true
#       task_cpu                  = 256
#       task_memory               = 512
#       subnets                   = data.aws_subnets.private.ids
#       security_groups           = [module.sg_ecs.sg_ids["ecs"]]
#       execution_role_arn        = module.iam.iam_roles_info["trf-execution"].role_arn
#       task_role_arn             = module.iam.iam_roles_info["trf-task"].role_arn
#       health_check_grace_period = 60
#       assign_public_ip          = false

#       service_connect_config = {
#         enabled   = true
#         namespace = data.aws_service_discovery_http_namespace.service_connect.arn
#         service = {
#           port_name      = "mocks"
#           discovery_name = "mocks"
#           client_alias = [
#             { port = var.container_port, dns_name = "mocks" }
#           ]
#         }
#       }

#       containers = {
#         "mocks" = {
#           image     = "${data.aws_ecr_repository.mocks.repository_url}:${var.bootstrap_image_tag}"
#           cpu       = 256
#           memory    = 512
#           essential = true
#           port_mappings = [
#             { name = "mocks", container_port = var.container_port, host_port = var.container_port, protocol = "tcp" }
#           ]
#           environment = []
#           secrets     = []
#           log_configuration = {
#             log_driver = "awslogs"
#             options = {
#               "awslogs-group"         = "/aws/ecs/${local.name_prefix}-mocks"
#               "awslogs-region"        = var.region
#               "awslogs-stream-prefix" = "ecs"
#               "awslogs-create-group"  = "true"
#             }
#           }
#         }
#       }
#       log_retention_days = 7
#       additional_tags    = { "component" = "core" }
#     }
#   }

#   #########################################################################
#   # API Gateway REST — API key + usage plan + VPC Link V2 hacia el ALB
#   #########################################################################
#   api_config = {
#     "transfers" = {
#       description   = "API Gateway REST de ms-transfers"
#       endpoint_type = "REGIONAL"
#       stage_name    = var.api_stage_name

#       # VPC Link creado como recurso propio (aws_api_gateway_vpc_link.nlb).
#       vpc_link = {
#         create = false
#       }

#       routes = {
#         "/{proxy+}" = {
#           methods          = ["ANY"]
#           integration_type = "VPC_LINK"
#           authorization    = "NONE"
#           api_key_required = true
#           backend_url      = "http://${data.aws_lb.nlb.dns_name}"
#           vpc_link_id      = aws_api_gateway_vpc_link.nlb.id
#           http_method      = "ANY"
#         }
#       }

#       api_keys = {
#         "default" = {
#           description = "API key de ms-transfers"
#           enabled     = true
#           rate_limit  = var.api_throttle_rate_limit
#           burst_limit = var.api_throttle_burst_limit
#         }
#       }
#     }
#   }
# }
