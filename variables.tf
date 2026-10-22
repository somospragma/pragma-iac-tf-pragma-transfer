######################################################################
# Variables Globales
######################################################################
# Los valores vienen de environments/<env>/terraform.tfvars, salvo
# deploy_role_arn, que el template del pipeline pasa desde la library
# (AWS_DEPLOY_ROLE).

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
# Variables de Red
######################################################################
variable "availability_zone" {
  type        = string
  description = "Única zona de disponibilidad del ambiente"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un CIDR válido, p. ej. 10.20.0.0/16."
  }
}

######################################################################
# Variables de Cómputo (ECS Fargate)
######################################################################
variable "ecr_repository_name" {
  type        = string
  description = "Repositorio ECR preexistente de la imagen del micro"
}

variable "bootstrap_image_tag" {
  type        = string
  description = "Tag de la imagen para la primera task definition; luego la gestiona el pipeline del micro"
  default     = "latest"
}

variable "ms_desired_count" {
  type        = number
  description = "Número de tareas del servicio ms-transfers"
  default     = 2
}

######################################################################
# Variables de API Gateway (JWT)
######################################################################
variable "jwt_issuer" {
  type        = string
  description = "Issuer del authorizer JWT de API Gateway"
}

variable "jwt_audience" {
  type        = string
  description = "Audience del authorizer JWT de API Gateway"
}
