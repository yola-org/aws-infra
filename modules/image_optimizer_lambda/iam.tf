data "aws_kms_key" "primary_jdbc" {
  count  = try(trimspace(var.primary_jdbc_secret.kms_key_id), "") == "" ? 0 : 1
  key_id = var.primary_jdbc_secret.kms_key_id
}

resource "aws_iam_role" "lambda" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ReadPrimaryJdbcSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.primary_jdbc_secret.arn
      },
      {
        Sid    = "ConsumeOptimizerQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = var.queue_arn
      },
      {
        Sid      = "PublishListingNotifications"
        Effect   = "Allow"
        Action   = ["appsync:EventPublish"]
        Resource = var.notification_namespace_arn
      },
      {
        Sid    = "ModerateListingImages"
        Effect = "Allow"
        Action = ["rekognition:DetectModerationLabels"]
        # DetectModerationLabels does not support resource-level permissions.
        Resource = "*"
      },
      {
        Sid      = "ListAssetsBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.bucket_arn
      },
      {
        Sid    = "ReadWriteAssets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${var.bucket_arn}/*"
      },
      ], [for key in data.aws_kms_key.primary_jdbc : {
        Sid      = "DecryptPrimaryJdbcSecret"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = key.arn
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:SecretARN" = var.primary_jdbc_secret.arn
          }
        }
    }])
  })
}
