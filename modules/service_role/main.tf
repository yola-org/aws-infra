resource "aws_iam_role" "this" {
  name = var.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "this" {
  name = "${var.name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "ReadWriteAssetsBucket"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation",
          ]
          Resource = [
            var.bucket_arn,
            "${var.bucket_arn}/*",
          ]
        },
        {
          # Both service roles get access to their environment's SQS queue —
          # backends publish image-optimization jobs to it.
          Sid      = "SendToOptimizerQueue"
          Effect   = "Allow"
          Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
          Resource = var.queue_arn
        },
      ],
      length(var.secret_read_arns) > 0 ? [
        {
          # Read this environment's allowlisted Secrets Manager entries.
          Sid      = "ReadEnvironmentSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
          Resource = var.secret_read_arns
        },
      ] : [],
      var.cognito_user_pool_arn != "" ? [
        {
          # /api/auth/login uses Cognito ADMIN_NO_SRP_AUTH.
          Sid      = "AdminInitiateAuth"
          Effect   = "Allow"
          Action   = ["cognito-idp:AdminInitiateAuth"]
          Resource = var.cognito_user_pool_arn
        },
      ] : [],
    )
  })
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}
