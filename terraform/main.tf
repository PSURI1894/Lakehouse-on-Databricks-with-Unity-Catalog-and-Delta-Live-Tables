# =====================================================================
# MASTER TERRAFORM LAYOUT COORDINATION
# Centralizes standard resource tags and global infrastructure metadata.
# =====================================================================

locals {
  common_tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "Metadata-Driven Lakehouse Platform"
    Owner       = "Data Platform Group"
  }
}

# Output configurations to expose metastore configurations
output "primary_lakehouse_bucket_arn" {
  value       = aws_s3_bucket.primary_lakehouse.arn
  description = "The ARN of the primary US-East storage bucket"
}

output "secondary_lakehouse_bucket_arn" {
  value       = aws_s3_bucket.secondary_lakehouse.arn
  description = "The ARN of the replica US-West storage bucket"
}

output "delta_sharing_recipient_token_activation" {
  value       = databricks_recipient.west_consumer.authentication_type
  description = "Authentication protocol for Delta Sharing recipients"
}
