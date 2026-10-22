# pragma-iac-tf-pragma-transfer

Infraestructura como código (Terraform) de la **capa de aplicación (core)** de **ms-transfers** en AWS, ambiente **dev**, cuenta `123456789012`. Crea los recursos propios del micro: entrada por API Gateway REST con API key, servicios ECS (micro y mocks), DynamoDB, SNS/SQS, el secreto de las APIs, KMS, IAM y la integración con el NLB de la capa transversal.

Depende de **networking** (`pragma-iac-tf-pragma-networking`) y **transversal** (`pragma-iac-tf-pragma-share`), que consume con `data`. Usa los **módulos de referencia de somospragma** (GitHub público).

> Rama de trabajo: **develop**. `main` está vacío (no se usa).

---

## Arquitectura de referencia

```
   Cliente
     │  HTTPS + header x-api-key
     ▼
┌─────────────────────────┐
│   API Gateway REST      │  usage plan (rate 20 / burst 40 / quota 10k mes)
│   /{proxy+} ANY         │  sin x-api-key → 403 (no llega al micro)
└───────────┬─────────────┘
            │  VPC Link (V1) → integración HTTP_PROXY
            ▼
┌─────────────────────────┐
│   NLB interno (share)   │  listener TCP:80
└───────────┬─────────────┘
            │  target group TCP:8080 (ip)
            ▼
┌─────────────────────────┐
│  ECS Fargate (cluster   │  ms-transfers (2 tareas)
│  compartido del share)  │  mocks (1 tarea, WireMock)
│  Service Connect        │  mocks:8080 / ms-transfers:8080
└───────────┬─────────────┘
            │
   ┌────────┼─────────────────────────────┐
   ▼        ▼              ▼               ▼
DynamoDB   SNS          SQS            Secrets Manager
transfers  transfers-   notifications  secret/apis (vacío,
idempotency events   →  + DLQ          lo llena el micro)
recipient-tokens
   (todo cifrado con KMS propia por servicio)
```

Las tareas corren en subredes **privadas**. La entrada pública es solo el API Gateway con `x-api-key`. El micro apunta `CORE_BASE_URL`, `FRAUD_BASE_URL` y `DIRECTORY_BASE_URL` a `mocks:8080` (Service Connect).

---

## Recursos que crea

| # | Recurso | Módulo | Versión |
|---|---------|--------|---------|
| 1 | KMS (sm, dynamo, sns, sqs) | `cloudops-ref-repo-aws-kms-terraform` | `v1.0.0` |
| 2 | DynamoDB (3 tablas) | `cloudops-ref-repo-aws-dynamo-terraform` | `v2.1.1` |
| 3 | SNS `transfers-events` | `cloudops-ref-repo-aws-sns-terraform` | `v1.0.0` |
| 4 | SQS `notifications` + DLQ | `cloudops-ref-repo-aws-sqs-terraform` | `v1.0.4` |
| 5 | Secret vacío de las APIs | `cloudops-ref-repo-aws-sm-terraform` | `v1.0.0` |
| 6 | SG de las tareas ECS | `cloudops-ref-repo-aws-sg-terraform` | `v1.0.2` |
| 7 | IAM execution + task role | `cloudops-ref-repo-aws-iam-terraform` | `v1.0.1` |
| 8 | ECS services (micro + mocks) | `cloudops-ref-repo-aws-ecs-service-terraform` | `v1.0.3` |
| 9 | ALB/NLB Listener + Target Group | `cloudops-ref-repo-aws-elb-listener-terraform` | `v1.0.4` |
| 10 | API Gateway REST + API key + usage plan | `cloudops-ref-repo-aws-api-gateway-terraform` | `v1.0.0` |
| 11 | VPC Link (recurso propio) | `aws_api_gateway_vpc_link` | — |

---

## Consume con `data` (de networking y share)

| Recurso | Nombre |
|---------|--------|
| VPC | `pragma-transfers-dev-vpc` |
| Subredes privadas | `*private*` |
| NLB interno | `pragma-transfers-dev-nlb-trf` |
| ECS Cluster | `pragma-transfers-dev-cluster-ms-transfers` |
| Cloud Map namespace | `pragma-transfers-dev-ns-service-connect` |
| ECR micro | `pragma-transfers-dev-ecr-ms-transfers` |
| ECR mocks | `pragma-transfers-dev-ecr-mocks` |

---

## Inventario DEV (cuenta 123456789012)

> Valores reales confirmados contra AWS.

### KMS
`alias/pragma-transfers-dev-kms-sm` · `-dynamo` · `-sns` · `-sqs`

### DynamoDB (on-demand)
| Tabla | TTL |
|-------|-----|
| `pragma-transfers-dev-ddb-transfers-transfers` | no |
| `pragma-transfers-dev-ddb-transfers-idempotency` | sí (`expiresAt`) |
| `pragma-transfers-dev-ddb-transfers-recipient-tokens` | sí (`expiresAt`) |

### Mensajería
| Recurso | Nombre |
|---------|--------|
| SNS topic | `pragma-transfers-dev-sns-transfers-events` |
| SQS cola | `pragma-transfers-dev-sqs-notifications` |
| SQS DLQ | `pragma-transfers-dev-dlq-notifications` |

### Secrets Manager
| Secreto | `pragma/transfers/dev/secret/apis` (vacío, cifrado KMS sm) |
|---|---|

### Seguridad / IAM
| Recurso | Nombre |
|---------|--------|
| SG tareas | `pragma-transfers-dev-sg-ecs` (`sg-0123456789abcdef0`) |
| Role execution | `pragma-transfers-dev-role-execution-transfers-trf` |
| Role task | `pragma-transfers-dev-role-task-transfers-trf` |
| Role API GW logs | `pragma-transfers-dev-role-apigateway-cloudwatch-transfers` |

### Cómputo (ECS — tareas en 0 hasta validar)
| Servicio | Tareas |
|----------|--------|
| `pragma-transfers-dev-ecs-service-ms-transfers` | 0 (luego 2) |
| `pragma-transfers-dev-ecs-service-mocks` | 0 (luego 1) |

### API Gateway
| Recurso | Valor |
|---------|-------|
| REST API | `pragma-transfers-dev-api-transfers` (id `abc123defg`) |
| VPC Link | `pragma-transfers-dev-vpclink` (recurso propio → NLB) |

---

## Outputs → library del micro (`pragma-ms-java-pragma-transfer`)

| Output | Variable | Para qué |
|--------|----------|----------|
| `ecs_service` | `ECS_SERVICE` | el pipeline del micro hace `force-new-deployment` |
| `secret_apis_name` | `SECRET_APIS_NAME` | el pipeline del micro escribe el valor del secreto |

> Publicados **en mayúsculas, sin prefijo** (el template ya no antepone `TF_VAR_`).

---

## Consideraciones

1. **Entrada con API key**: el API Gateway REST exige `x-api-key`. Sin el header, responde **403** y la petición no llega al micro (requisito de la HU). El valor de la key se lee con `aws apigateway get-api-key --api-key <id> --include-value`.
2. **VPC Link V1 → NLB**: el módulo `api-gateway` v1.0.0 solo implementa VPC Link **V1** (acepta NLB, no ALB). Por eso la entrada privada es un NLB (en `share`), no un ALB. El VPC Link se crea como **recurso propio** (`aws_api_gateway_vpc_link.nlb`) porque el módulo no inyecta el id del VPC Link que él crea en la integración (deja `connection_id` vacío → `PutIntegration` falla). Mejora futura: módulo con VPC Link V2 (soporta ALB) → feature branch, probar, nuevo tag.
3. **Tareas en 0**: `ms_desired_count = 0` y `mocks_desired_count = 0` hasta validar todo. Luego subir a 2 y 1. Evita que las tareas fallen mientras las imágenes `:latest` no estén completas.
4. **Imágenes `:latest`**: las task definitions apuntan a `<ecr>:latest`. El pipeline del micro sube las imágenes y reinicia las tareas; Terraform no gestiona la imagen.
5. **KMS una por servicio**: sm, dynamo, sns, sqs. SNS y SQS cifrados con CMK propia (requisito de Trivy, AVD-AWS-0095/0135).
6. **SQS `dead_letter_queue = false`** en la cola principal: con `true` el módulo le pone el prefijo `dlq-` y colisiona con su DLQ. La DLQ la crea el `redrive_policy`.
7. **Secret sin version**: Terraform crea el secreto vacío; el valor (CORE_API_KEY, FRAUD_API_KEY) lo escribe el pipeline del micro. Nunca pasa por el state.
8. **`recipient-tokens`**: TTL de 5 min; la tabla tiene TTL habilitado sobre `expiresAt` y el micro escribe ese timestamp.
9. **Trivy**: `.trivyignore` cubre `AVD-AWS-0104` (egress) y `AVD-AWS-0097` (policy SQS del módulo, no configurable).
10. **Orden de despliegue**: networking → share → **core**.

---

## Después del primer apply completo

1. Correr el pipeline del micro: sube las imágenes `:latest` y escribe el secreto.
2. Subir `ms_desired_count = 2` y `mocks_desired_count = 1`, re-aplicar.
3. Probar el API:
   ```bash
   API_KEY=$(aws apigateway get-api-key --api-key <api_key_id> --include-value --query value --output text)
   curl -i <api_base_url>/api/v1/accounts/191-0001234567/transfers -H "x-api-key:$API_KEY" -H "X-Customer-Id:CUST-000123"
   ```
   Sin `x-api-key` → 403.
