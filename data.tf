############################################################################
# Data Sources
############################################################################
# Recursos preexistentes (HU-00): se referencian, nunca se crean aquí.
# El bucket del state solo se usa como backend (-backend-config).

data "aws_caller_identity" "current" {
  provider = aws.principal
}

data "aws_region" "current" {
  provider = aws.principal
}

data "aws_ecr_repository" "ms_transfers" {
  provider = aws.principal
  name     = var.ecr_repository_name
}
