############################################################################
# Local Values
############################################################################

locals {
  # Nomenclatura: {client}-{project}-{environment}-{type}-{key}
  # p. ej. pragma-transfers-qa-ecs-ms-transfers
  name_prefix = "${var.client}-${var.project}-${var.environment}"
}
