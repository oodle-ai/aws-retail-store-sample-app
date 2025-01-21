resource "aws_ecs_cluster" "cluster" {
  name = "${var.environment_name}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "${var.environment_name}-tasks"
  retention_in_days = 1
}
