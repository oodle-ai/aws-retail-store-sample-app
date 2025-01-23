resource "aws_ecs_task_definition" "datadog_agent" {
  family                   = "${var.environment_name}-datadog-agent"
  requires_compatibilities = ["EC2"]
  network_mode            = "host"
  task_role_arn = aws_iam_role.datadog_agent_task_role.arn
  execution_role_arn = aws_iam_role.datadog_agent_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "datadog-agent"
      image = "public.ecr.aws/datadog/agent:latest"
      
      environment = [
        {
          name  = "DD_API_KEY"
          value = var.datadog_api_key
        },
        {
          name  = "DD_SITE"
          value = "us5.datadoghq.com"
        },
        {
          name  = "DD_ADDITIONAL_ENDPOINTS"
          value = "{\"${var.oodle_site}\": [\"${var.oodle_api_key}\"]}"
        },
        {
          name  = "DD_ECS_COLLECT_RESOURCE_TAGS_EC2"
          value = "false"
        },
        {
          name  = "DD_APM_ENABLED"
          value = "false"
        },
        {
          name  = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
          value = "true"
        }
      ]

      portMappings = [
        {
          containerPort = 8125
          hostPort      = 8125
          protocol      = "udp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "docker_sock"
          containerPath = "/var/run/docker.sock"
          readOnly      = true
        },
        {
          sourceVolume  = "proc"
          containerPath = "/host/proc"
          readOnly      = true
        },
        {
          sourceVolume  = "cgroup"
          containerPath = "/host/sys/fs/cgroup"
          readOnly      = true
        }
      ]

      cpu         = 256
      memory      = 512
      essential   = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment_name}-cluster/datadog-agent"
          awslogs-region        = "us-west-2"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  volume {
    name      = "docker_sock"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "cgroup"
    host_path = "/sys/fs/cgroup"
  }
}

resource "aws_security_group" "datadog_agent" {
  name        = "${var.environment_name}-datadog-agent"
  description = "Security group for Datadog agent"
  vpc_id      = var.vpc_id

  # Allow inbound StatsD metrics
  ingress {
    from_port   = 8125
    to_port     = 8125
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]  # Or more specific CIDR range if needed
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment_name}-datadog-agent"
    Environment = var.environment_name
  }
}

resource "aws_ecs_service" "datadog_agent" {
  name                = "datadog-agent"
  cluster             = aws_ecs_cluster.cluster.arn
  task_definition     = aws_ecs_task_definition.datadog_agent.arn
  scheduling_strategy = "DAEMON"
  enable_execute_command = true

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
}

# CloudWatch Log Group for Datadog Agent
resource "aws_cloudwatch_log_group" "datadog_agent" {
  name              = "/ecs/${var.environment_name}-cluster/datadog-agent"
  retention_in_days = 1
}

# Add IAM roles and policies for execute command
resource "aws_iam_role" "datadog_agent_task_role" {
  name = "${var.environment_name}-datadog-agent-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "datadog_agent_task_policy" {
  name = "${var.environment_name}-datadog-agent-task-policy"
  role = aws_iam_role.datadog_agent_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "datadog_agent_execution_role" {
  name = "${var.environment_name}-datadog-agent-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "datadog_agent_execution_policy" {
  role       = aws_iam_role.datadog_agent_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
