### start of the first uncomment task
resource "kubernetes_namespace" "airbyte" {
  metadata {
    name = "airbyte"
  }
}

resource "helm_release" "airbyte" {
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/helm-charts"
  chart            = "airbyte"
  version          = "1.1.0"
  namespace        = kubernetes_namespace.airbyte.metadata[0].name
  create_namespace = true

  set {
    name  = "webapp.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}
### end of the first uncomment task

### start of the second uncomment task

data "kubernetes_service" "airbyte_webapp" {
  metadata {
    name      = "airbyte-airbyte-webapp-svc"
    namespace = kubernetes_namespace.airbyte.metadata[0].name
  }
  depends_on = [helm_release.airbyte]
}

data "kubernetes_service" "airbyte_server" {
  metadata {
    name      = "airbyte-airbyte-server-svc"
    namespace = kubernetes_namespace.airbyte.metadata[0].name
  }
  depends_on = [helm_release.airbyte]
}

locals {
  airbyte_webapp_host = try(
    data.kubernetes_service.airbyte_webapp.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service.airbyte_webapp.status[0].load_balancer[0].ingress[0].ip,
    "pending"
  )
  airbyte_server_host = try(
    data.kubernetes_service.airbyte_server.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service.airbyte_server.status[0].load_balancer[0].ingress[0].ip,
    "pending"
  )
}

resource "null_resource" "wait_for_airbyte_server" {
  depends_on = [data.kubernetes_service.airbyte_server]

  provisioner "local-exec" {
    command = "while [[ ${local.airbyte_server_host} == 'pending' ]]; do sleep 10; done"
  }
}

output "airbyte_webapp_url" {
  value = "http://${local.airbyte_webapp_host}"
}

output "airbyte_server_host" {
  value       = local.airbyte_server_host
  description = "The hostname or IP address of the Airbyte server"
}

### end of the second uncomment task

### start of the third uncomment task

resource "aws_iam_user" "airbyte_user" {
  name = "airbyte-s3-user"
}

resource "aws_iam_access_key" "airbyte_user" {
  user = aws_iam_user.airbyte_user.name
  depends_on = [
    aws_iam_user.airbyte_user
  ]
}

resource "aws_iam_policy" "airbyte_s3_policy" {
  name        = "airbyte-s3-access-policy"
  path        = "/"
  description = "IAM policy for Airbyte S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucket*",
          "s3:ListBucket*",
          "s3:GetObject*",
          "s3:PutObject*"
        ]
        Resource = [
          module.s3_bucket.s3_bucket_arn,
          "${module.s3_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "airbyte_policy_attach" {
  user       = aws_iam_user.airbyte_user.name
  policy_arn = aws_iam_policy.airbyte_s3_policy.arn
  depends_on = [
    aws_iam_user.airbyte_user,
    aws_iam_policy.airbyte_s3_policy
  ]
}

resource "aws_security_group" "airbyte_public_sg" {
  name        = "${local.name}-airbyte-public-sg"
  description = "Security group for public Airbyte access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

provider "airbyte" {
  username   = "airbyte"
  password   = "password"
  server_url = "http://${local.airbyte_server_host}:8001/api/public/v1/"
}

resource "airbyte_workspace" "solution_team_workspace" {
  name       = "Default Workspace"
  depends_on = [null_resource.wait_for_airbyte_server]
}

// Airbyte Terraform provider documentation: https://registry.terraform.io/providers/airbytehq/airbyte/latest/docs

# 1st batch

resource "airbyte_source_s3" "s3" {
  configuration = {
    aws_access_key_id     = aws_iam_access_key.airbyte_user.id
    aws_secret_access_key = aws_iam_access_key.airbyte_user.secret
    bucket                = module.s3_bucket.s3_bucket_id
    region_name           = module.s3_bucket.s3_bucket_region
    path_pattern          = "**"
    streams = [
      {
        days_to_sync_if_history_is_full = 6
        format = {
          csv_format = {
            double_as_string = true
          }
        }
        globs = [
          "${local.source_files_s3_path}/*.csv",
        ]
        name                                        = "csv_stream"
        recent_n_files_to_read_for_schema_discovery = 1
        schemaless                                  = false
        validation_policy                           = "Emit Record"
      },
    ]
  }
  name         = "s3_bucket_with_source"
  workspace_id = airbyte_workspace.solution_team_workspace.workspace_id

  depends_on = [
    aws_iam_user_policy_attachment.airbyte_policy_attach,
    aws_s3_bucket_policy.mwaa_bucket_policy
  ]
}

resource "airbyte_destination_postgres" "postgres" {
  name         = "PostgreSQL"
  workspace_id = airbyte_workspace.solution_team_workspace.workspace_id
  configuration = {
    database = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    username = aws_db_instance.postgres.username
    password = aws_db_instance.postgres.password
  }
}

resource "airbyte_connection" "s3_to_postgres" {
  name           = "S3_to_Postgres"
  source_id      = airbyte_source_s3.s3.source_id
  destination_id = airbyte_destination_postgres.postgres.destination_id
  configurations = {
    streams = [
      {
        name        = "csv_stream"
        sync_mode   = "full_refresh_overwrite"
        primary_key = [["Customer ID"]]
      }
    ]
  }
  schedule = {
    schedule_type = "manual"
  }
  status = "active"
}

# # 2nd batch 

resource "airbyte_source_s3" "s3_with_dim" {
  configuration = {
    aws_access_key_id     = aws_iam_access_key.airbyte_user.id
    aws_secret_access_key = aws_iam_access_key.airbyte_user.secret
    bucket                = module.s3_bucket.s3_bucket_id
    region_name           = module.s3_bucket.s3_bucket_region
    path_pattern          = "**"
    streams = [
      {
        days_to_sync_if_history_is_full = 6
        format = {
          csv_format = {
            double_as_string = true
          }
        }
        globs = [
          "${local.dim_project_s3_path}/*.csv",
        ]
        name                                        = "DIM_PROJECT"
        recent_n_files_to_read_for_schema_discovery = 1
        schemaless                                  = false
        validation_policy                           = "Emit Record"
      },
    ]
  }
  name         = "s3_bucket_with_dim"
  workspace_id = airbyte_workspace.solution_team_workspace.workspace_id

  depends_on = [
    aws_iam_user_policy_attachment.airbyte_policy_attach,
    aws_s3_bucket_policy.mwaa_bucket_policy
  ]
}

resource "airbyte_destination_snowflake" "snowflake" {
  configuration = {
    credentials = {
      username_and_password = {
        password = "hRjRTs^4!J7GE2!"
      }
    }
    database         = "superside"
    destination_type = "snowflake"
    host             = "czb09219.us-east-1.snowflakecomputing.com"
    raw_data_schema  = "PUBLIC"
    role             = "ACCOUNTADMIN"
    schema           = "PUBLIC"
    username         = "lucasudar"
    warehouse        = "COMPUTE_WH"
  }
  name         = "Snowflake"
  workspace_id = airbyte_workspace.solution_team_workspace.workspace_id
}

resource "airbyte_connection" "s3_to_snowflake" {
  name           = "S3_to_Snowflake"
  source_id      = airbyte_source_s3.s3_with_dim.source_id
  destination_id = airbyte_destination_snowflake.snowflake.destination_id
  configurations = {
    streams = [
      {
        name        = "DIM_PROJECT"
        sync_mode   = "full_refresh_overwrite"
        primary_key = [["ID"]]
      }
    ]
  }
  schedule = {
    schedule_type = "manual"
  }
  status = "active"
}