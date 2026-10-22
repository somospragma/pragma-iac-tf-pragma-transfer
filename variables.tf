######################################################################
# Variables Globales
######################################################################
variable "region" {
  type        = string
  description = "Region AWS"
  default     = "us-east-1"
}

variable "client" {
  type        = string
  description = "Nombre del cliente"
}

variable "project" {
  type        = string
  description = "Identificador del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue (dev, qa, prod)"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El entorno debe ser uno de: dev, qa, prod."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to be applied to the resources"
}

variable "deploy_role_arn" {
  type        = string
  description = "Rol Deployment IaC"
  default     = ""
}

######################################################################
# Nombres de recursos preexistentes (leídos con data source)
######################################################################
variable "vpc_name" {
  type        = string
  description = "Tag Name de la VPC (capa networking)"
}

variable "nlb_name" {
  type        = string
  description = "Nombre del NLB interno (capa share)"
}

variable "cloudmap_namespace_name" {
  type        = string
  description = "Nombre del namespace HTTP de Cloud Map (capa share)"
}

variable "ecs_cluster_name" {
  type        = string
  description = "Nombre del cluster ECS compartido (capa share)"
}

variable "ecr_repository_name" {
  type        = string
  description = "Repositorio ECR preexistente de la imagen del micro (data source)"
}

variable "ecr_mocks_repository_name" {
  type        = string
  description = "Repositorio ECR preexistente de la imagen de WireMock/mocks (data source)"
}

######################################################################
# Cómputo (ECS Fargate)
######################################################################
variable "bootstrap_image_tag" {
  type        = string
  description = "Tag de las imágenes del micro y de mocks; el pipeline del micro sube ese tag y reinicia las tareas"
  default     = "latest"
}

variable "ms_desired_count" {
  type        = number
  description = "Número de tareas del servicio ms-transfers (0 hasta validar; luego 2)"
  default     = 0
}

variable "mocks_desired_count" {
  type        = number
  description = "Número de tareas del servicio mocks (0 hasta validar; luego 1)"
  default     = 0
}

variable "container_port" {
  type        = number
  description = "Puerto del contenedor del micro y de mocks"
  default     = 8080
}

######################################################################
# KMS — una llave por servicio (sm, dynamo)
# Usar ACCOUNT_ID_PLACEHOLDER en condition.values; los locals lo reemplazan.
######################################################################
variable "kms_config" {
  type = map(object({
    description         = string
    enable_key_rotation = bool
    statements = list(object({
      sid         = string
      actions     = list(string)
      resources   = list(string)
      effect      = string
      type        = string
      identifiers = list(string)
      condition = list(object({
        test     = string
        variable = string
        values   = list(string)
      }))
    }))
    additional_tags = optional(map(string), {})
  }))
  default = {}
}

######################################################################
# DynamoDB — transfers, idempotency (TTL), recipient-tokens (TTL)
# map(object) según el módulo v2.1.1.
# kms_key_arn vacío = los locals inyectan la llave KMS "dynamo".
######################################################################
variable "dynamo_config" {
  type = map(object({
    billing_mode                = string
    hash_key                    = string
    range_key                   = optional(string)
    point_in_time_recovery      = optional(bool, true)
    deletion_protection_enabled = optional(bool, true)
    attributes = list(object({
      name = string
      type = string
    }))
    server_side_encryption = object({
      enabled     = bool
      kms_key_arn = optional(string)
    })
    global_secondary_indexes = optional(list(object({
      name = string
      key_schema = list(object({
        attribute_name = string
        key_type       = string
      }))
      projection_type    = string
      non_key_attributes = optional(list(string), [])
      read_capacity      = optional(number)
      write_capacity     = optional(number)
    })), [])
    ttl_enabled        = optional(bool, false)
    ttl_attribute_name = optional(string, "")
    functionality      = string
    additional_tags    = optional(map(string), {})
  }))
  default = {}
}

######################################################################
# SNS — transfers-events
######################################################################
variable "sns_topics" {
  type = map(object({
    display_name      = optional(string, "")
    fifo_topic        = optional(bool, false)
    kms_master_key_id = optional(string, "")
    additional_tags   = optional(map(string), {})
    subscriptions = optional(map(object({
      protocol             = string
      endpoint             = string
      raw_message_delivery = optional(bool, false)
    })), {})
  }))
  default = {}
}

######################################################################
# SQS — notifications + DLQ
######################################################################
variable "sqs_config" {
  type = map(object({
    delay_seconds              = number
    max_message_size           = number
    message_retention_seconds  = number
    receive_wait_time_seconds  = number
    visibility_timeout_seconds = number
    fifo_queue                 = bool
    kms_master_key_id          = string
    dead_letter_queue          = bool
    statements = list(object({
      sid         = string
      actions     = list(string)
      resources   = list(string)
      effect      = string
      type        = string
      identifiers = list(string)
      condition = list(object({
        test     = string
        variable = string
        values   = list(string)
      }))
    }))
    application     = string
    additional_tags = optional(map(string), {})
    redrive_policy = optional(object({
      max_receive_count             = number
      dlq_message_retention_seconds = optional(number, 1209600)
    }), null)
  }))
  default = {}
}

######################################################################
# Secrets Manager — secreto vacío de las APIs
# kms_key_id vacío = los locals inyectan la llave KMS sm
######################################################################
variable "secrets_config" {
  type = map(object({
    description             = string
    kms_key_id              = optional(string, "")
    recovery_window_in_days = optional(number, 7)
    create_secret_version   = optional(bool, false)
    additional_tags         = optional(map(string), {})
  }))
  default = {}
}

######################################################################
# API Gateway REST — API key + usage plan + VPC Link V2 hacia el ALB
######################################################################
variable "api_stage_name" {
  type        = string
  description = "Stage del REST API"
  default     = "dev"
}

variable "api_throttle_rate_limit" {
  type        = number
  description = "Peticiones por segundo del usage plan"
  default     = 20
}

variable "api_throttle_burst_limit" {
  type        = number
  description = "Ráfaga máxima del usage plan"
  default     = 40
}
