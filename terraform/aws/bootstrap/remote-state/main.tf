resource "aws_s3_bucket" "terraform_state" {
  # checkov:skip=CKV2_AWS_62:S3 event notifications are not required for the current Terraform state backend.
  # checkov:skip=CKV_AWS_144:Cross-region replication is intentionally deferred for this single-region learning environment.
  # checkov:skip=CKV_AWS_18:Access logging is deferred because this homelab does not currently maintain a dedicated log destination bucket.
  # checkov:skip=CKV2_AWS_61:A lifecycle policy is not currently required for the small persistent Terraform state backend.
  # checkov:skip=CKV_AWS_145:Terraform state is encrypted with SSE-S3; customer-managed KMS encryption is intentionally deferred.
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-remote-state"
    Environment = "Lab"
    ManagedBy   = "Terraform"
    Purpose     = "Terraform-State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
