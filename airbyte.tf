resource "kubernetes_namespace" "airbyte" {
  metadata {
    name = "airbyte"
  }
}

resource "helm_release" "airbyte" {
  name       = "airbyte"
  repository = "https://airbytehq.github.io/helm-charts"
  chart      = "airbyte"
  namespace  = kubernetes_namespace.airbyte.metadata[0].name
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

  ingress {
    description = "Airbyte API"
    from_port   = 8001
    to_port     = 8001
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

locals {
  airbyte_webapp_host = try(data.kubernetes_service.airbyte_webapp.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

# provider "airbyte" {
#   username   = "airbyte"
#   password   = "password"
#   server_url = "http://localhost:8000/api/public/v1/"
# }

# resource "airbyte_workspace" "solution_team_workspace" {
#   name = "Solution Team Workspace"
# }

// Airbyte Terraform provider documentation: https://registry.terraform.io/providers/airbytehq/airbyte/latest/docs

# 1st

# resource "airbyte_source_s3" "s3" {
#   configuration = {
#     source_type  = "s3"
#     bucket       = module.s3_bucket.s3_bucket_id
#     endpoint     = "https://s3.amazonaws.com"
#     path_pattern = "**"
#     format = {
#       csv = {
#         delimiter   = ","
#         quote_char  = "\""
#         escape_char = "\\"
#         null_values = ["null"]
#         skip_header = true
#       }
#     }
#     provider = {
#       bucket      = module.s3_bucket.s3_bucket_id
#       endpoint    = "https://s3.amazonaws.com"
#       path_prefix = local.source_files_s3_path
#       region_name = module.s3_bucket.s3_bucket_region
#       start_date  = "2021-01-01T00:00:00Z"
#     }
#     streams = [
#       {
#         name      = "my_stream"
#         file_type = "csv"
#         format = {
#           csv_format = {
#             filetype = "csv"
#           }
#         }
#       },
#     ]
#   }
#   name         = "s3-csv-source"
#   workspace_id = airbyte_workspace.solution_team_workspace.workspace_id
# }

# resource "airbyte_destination_postgres" "postgres" {
#   name         = "PostgreSQL Destination"
#   workspace_id = airbyte_workspace.solution_team_workspace.workspace_id
#   configuration = {
#     database = "postgres"
#     host     = aws_db_instance.postgres.address
#     port     = aws_db_instance.postgres.port
#     username = aws_db_instance.postgres.username
#     password = aws_db_instance.postgres.password
#   }
# }

# resource "airbyte_connection" "s3_to_postgres" {
#   name           = "S3 to Postgres"
#   source_id      = airbyte_source_s3.s3.source_id
#   destination_id = airbyte_destination_postgres.postgres.destination_id
# }

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
