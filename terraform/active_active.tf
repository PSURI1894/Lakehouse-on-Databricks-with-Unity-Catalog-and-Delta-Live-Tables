# 1. Primary S3 Storage Bucket (US-East)
resource "aws_s3_bucket" "primary_lakehouse" {
  provider = aws.us_east
  bucket   = "enterprise-lakehouse-primary-us-east"
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  provider = aws.us_east
  bucket   = aws_s3_bucket.primary_lakehouse.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. Secondary S3 Storage Bucket (US-West Disaster Recovery)
resource "aws_s3_bucket" "secondary_lakehouse" {
  provider = aws.us_west
  bucket   = "enterprise-lakehouse-replica-us-west"
}

resource "aws_s3_bucket_versioning" "secondary_versioning" {
  provider = aws.us_west
  bucket   = aws_s3_bucket.secondary_lakehouse.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. IAM Replication Role Setup
resource "aws_iam_role" "replication" {
  name = "s3-lakehouse-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "replication_policy" {
  name = "s3-lakehouse-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.primary_lakehouse.arn
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.primary_lakehouse.arn}/*"
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.secondary_lakehouse.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication_attach" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

# Enable replication rules
resource "aws_s3_bucket_replication_configuration" "east_to_west" {
  provider   = aws.us_east
  depends_on = [aws_s3_bucket_versioning.primary_versioning]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary_lakehouse.id

  rule {
    id     = "active-active-replica-rule"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_lakehouse.arn
      storage_class = "STANDARD"
    }
  }
}

# 4. Databricks Storage Credentials Configuration
resource "databricks_storage_credential" "east_cred" {
  provider = databricks.us_east
  name     = "s3_east_storage_credential"
  aws_iam_role {
    role_arn = "arn:aws:iam::123456789012:role/databricks-uc-access-role"
  }
  comment = "Authorized IAM Role for Primary US-East access"
}

# 5. Databricks External Location Setup
resource "databricks_external_location" "east_external" {
  provider        = databricks.us_east
  name            = "s3_east_landing_external_location"
  url             = "s3://${aws_s3_bucket.primary_lakehouse.bucket}/landing"
  credential_name = databricks_storage_credential.east_cred.name
  comment         = "Landing external location for Auto Loader streams"
}
