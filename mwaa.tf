#------------------------------------------------------------------------
# AWS MWAA Module
#------------------------------------------------------------------------

module "mwaa" {
  source  = "aws-ia/mwaa/aws"
  version = "0.0.4"

  depends_on = [aws_s3_object.uploads, module.vpc_endpoints, aws_s3_bucket_policy.mwaa_bucket_policy]

  name                  = local.name
  airflow_version       = "2.5.1"
  environment_class     = "mw1.medium"
  webserver_access_mode = "PUBLIC_ONLY"

  create_s3_bucket  = false
  source_bucket_arn = module.s3_bucket.s3_bucket_arn

  dag_s3_path          = local.dag_s3_path
  requirements_s3_path = "${local.dag_s3_path}/requirements.txt"

  min_workers = 1
  max_workers = 25

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  source_cidr        = [module.vpc.vpc_cidr_block]

  airflow_configuration_options = {
    "core.load_default_connections" = "false"
    "core.load_examples"            = "false"
    "webserver.dag_default_view"    = "tree"
    "webserver.dag_orientation"     = "TB"
    "logging.logging_level"         = "INFO"
  }

  logging_configuration = {
    dag_processing_logs = {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs = {
      enabled   = true
      log_level = "INFO"
    }

    task_logs = {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs = {
      enabled   = true
      log_level = "INFO"
    }

    worker_logs = {
      enabled   = true
      log_level = "INFO"
    }
  }

  tags = local.tags
}

#------------------------------------------------------------------------
# Dags and Requirements
#------------------------------------------------------------------------

#tfsec:ignore:*
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.14"

  bucket = "mwaa-${random_id.this.hex}"

  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  tags = local.tags
}

resource "aws_s3_bucket_policy" "mwaa_bucket_policy" {
  bucket = module.s3_bucket.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMWAAAccess"
        Effect = "Allow"
        Principal = {
          Service = "airflow.amazonaws.com"
        }
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
  depends_on = [
    module.s3_bucket
  ]
}


# Kubeconfig is required for KubernetesPodOperator
# https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/operators.html
locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "mwaa"
    clusters = [{
      name = module.eks.cluster_arn
      cluster = {
        certificate-authority-data = module.eks.cluster_certificate_authority_data
        server                     = module.eks.cluster_endpoint
      }
    }]
    contexts = [{
      name = "mwaa" # must match KubernetesPodOperator context
      context = {
        cluster = module.eks.cluster_arn
        user    = "mwaa"
      }
    }]
    users = [{
      name = "mwaa"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args = [
            "--region",
            local.region,
            "eks",
            "get-token",
            "--cluster-name",
            local.name
          ]
        }
      }
    }]
  })
}

resource "aws_s3_object" "kube_config" {
  bucket  = module.s3_bucket.s3_bucket_id
  key     = "${local.dag_s3_path}/kube_config.yaml"
  content = local.kubeconfig
  etag    = md5(local.kubeconfig)
}

resource "aws_s3_object" "uploads" {
  for_each = fileset("${local.dag_s3_path}/", "*")

  bucket = module.s3_bucket.s3_bucket_id
  key    = "${local.dag_s3_path}/${each.value}"
  source = "${local.dag_s3_path}/${each.value}"
  etag   = filemd5("${local.dag_s3_path}/${each.value}")
}

resource "random_id" "this" {
  byte_length = "2"
}

#------------------------------------------------------------------------
# Create K8s Namespace and Role for mwaa access directly
#------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "mwaa" {
  metadata {
    annotations = {
      name = "mwaa"
    }

    name = "mwaa"
  }
}

resource "kubernetes_role_v1" "mwaa" {
  metadata {
    name      = "mwaa-role"
    namespace = kubernetes_namespace_v1.mwaa.metadata[0].name
  }

  rule {
    api_groups = [
      "",
      "apps",
      "batch",
      "extensions",
    ]
    resources = [
      "jobs",
      "pods",
      "pods/attach",
      "pods/exec",
      "pods/log",
      "pods/portforward",
      "secrets",
      "services",
    ]
    verbs = [
      "create",
      "delete",
      "describe",
      "get",
      "list",
      "patch",
      "update",
    ]
  }
}

resource "kubernetes_role_binding_v1" "mwaa" {
  metadata {
    name      = "mwaa-role-binding"
    namespace = kubernetes_namespace_v1.mwaa.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_namespace_v1.mwaa.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "mwaa-service"
    api_group = "rbac.authorization.k8s.io"
  }
}
