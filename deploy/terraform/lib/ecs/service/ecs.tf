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
data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment_name}-${var.service_name}"
  container_definitions    = <<DEFINITION
    [{
      "name": "application",
      "image": "${var.container_image}",
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
      "environment": ${local.environment},
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
        "logDriver": "awsfirelens"
      }
    },
    {
      "name": "otel-collector",
      "image": "${var.otel_collector_image}",
      "essential": true,
      "memory": 200,
      "environment": [
        {
          "name": "OODLE_API_KEY",
          "value": "${var.oodle_api_key}"
        },
        {
          "name": "OODLE_ENDPOINT",
          "value": "${var.oodle_endpoint}"
        },
        {
          "name": "OODLE_INSTANCE",
          "value": "${var.oodle_instance}"
        },
        {
          "name": "CLOUDWATCH_LOG_GROUP",
          "value": "${var.cloudwatch_logs_group_id}"
        },
        {
          "name": "CLOUDWATCH_LOG_STREAM",
          "value": "${var.service_name}-application"
        }
      ],
      "command": ["--config", "https://oodle-configs.s3.us-west-2.amazonaws.com/logs/ecs/otel/otel-config-v1.yaml"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${var.cloudwatch_logs_group_id}",
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-stream-prefix": "${var.service_name}-otel"
        }
      },
      "firelensConfiguration": {
        "type": "fluentbit"
      }
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
}

resource "aws_ecs_service" "this" {
  name                   = var.service_name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

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

resource "aws_iam_role_policy" "task_role_cloudwatch_logs" {
  name = "${var.environment_name}-${var.service_name}-task-cloudwatch-logs"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.cloudwatch_logs_group_id}:*"
      }
    ]
  })
}
