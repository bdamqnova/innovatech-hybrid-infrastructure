resource "aws_autoscaling_group" "web" {
  name             = "${var.project_name}-web-asg"
  min_size         = 2
  desired_capacity = 2
  max_size         = 6

  # This is the list for creating web subnets
  vpc_zone_identifier = [
    aws_subnet.web_a.id, # Web subnet 1
    aws_subnet.web_b.id  # Web subnet 2
  ]

  # Starts a list of load balancer target groups deciding where the EC2 instances should belong
  target_group_arns = [
    aws_lb_target_group.web.arn # Connects load balancer target group to ASG
  ]

  # Using the load balancer's way of checking instance health
  health_check_type         = "ELB"
  health_check_grace_period = 180

  # Instructions for how to create a web server
  launch_template {
    id      = aws_launch_template.web.id             # Using existing launch template as a blueprint for EC2
    version = aws_launch_template.web.latest_version # Using the newest version
  }

  # Gives every EC2 instance created by the ASG a Name tag
  tag {
    key                 = "Name"
    value               = "${var.project_name}-web"
    propagate_at_launch = true # Apply this tag to every EC2 created from ASG
  }

  # Controls how AWS replaces old instances
  instance_refresh {
    strategy = "Rolling" # Replace gradually, not all at once

    # During replacement keep at least 50% of the servers healthy
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }
  }
}

resource "aws_autoscaling_policy" "web_cpu_target" {
  # Policy created for AWS to decide when to scale the instances
  name                   = "${var.project_name}-web-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name

  # Apply this policy to my web ASG
  policy_type = "TargetTrackingScaling"

  # AWS will keep the metric around a specific target
  target_tracking_configuration {
    # Target tracking policy
    predefined_metric_specification {
      # Tells AWS which metric to use
      predefined_metric_type = "ASGAverageCPUUtilization" # Average CPU for the instances
    }

    target_value = 50.0
  }

  estimated_instance_warmup = 180
}