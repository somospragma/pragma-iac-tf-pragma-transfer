############################################################################
# Infraestructura de ms-transfers · ambiente qa
############################################################################
# Estructura base (HU-00): todavía no declara recursos.
# La HU-02 (#17) agrega aquí los módulos de referencia de Pragma
# (git::https://github.com/somospragma/cloudops-ref-repo-aws-*-terraform.git),
# siguiendo el diagrama docs/arquitectura-qa.drawio y este orden:
#
#   1. Red: VPC, una subred privada en var.availability_zone, sin NAT Gateway.
#      VPC endpoints gateway (DynamoDB, S3) e interface (ECR api/dkr,
#      Secrets Manager, SNS, CloudWatch Logs).
#   2. Datos: tablas DynamoDB transfers e idempotency (on-demand, TTL en idempotency).
#   3. Mensajería: SNS transfers-events -> SQS notifications con DLQ.
#   4. Secretos: secreto vacío de la app (sin aws_secretsmanager_secret_version;
#      el valor lo escribe el pipeline del micro).
#   5. Cómputo: cluster ECS Fargate, servicios ms-transfers (var.ms_desired_count)
#      y mocks (WireMock, Cloud Map). aws_ecs_service del micro con
#      lifecycle { ignore_changes = [task_definition] }.
#   6. Entrada: NLB interno -> VPC Link -> API Gateway HTTP API con authorizer JWT.
#   7. IAM (execution y task role con mínimo privilegio), log groups y alarmas.
#
# Cada módulo usa el provider con alias:
#
#   providers = {
#     aws.project = aws.principal
#   }
