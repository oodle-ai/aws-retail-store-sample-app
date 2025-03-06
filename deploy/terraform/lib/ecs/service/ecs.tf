locals {
  environment = jsonencode([for k, v in var.environment_variables : {
    "name" : k,
    "value" : v
  }])

  secrets = jsonencode([for k, v in var.secrets : {
    "name" : k,
    "valueFrom" : v
  }])
}

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment_name}-${var.service_name}"
  container_definitions    = <<DEFINITION
    [{
      "name": "application",
      "image": "${var.container_image}",
      "imagePullPolicy": "ALWAYS",
      "cpu": 1024,
      "memory": 2048,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080,
          "name": "application",
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "readonlyRootFilesystem": false,
      "environment": ${jsonencode(concat([
        {
          "name": "ECS_ENABLE_CONTAINER_METADATA",
          "value": "true"
        },
        {
          "name": "DD_API_KEY",
          "value": var.datadog_api_key
        },
        {
          "name": "DD_SITE", 
          "value": var.datadog_site
        }
      ], jsondecode(local.environment)))},
      "secrets": ${local.secrets},
      "cpu": 0,
      "mountPoints": [],
      "volumesFrom": [],
      "healthCheck": {
        "command": [ "CMD-SHELL", "curl -f http://localhost:8080${var.healthcheck_path} || exit 1" ],
        "interval": 10,
        "startPeriod": 60,
        "retries": 3,
        "timeout": 5
      },
      "logConfiguration": {
        "logDriver": "awsfirelens",
        "options": {
          "Name": "http",
          "Host": "${var.oodle_log_collector_host}",
          "Port": "443",
          "URI": "/ingest/v1/logs",
          "Header": "X-OODLE-INSTANCE-API-KEY ${var.oodle_instance_api_key}",
          "Format": "json",
          "Compress": "gzip",
          "Json_date_key": "timestamp",
          "Json_date_format": "iso8601",
          "TLS": "On"
        }
      }
    },
    {
      "name": "log-router",
      "image": "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable",
      "essential": true,
      "memory": 200,
      "firelensConfiguration": {
        "type": "fluentbit"
      }
    }
  ]
  DEFINITION
  requires_compatibilities = []
  network_mode             = "host"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
}

resource "aws_ecs_service" "this" {
  name                   = var.service_name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = 1
  launch_type            = "EC2"
  enable_execute_command = true
  wait_for_steady_state  = true
  force_new_deployment   = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 0

  dynamic "load_balancer" {
    for_each = concat(
      var.alb_target_group_arn == "" ? [] : [{"target_group_arn": var.alb_target_group_arn}],
      [{"target_group_arn": aws_lb_target_group.internal.arn}]
    )

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = "application"
      container_port   = 8080
    }
  }
}

resource "aws_lb" "internal" {
  name               = "${var.environment_name}-${var.service_name}-int"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.subnet_ids

  tags = {
    Environment = var.environment_name
    Service     = var.service_name
  }
}

resource "aws_lb_target_group" "internal" {
  name        = "${var.environment_name}-${var.service_name}-int"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 5

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher            = "200"
    path               = var.healthcheck_path
    port               = "traffic-port"
    timeout            = 5
    unhealthy_threshold = 2
  }

  tags = {
    Environment = var.environment_name
    Service     = var.service_name
  }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal.arn
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.environment_name}-${var.service_name}-alb"
  description = "Security group for internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment_name
    Service     = var.service_name
  }
}

resource "aws_route53_record" "internal_alb" {
  zone_id = var.route53_zone_id
  name    = "${var.service_name}"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.internal.dns_name]
}

resource "aws_s3_object" "fluent_bit_config" {
  bucket = var.fluent_bit_config_bucket_name
  key    = "${var.environment_name}/${var.service_name}/fluent-bit.conf"
  source = "${path.module}/fluent-bit.conf"
  etag   = filemd5("${path.module}/fluent-bit.conf")
}
