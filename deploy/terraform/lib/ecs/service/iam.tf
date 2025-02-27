resource "aws_iam_role" "task_execution_role" {
  name               = "${var.environment_name}-${var.service_name}-te"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "task_execution_role_additional" {
  count = length(var.additional_task_execution_role_iam_policy_arns)

  role       = aws_iam_role.task_execution_role.name
  policy_arn = var.additional_task_execution_role_iam_policy_arns[count.index]
}

resource "aws_iam_role" "task_role" {
  name               = "${var.environment_name}-${var.service_name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "task_role_additional" {
  count = length(var.additional_task_role_iam_policy_arns)

  role       = aws_iam_role.task_role.name
  policy_arn = var.additional_task_role_iam_policy_arns[count.index]
}

resource "aws_iam_role_policy_attachment" "task_role_policy" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}

resource "aws_iam_policy" "ecs_exec" {
  name        = "${var.environment_name}-${var.service_name}-exec"
  path        = "/"
  description = "ECS exec policy"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
       "Effect": "Allow",
       "Action": [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
       ],
      "Resource": "*"
      }
   ]
}
EOF
}

resource "aws_iam_policy" "firelens_cloudwatch" {
  name        = "${var.environment_name}-${var.service_name}-firelens"
  path        = "/"
  description = "FireLens CloudWatch permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:retail-store-ecs-tasks:*",
          "arn:aws:logs:*:*:log-group:retail-store-ecs-tasks:log-stream:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_role_firelens" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.firelens_cloudwatch.arn
}

resource "aws_iam_policy" "task_execution_s3_policy" {
  name        = "${var.environment_name}-${var.service_name}-s3-config"
  description = "Policy for accessing S3 config files"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.fluent_bit_config_bucket_name}",
          "arn:aws:s3:::${var.fluent_bit_config_bucket_name}/${var.environment_name}/${var.service_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_s3_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_s3_policy.arn
}
