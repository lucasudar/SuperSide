resource "kubernetes_namespace" "airbyte" {
  metadata {
    name = "airbyte"
  }
}

resource "helm_release" "airbyte" {
  name       = "airbyte"
  repository = "https://airbytehq.github.io/helm-charts"
  chart      = "airbyte"
  version    = "1.1.0"
  namespace  = kubernetes_namespace.airbyte.metadata[0].name

  set {
    name  = "webapp.service.type"
    value = "LoadBalancer"
  }
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
  airbyte_server_host = data.kubernetes_service.airbyte_server.spec[0].cluster_ip
}

output "airbyte_webapp_url" {
  value = "http://${local.airbyte_webapp_host}"
}

provider "airbyte" {
  username   = "airbyte"
  password   = "password"
  server_url = "http://127.0.0.1:8001/api/public/v1/"
}

resource "airbyte_workspace" "solution_team_workspace" {
  name = "Default Workspace"
}


// Airbyte Terraform provider documentation: https://registry.terraform.io/providers/airbytehq/airbyte/latest/docs

# 1st

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
          "**/*.csv",
        ]
        name                                        = "csv_stream"
        recent_n_files_to_read_for_schema_discovery = 1
        schemaless                                  = true
        validation_policy                           = "Emit Record"
      },
    ]
  }
  name         = "s3_bucket"
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
        name        = "csv_stream" # Имя потока данных
        sync_mode   = "full_refresh_overwrite"
        primary_key = [["Customer ID"]] # Первичный ключ
      }
    ]
  }
  schedule = {
    schedule_type = "manual"
  }
  status = "active"
}

# 2nd

# resource "airbyte_source_postgres" "postgres" {
#   configuration = {
#     database    = "...my_database..."
#     host        = "...my_host..."
#     username    = "postgres"
#     password    = "postgres"
#     port        = 5432
#     source_type = "postgres"
#     schemas = [
#       "...my_schema..."
#     ]
#     ssl_mode = {
#       source_postgres_ssl_modes_allow = {
#         mode = "allow"
#       }
#     }
#     tunnel_method = {
#       source_postgres_ssh_tunnel_method_no_tunnel = {
#         tunnel_method = "NO_TUNNEL"
#       }
#     }
#     replication_method = {
#       source_postgres_update_method_read_changes_using_write_ahead_log_cdc = {
#         method           = "CDC"
#         publication      = "...pub..."
#         replication_slot = "...slot..."
#       }
#     }
#   }
#   name         = "Postgres"
#   workspace_id = var.airbyte.workspace_id
# }

## Destinations
# resource "airbyte_destination_snowflake" "snowflake" {
#   configuration = {
#     credentials = {
#       destination_snowflake_authorization_method_key_pair_authentication = {
#         auth_type            = "Key Pair Authentication"
#         private_key          = "...my_private_key..."
#         private_key_password = "...my_private_key_password..."
#       }
#     }
#     database         = "AIRBYTE_DATABASE"
#     destination_type = "snowflake"
#     host             = "accountname.us-east-2.aws.snowflakecomputing.com"
#     jdbc_url_params  = "...my_jdbc_url_params..."
#     raw_data_schema  = "...my_raw_data_schema..."
#     role             = "AIRBYTE_ROLE"
#     schema           = "AIRBYTE_SCHEMA"
#     username         = "AIRBYTE_USER"
#     warehouse        = "AIRBYTE_WAREHOUSE"
#   }
#   name         = "Snowflake"
#   workspace_id = airbyte_workspace.solution_team_workspace.workspace_id
# }

# resource "airbyte_connection" "postgres_to_snowflake" {
#   name           = "Postgres to Snowflake"
#   source_id      = airbyte_source_postgres.postgres.source_id
#   destination_id = airbyte_destination_snowflake.snowflake.destination_id
#   configurations = {
#     streams = [
#       {
#         name = "...my_table_name_1..."
#       },
#       {
#         name = "...my_table_name_2..."
#       },
#     ]
#   }
# }


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
          "s3:GetObject",
          "s3:ListBucket"
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
