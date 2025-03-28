module "catalog_service" {
  source = "./service"

  datadog_api_key = var.datadog_api_key
  datadog_site    = var.datadog_site
  oodle_api_key  = var.oodle_api_key
  oodle_site     = var.oodle_site
  oodle_log_collector_host = var.oodle_log_collector_host
  oodle_instance = var.oodle_instance

  environment_name                = var.environment_name
  service_name                    = "catalog"
  cluster_arn                     = aws_ecs_cluster.cluster.arn
  vpc_id                          = var.vpc_id
  vpc_cidr                        = var.vpc_cidr
  subnet_ids                      = var.subnet_ids
  public_subnet_ids               = var.public_subnet_ids
  tags                            = var.tags
  container_image                 = module.container_images.result.catalog.url
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  route53_zone_id                 = aws_route53_zone.private.zone_id
  
  environment_variables = {
    DB_NAME = var.catalog_db_name
  }

  secrets = {
    DB_ENDPOINT = "${aws_secretsmanager_secret_version.catalog_db.arn}:host::"
    DB_USER     = "${aws_secretsmanager_secret_version.catalog_db.arn}:username::"
    DB_PASSWORD = "${aws_secretsmanager_secret_version.catalog_db.arn}:password::"
  }

  additional_task_execution_role_iam_policy_arns = [
    aws_iam_policy.catalog_policy.arn
  ]
}

data "aws_iam_policy_document" "catalog_db_secret" {
  statement {
    sid = ""
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt*"
    ]
    effect = "Allow"
    resources = [
      aws_secretsmanager_secret.catalog_db.arn,
      aws_kms_key.cmk.arn
    ]
  }
}

resource "aws_iam_policy" "catalog_policy" {
  name        = "${var.environment_name}-catalog"
  path        = "/"
  description = "Policy for catalog"

  policy = data.aws_iam_policy_document.catalog_db_secret.json
}

resource "random_string" "random_catalog_secret" {
  length  = 4
  special = false
}

resource "aws_secretsmanager_secret" "catalog_db" {
  name       = "${var.environment_name}-catalog-db-${random_string.random_catalog_secret.result}"
  kms_key_id = aws_kms_key.cmk.key_id
}

resource "aws_secretsmanager_secret_version" "catalog_db" {
  secret_id = aws_secretsmanager_secret.catalog_db.id

  secret_string = jsonencode(
    {
      username = var.catalog_db_username
      password = var.catalog_db_password
      host     = "${var.catalog_db_endpoint}:${var.catalog_db_port}"
    }
  )
}
