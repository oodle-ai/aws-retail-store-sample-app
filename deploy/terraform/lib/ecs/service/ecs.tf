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
      "networkMode": "awsvpc",
      "readonlyRootFilesystem": false,
      "environment": ${jsonencode(concat([
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
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${var.cloudwatch_logs_group_id}",
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-stream-prefix": "${var.service_name}-service"
        }
      }
    },
    {
      "name": "datadog-agent",
      "image": "public.ecr.aws/datadog/agent:latest",
      "cpu": 100,
      "memory": 256,
      "essential": true,
      "environment": [
        {
          "name": "DD_APM_ENABLED",
          "value": "false"
        },
        {
          "name": "DD_APM_NON_LOCAL_TRAFFIC",
          "value": "false"
        },
        {
          "name": "DD_LOGS_ENABLED",
          "value": "false"
        },
        {
          "name": "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL",
          "value": "false"
        },
        {
          "name": "DD_CONTAINER_EXCLUDE",
          "value": "name:datadog-agent"
        },
        {
          "name": "ECS_FARGATE",
          "value": "false"
        },
        {
          "name": "DD_API_KEY",
          "value": "${var.datadog_api_key}"
        },
        {
          "name": "DD_SITE",
          "value": "${var.datadog_site}"
        },
        {
          "name": "DD_DOGSTATSD_NON_LOCAL_TRAFFIC",
          "value": "true"
        },
        {
          "name": "DD_ADDITIONAL_ENDPOINTS",
          "value": "{\"${var.oodle_site}\": [\"${var.oodle_api_key}\"]}"
        }
      ],
      "mountPoints": [],
      "volumesFrom": [],
      "portMappings": [
        {
          "containerPort": 8126,
          "hostPort": 8126,
          "protocol": "tcp"
        },
        {
          "containerPort": 8125,
          "hostPort": 8125,
          "protocol": "udp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${var.cloudwatch_logs_group_id}",
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-stream-prefix": "${var.service_name}-datadog"
        }
      } 
    }
  ]
  DEFINITION
  requires_compatibilities = []
  network_mode             = "awsvpc"
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

  network_configuration {
    security_groups  = [aws_security_group.this.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_discovery_namespace_arn
    service {
      client_alias {
        dns_name = var.service_name
        port     = "80"
      }
      discovery_name = var.service_name
      port_name      = "application"
    }
  }

  dynamic "load_balancer" {
    for_each = var.alb_target_group_arn == "" ? [] : [1]

    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = "application"
      container_port   = 8080
    }
  }
}
