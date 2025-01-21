output "ui_service_url" {
  description = "URL of the UI component"
  value       = "http://${module.alb.lb_dns_name}"
}

output "catalog_security_group_id" {
  value = module.catalog_service.task_security_group_id
}

output "checkout_security_group_id" {
  value = module.checkout_service.task_security_group_id
}

output "orders_security_group_id" {
  value = module.orders_service.task_security_group_id
}

output "ecs_instance_security_group_id" {
  value       = aws_security_group.ecs_instances.id
}

output "route53_zone_id" {
  value       = aws_route53_zone.private.zone_id
}

output "route53_zone_name" {
  value       = aws_route53_zone.private.name
}
