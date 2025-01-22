resource "aws_ecs_task_definition" "dummy" {
  family                   = "${var.environment_name}-dummy"
  requires_compatibilities = ["EC2"]
  network_mode            = "bridge"
  
  container_definitions = jsonencode([
    {
      name  = "dummy"
      image = "nginx:latest"

      memory = 256
      
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NGINX_PORT"
          value = "8080"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_tasks.id
          awslogs-region        = "us-west-2"
          awslogs-stream-prefix = "dummy"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "dummy" {
  name            = "dummy"
  cluster         = aws_ecs_cluster.cluster.arn
  task_definition = aws_ecs_task_definition.dummy.arn
  desired_count   = 200

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
}

resource "aws_security_group" "dummy" {
  name        = "${var.environment_name}-dummy"
  description = "Security group for dummy service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
