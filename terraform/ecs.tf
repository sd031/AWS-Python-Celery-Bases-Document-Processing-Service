# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/ecs/${var.project_name}-api"
  retention_in_days = 7
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/ecs/${var.project_name}-worker"
  retention_in_days = 7
  
  tags = local.common_tags
}

# Application Load Balancer
resource "aws_lb" "api" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

# Target Group
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-api-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
  
  deregistration_delay = 30
  
  tags = local.common_tags
}

# ALB Listener
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ECS Task Definition for API
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_api.arn
  
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AWS_ACCOUNT_ID"
          value = local.account_id
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.documents.id
        },
        {
          name  = "S3_UPLOAD_PREFIX"
          value = "uploads/"
        },
        {
          name  = "S3_PROCESSED_PREFIX"
          value = "processed/"
        },
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = aws_dynamodb_table.celery_results.name
        },
        {
          name  = "JOBS_TABLE_NAME"
          value = aws_dynamodb_table.jobs.name
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.notifications.arn
        },
        {
          name  = "MAX_FILE_SIZE"
          value = tostring(var.max_file_size)
        },
        {
          name  = "ALLOWED_EXTENSIONS"
          value = var.allowed_extensions
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])
  
  tags = local.common_tags
}

# ECS Service for API
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"
  
  # Force new deployment when image is updated
  force_new_deployment = true
  
  # Deployment configuration for rolling updates
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  # Wait for tasks to be stable before considering deployment successful
  wait_for_steady_state = false
  
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }
  
  depends_on = [aws_lb_listener.api]
  
  tags = local.common_tags
  
  # Ignore changes to task_definition to allow force_new_deployment to work
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ECS Task Definition for Worker
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_worker.arn
  
  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${aws_ecr_repository.worker.repository_url}:latest"
      essential = true
      
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AWS_ACCOUNT_ID"
          value = local.account_id
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.documents.id
        },
        {
          name  = "S3_UPLOAD_PREFIX"
          value = "uploads/"
        },
        {
          name  = "S3_PROCESSED_PREFIX"
          value = "processed/"
        },
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = aws_dynamodb_table.celery_results.name
        },
        {
          name  = "JOBS_TABLE_NAME"
          value = aws_dynamodb_table.jobs.name
        },
        {
          name  = "SQS_QUEUE_NAME"
          value = aws_sqs_queue.celery.name
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.celery.url
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.notifications.arn
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])
  
  tags = local.common_tags
}

# ECS Service for Worker
resource "aws_ecs_service" "worker" {
  name            = "${var.project_name}-worker-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"
  
  # Force new deployment when image is updated
  force_new_deployment = true
  
  # Deployment configuration for rolling updates
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  # Wait for tasks to be stable before considering deployment successful
  wait_for_steady_state = false
  
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  
  tags = local.common_tags
  
  # Ignore changes to task_definition to allow force_new_deployment to work
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# Auto Scaling for Worker
resource "aws_appautoscaling_target" "worker" {
  max_capacity       = 10
  min_capacity       = var.worker_desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${var.project_name}-worker-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
