output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "mwaa_webserver_url" {
  description = "MWAA Webserver Url"
  value       = module.mwaa.mwaa_webserver_url
}

output "postgres_endpoint" {
  description = "Public DNS name of database instance"
  value       = aws_db_instance.postgres.address
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.s3_bucket.s3_bucket_id
}
