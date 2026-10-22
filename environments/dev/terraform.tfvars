######################################################################
# Variables Generales / Globales
######################################################################
client      = "pragma"
environment = "dev"
project     = "transfers"
region      = "us-east-1"

common_tags = {
  client      = "pragma"
  project     = "transfers"
  environment = "dev"
  owner       = "cloudops"
  territory   = "peru"
  country     = "pe"
  service     = "ms-transfers"
  component   = "core"
}

######################################################################
# Nombres de recursos preexistentes (leídos con data source)
######################################################################
vpc_name                = "pragma-transfers-dev-vpc"
nlb_name                = "pragma-transfers-dev-nlb-trf"
ecs_cluster_name        = "pragma-transfers-dev-cluster-ms-transfers"
cloudmap_namespace_name = "pragma-transfers-dev-ns-service-connect"

ecr_repository_name       = "pragma-transfers-dev-ecr-ms-transfers"
ecr_mocks_repository_name = "pragma-transfers-dev-ecr-mocks"

######################################################################
# Cómputo (ECS Fargate)
# Tareas en 0 hasta validar que todo esté bien. Luego subir a 2 (micro) y 1 (mocks).
######################################################################
bootstrap_image_tag = "latest"
ms_desired_count    = 1
mocks_desired_count = 1
container_port      = 8080

######################################################################
# KMS — una llave por servicio (ACCOUNT_ID_PLACEHOLDER lo reemplaza locals)
######################################################################
kms_config = {
  "sm" = {
    description         = "Key cifrado Secrets Manager — ms-transfers"
    enable_key_rotation = true
    statements = [
      {
        sid         = "AllowSecretsManagerServiceInAccount"
        actions     = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        resources   = ["*"]
        effect      = "Allow"
        type        = "Service"
        identifiers = ["secretsmanager.amazonaws.com"]
        condition = [
          { test = "StringEquals", variable = "aws:SourceAccount", values = ["ACCOUNT_ID_PLACEHOLDER"] }
        ]
      }
    ]
    additional_tags = { Service = "SecretsManager" }
  }

  "dynamo" = {
    description         = "Key cifrado DynamoDB — ms-transfers"
    enable_key_rotation = true
    statements = [
      {
        sid         = "AllowDynamoDBServiceInAccount"
        actions     = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        resources   = ["*"]
        effect      = "Allow"
        type        = "Service"
        identifiers = ["dynamodb.amazonaws.com"]
        condition = [
          { test = "StringEquals", variable = "aws:SourceAccount", values = ["ACCOUNT_ID_PLACEHOLDER"] }
        ]
      }
    ]
    additional_tags = { Service = "DynamoDB" }
  }

  "sns" = {
    description         = "Key cifrado SNS — ms-transfers"
    enable_key_rotation = true
    statements = [
      {
        sid         = "AllowSnsServiceInAccount"
        actions     = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        resources   = ["*"]
        effect      = "Allow"
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
        condition = [
          { test = "StringEquals", variable = "aws:SourceAccount", values = ["ACCOUNT_ID_PLACEHOLDER"] }
        ]
      }
    ]
    additional_tags = { Service = "SNS" }
  }

  "sqs" = {
    description         = "Key cifrado SQS — ms-transfers"
    enable_key_rotation = true
    statements = [
      {
        sid         = "AllowSqsServiceInAccount"
        actions     = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        resources   = ["*"]
        effect      = "Allow"
        type        = "Service"
        identifiers = ["sqs.amazonaws.com"]
        condition = [
          { test = "StringEquals", variable = "aws:SourceAccount", values = ["ACCOUNT_ID_PLACEHOLDER"] }
        ]
      }
    ]
    additional_tags = { Service = "SQS" }
  }
}

######################################################################
# DynamoDB — transfers, idempotency (TTL), recipient-tokens (TTL)
# map(object) según el módulo v2.1.1. kms_key_arn vacío = locals inyecta KMS "dynamo".
# El TTL de 5 min de recipient-tokens lo controla el micro con el valor de expiresAt.
######################################################################
dynamo_config = {
  "transfers" = {
    billing_mode                = "PAY_PER_REQUEST"
    hash_key                    = "transferId"
    point_in_time_recovery      = true
    deletion_protection_enabled = false
    attributes = [
      { name = "transferId", type = "S" },
      { name = "sourceAccountId", type = "S" },
      { name = "customerDay", type = "S" },
      { name = "createdAt", type = "S" }
    ]
    global_secondary_indexes = [
      {
        name = "sourceAccountId-createdAt-index"
        key_schema = [
          { attribute_name = "sourceAccountId", key_type = "HASH" },
          { attribute_name = "createdAt", key_type = "RANGE" }
        ]
        projection_type = "ALL"
      },
      {
        name = "customerDay-createdAt-index"
        key_schema = [
          { attribute_name = "customerDay", key_type = "HASH" },
          { attribute_name = "createdAt", key_type = "RANGE" }
        ]
        projection_type = "ALL"
      }
    ]
    server_side_encryption = {
      enabled     = true
      kms_key_arn = ""
    }
    ttl_enabled   = false
    functionality = "transfers"
  }

  "idempotency" = {
    billing_mode                = "PAY_PER_REQUEST"
    hash_key                    = "idempotencyKey"
    point_in_time_recovery      = true
    deletion_protection_enabled = false
    attributes = [
      { name = "idempotencyKey", type = "S" }
    ]
    server_side_encryption = {
      enabled     = true
      kms_key_arn = ""
    }
    ttl_enabled        = true
    ttl_attribute_name = "expiresAt"
    functionality      = "idempotency"
  }

  "recipient-tokens" = {
    billing_mode                = "PAY_PER_REQUEST"
    hash_key                    = "recipientToken"
    point_in_time_recovery      = true
    deletion_protection_enabled = false
    attributes = [
      { name = "recipientToken", type = "S" }
    ]
    server_side_encryption = {
      enabled     = true
      kms_key_arn = ""
    }
    ttl_enabled        = true
    ttl_attribute_name = "expiresAt"
    functionality      = "recipient-tokens"
  }
}

######################################################################
# SNS — transfers-events (la suscripción a SQS la arma locals)
######################################################################
sns_topics = {
  "transfers-events" = {
    display_name    = "ms-transfers events"
    fifo_topic      = false
    additional_tags = { "component" = "core" }
  }
}

######################################################################
# SQS — notifications + DLQ
######################################################################
sqs_config = {
  "notifications" = {
    delay_seconds              = 0
    max_message_size           = 262144
    message_retention_seconds  = 345600
    receive_wait_time_seconds  = 10
    visibility_timeout_seconds = 30
    fifo_queue                 = false
    kms_master_key_id          = ""
    # false: esta es la cola PRINCIPAL (prefijo sqs-). El redrive_policy crea
    # su DLQ aparte (prefijo dlq-). Con true ambas tomarían el mismo nombre.
    dead_letter_queue = false
    statements        = []
    application       = "transfers"
    additional_tags   = { "component" = "core" }
    redrive_policy = {
      max_receive_count = 5
    }
  }
}

######################################################################
# Secrets Manager — secreto vacío (kms_key_id vacío = locals inyecta KMS "sm")
######################################################################
secrets_config = {
  "apis" = {
    description             = "Secreto de las APIs externas (CORE, FRAUD) — valor lo escribe el pipeline del micro"
    kms_key_id              = ""
    recovery_window_in_days = 7
    create_secret_version   = false
    additional_tags         = { "component" = "core" }
  }
}

######################################################################
# API Gateway REST — API key + usage plan
######################################################################
api_stage_name           = "dev"
api_throttle_rate_limit  = 20
api_throttle_burst_limit = 40
