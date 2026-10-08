# MONITORING SERVER

resource "aws_iam_role" "monitoring" { #creating IAM role
  name = "${var.project_name}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com" #generates temporary credentials instead of access keys
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-monitoring-role"
  }
}

# Allow monitoring EC2 to use Systems Manager
resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  role       = aws_iam_role.monitoring.name #tells Terraform which IAM role should receive permissions
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow Prometheus to discover running EC2 instances
resource "aws_iam_role_policy" "monitoring_ec2_discovery" { # creates a permission for the monitoring server
  name = "${var.project_name}-monitoring-ec2-discovery"
  role = aws_iam_role.monitoring.id #attach the policy to the monitoring IAM role

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances", #allowing monitoring server to look at EC2 instances and tags
          "ec2:DescribeTags"       #this makes prometheus find them automatically
        ]

        Resource = "*"
      }
    ]
  })
}

# Attach monitoring IAM role to monitoring EC2
resource "aws_iam_instance_profile" "monitoring" { #creates monitoring instance profile
  name = "${var.project_name}-monitoring-profile"
  role = aws_iam_role.monitoring.name #putting monitoring IAM role
}

# Monitoring EC2 instance
resource "aws_instance" "monitoring" {                      # creates a monitoring EC2
  ami           = data.aws_ssm_parameter.amazon_linux.value #Selecting OS- Amazon Linux system
  instance_type = "t3.small"                                #selects the server size

  subnet_id = aws_subnet.monitoring_a.id #places the monitoring server inside a monitoring subnet

  vpc_security_group_ids = [
    aws_security_group.monitoring.id #attaches a security group to the monitoring
  ]

  iam_instance_profile = aws_iam_instance_profile.monitoring.name

  associate_public_ip_address = false #no public ip

  user_data_replace_on_change = true #update if user data changes

  # automatic run by itself
  user_data = <<-EOF
    #!/bin/bash

    # Update Linux and install Docker
    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    # Create monitoring configuration folders
    mkdir -p /opt/monitoring/prometheus
    # make directories prometheus

    mkdir -p /opt/monitoring/grafana/provisioning/datasources
    # directory grafana

    mkdir -p /opt/monitoring/blackbox
    # directory folder blackbox

    # Create Prometheus configuration
    # creating prometheus configuration files
    cat > /opt/monitoring/prometheus/prometheus.yml <<'PROMEOF'
    global:
      scrape_interval: 15s   #prometheus scrape metrics every 15 seconds

    scrape_configs:

      # Prometheus monitors itself
      - job_name: "prometheus"
        static_configs:
          - targets:
              - "localhost:9090"   #running on port

      # Automatically discover web EC2 instances
      - job_name: "web-node-exporter"   #monitoring job for the web servers
        ec2_sd_configs:
          - region: ${var.aws_region}
            port: 9100   #node exporter is there : CPU , memory usage, Disk, Network
            filters:
              - name: tag:Name
                values:
                  - "${var.project_name}-web"

              - name: instance-state-name
                # find web servers that already have a name
                values:
                  - "running"   #find web servers only that are running

      # Check whether the website responds over HTTP
      - job_name: "website-health"   #checks if the website is healthy
        metrics_path: /probe

        params:
          module:
            - http_2xx

        static_configs:
          - targets:
              - "http://${aws_lb.web.dns_name}"

        relabel_configs:
          - source_labels:
              - __address__
            target_label: __param_target

          - source_labels:
              - __param_target
            target_label: instance

          - target_label: __address__
            replacement: "127.0.0.1:9115"

      # Automatically discover database EC2
      - job_name: "database"   #creating monitoring job for my database server
        ec2_sd_configs:
          # Service discovery
          - region: ${var.aws_region}
            port: 9187

            filters:
              - name: tag:Name
                values:
                  - "${var.project_name}-database"

              - name: instance-state-name
                values:
                  - "running"

    PROMEOF

    # Create Blackbox Exporter configuration
    cat > /opt/monitoring/blackbox/blackbox.yml <<'BLACKBOXEOF'
    modules:
      http_2xx:
        prober: http
        timeout: 5s
    BLACKBOXEOF

    # Configure Grafana to use Prometheus
    cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml <<'GRAFANAEOF'
    apiVersion: 1

    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://127.0.0.1:9090
        isDefault: true
    GRAFANAEOF

    # Start Blackbox Exporter
    docker run -d \
      --name blackbox-exporter \
      --restart always \
      --network host \
      -v /opt/monitoring/blackbox/blackbox.yml:/config/blackbox.yml:ro \
      prom/blackbox-exporter:latest \
      --config.file=/config/blackbox.yml

    # Start Prometheus
    docker run -d \
      --name prometheus \
      --restart always \
      --network host \
      -v /opt/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
      prom/prometheus:latest

    # Start Grafana
    docker run -d \
      --name grafana \
      --restart always \
      --network host \
      -v /opt/monitoring/grafana/provisioning:/etc/grafana/provisioning:ro \
      grafana/grafana:latest

  EOF

  # storage
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-monitoring"
  }

  depends_on = [
    aws_route_table_association.monitoring_a
  ]
}