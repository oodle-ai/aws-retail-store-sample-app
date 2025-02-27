module "carts_service" {
  source = "./service"

  datadog_api_key = var.datadog_api_key
  datadog_site    = var.datadog_site
  oodle_api_key  = var.oodle_api_key
  oodle_site     = var.oodle_site
  oodle_log_collector_host = var.oodle_log_collector_host
  oodle_instance = var.oodle_instance

  environment_name                = var.environment_name
  service_name                    = "carts"
  cluster_arn                     = aws_ecs_cluster.cluster.arn
  vpc_id                          = var.vpc_id
  vpc_cidr                        = var.vpc_cidr
  subnet_ids                      = var.subnet_ids
  public_subnet_ids               = var.public_subnet_ids
  tags                            = var.tags
  container_image                 = module.container_images.result.cart.url
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/actuator/health"
  route53_zone_id                 = aws_route53_zone.private.zone_id

  environment_variables = {
    CARTS_DYNAMODB_TABLENAME = var.carts_dynamodb_table_name
    SPRING_PROFILES_ACTIVE   = "dynamodb"
  }

  additional_task_role_iam_policy_arns = [
    var.carts_dynamodb_policy_arn
  ]
}
