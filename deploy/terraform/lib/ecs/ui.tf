module "ui_service" {
  source = "./service"

  datadog_api_key = var.datadog_api_key
  datadog_site    = var.datadog_site
  oodle_api_key  = var.oodle_api_key
  oodle_site     = var.oodle_site
  oodle_log_collector_host = var.oodle_log_collector_host
  oodle_instance = var.oodle_instance

  environment_name                = var.environment_name
  service_name                    = "ui"
  cluster_arn                     = aws_ecs_cluster.cluster.arn
  vpc_id                          = var.vpc_id
  vpc_cidr                        = var.vpc_cidr
  subnet_ids                      = var.subnet_ids
  public_subnet_ids               = var.public_subnet_ids
  tags                            = var.tags
  container_image                 = module.container_images.result.ui.url
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/actuator/health"
  alb_target_group_arn            = element(module.alb.target_group_arns, 0)
  route53_zone_id                 = aws_route53_zone.private.zone_id

  environment_variables = {
    ENDPOINTS_CATALOG  = "http://${module.catalog_service.ecs_service_name}.retailstore.local"
    ENDPOINTS_CARTS    = "http://${module.carts_service.ecs_service_name}.retailstore.local"
    ENDPOINTS_CHECKOUT = "http://${module.checkout_service.ecs_service_name}.retailstore.local"
    ENDPOINTS_ORDERS   = "http://${module.orders_service.ecs_service_name}.retailstore.local"
    ENDPOINTS_ASSETS   = "http://${module.assets_service.ecs_service_name}.retailstore.local"
  }
}
