# Copy source files to S3
resource "aws_s3_object" "source_files" {
  for_each = fileset("${local.source_files_s3_path}/", "*")

  bucket = module.s3_bucket.s3_bucket_id
  key    = "${local.source_files_s3_path}/${each.value}"
  source = "${local.source_files_s3_path}/${each.value}"
  etag   = filemd5("${local.source_files_s3_path}/${each.value}")
}