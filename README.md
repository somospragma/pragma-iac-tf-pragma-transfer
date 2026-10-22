# pragma-iac-tf-pragma-transfer

Infraestructura como código (Terraform) de **ms-transfers** de PragBank Perú en AWS, ambiente **qa**, una sola zona de disponibilidad.

> **Estado: estructura base (HU-00).** No declara recursos todavía. La **HU-02** agrega los módulos de referencia de Pragma según `docs/arquitectura-qa.drawio`. El orden y las reglas están en el encabezado de `main.tf`.

---

## Arquitectura (HU-02)

Diagrama vigente: [`docs/arquitectura-qa.drawio`](docs/arquitectura-qa.drawio).

- **Entrada:** API Gateway HTTP API (authorizer JWT) → VPC Link → **NLB interno**. No hay ALB porque exige dos zonas.
- **Cómputo:** ECS con capacidad Fargate. Servicio `ms-transfers` (2 tareas) y servicio `mocks` (WireMock, Cloud Map).
- **Red:** VPC con una subred privada en `us-east-1a`, sin NAT Gateway. VPC endpoints gateway (DynamoDB, S3) e interface (ECR, Secrets Manager, SNS, CloudWatch Logs).
- **Datos:** DynamoDB on-demand, tablas `transfers` e `idempotency` (TTL).
- **Eventos:** SNS `transfers-events` → SQS `notifications` con DLQ.
- **Secretos:** Terraform crea el secreto vacío; el valor lo escribe el pipeline del micro. Nunca pasa por el state.
- **Preexistente, solo con `data`:** repositorio ECR del micro.

---

## Estructura del proyecto

```
pragma-iac-tf-pragma-transfer/
├── main.tf                          # Definición de módulos (HU-02)
├── variables.tf                     # Variables de entrada
├── outputs.tf                       # Outputs del stack
├── locals.tf                        # Valores locales y nomenclatura
├── data.tf                          # Data sources (cuenta, región, ECR preexistente)
├── providers.tf                     # Provider AWS (assume role), versiones y backend S3
├── environments/
│   └── qa/
│       ├── terraform.tfvars         # Variables de Terraform para qa (incluye common_tags)
│       └── .env.yaml                # Variables de pipeline (library + ENVIRONMENT)
├── templates/                       # Plantillas (task definitions, etc.)
├── docs/
│   └── arquitectura-qa.drawio       # Diagrama de la infraestructura de qa
└── azure-pipelines.yaml             # Extiende el template corporativo de IaC
```

---

## Pipeline

`azure-pipelines.yaml` extiende el template corporativo `pragma-template/pragma-azure-devops-tf-pipeline` (`terraform/iac-pipeline.yml`), igual que `iac-sopp-prompt-as-a-service`. Se dispara con push a la rama **`qa`**, que carga `environments/qa/.env.yaml`.

| Etapa | Qué hace |
| --- | --- |
| Prerequisites | Extrae `common_tags` del tfvars, asume `AWS_DEPLOY_ROLE` y crea (o actualiza) el bucket del state con tags, versionado, cifrado y bloqueo público |
| CI | Instala Terraform, copia `environments/qa/terraform.tfvars` a la raíz, corre Checkov y publica el artefacto |
| Validation | `init` (backend S3 con `use_lockfile`), `fmt -check`, `validate` y `plan` |
| Approval | Espera la aprobación del environment **`qa`** (mismo nombre que la rama) |
| CD | `apply` con el tfvars del ambiente |

El bucket del state lo crea el pipeline con el nombre `$(CLIENT)-$(PROJECT)-$(ENVIRONMENT)-$(INFRASTRUCTURE)-$(CODE_APP)-terraform-state`.

### Requisitos en Azure DevOps

- **Service connection de AWS** (`aws-qa`): su rol debe poder asumir `AWS_DEPLOY_ROLE`.
- **Service connection al repo del template** `pragma-sopp-sc-alejandria` (tipo *Azure Repos/Team Foundation Server*, organización `Alejandria-Pragma`).
- **Environment `qa`** con la aprobación configurada en *Approvals and checks*.
- **Library `pragma-iac-tf-pragma-transfer`** con las variables de abajo.

### Library `pragma-iac-tf-pragma-transfer`

| Variable | Ejemplo | Para qué |
| --- | --- | --- |
| `AWS_SERVICE_CONNECTION` | `aws-qa` | Service connection de AWS que usan las tareas |
| `AWS_DEPLOY_ROLE` | `arn:aws:iam::<cuenta>:role/<rol-deploy>` | Rol que asume Terraform (provider y backend) |
| `AWS_REGION` | `us-east-1` | Región del despliegue y del bucket del state |
| `CLIENT` | `pragma` | Nombre del bucket del state |
| `PROJECT` | `transfers` | Nombre del bucket del state |
| `INFRASTRUCTURE` | `workload` | Nombre del bucket y de la llave del state |
| `CODE_APP` | `trf01` | Nombre del bucket del state (máx. 5 caracteres) |
| `TERRAFORM_VERSION` | `1.14.0` | Versión que instala el pipeline (mínimo 1.14 por `providers.tf`) |

`ENVIRONMENT` no va en la library: lo define `environments/qa/.env.yaml`. Las variables de Terraform van en `environments/qa/terraform.tfvars`. Esta library no tiene secretos.

## Requisitos del código Terraform (HU-02)

- Solo módulos de referencia de Pragma (`somospragma/cloudops-ref-repo-aws-*-terraform`), con `providers = { aws.project = aws.principal }`.
- Nomenclatura `{client}-{project}-{environment}-{type}-{key}` (`local.name_prefix`).
- `aws_ecs_service` con `lifecycle { ignore_changes = [task_definition] }`, para que Terraform no revierta las revisiones que registra el pipeline del micro.
- Secreto de Secrets Manager sin `aws_secretsmanager_secret_version`: Terraform crea el secreto vacío y el pipeline del micro escribe el valor.
- ECR con `data` source, nunca como `resource`.
- Outputs: `ecs_cluster_name`, `ecs_service_name`, `task_family`, `app_secret_name`, `api_base_url`.

## Validar en local

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
