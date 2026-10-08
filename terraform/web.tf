data "aws_ssm_parameter" "amazon_linux" {
  # Look up the latest Amazon Linux 2023 image   #Finding the latest Amazon Linux
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ssm_parameter.amazon_linux.value
  instance_type = "t3.small"

  # Gives the EC2 instance permission to use SSM and other allowed AWS services
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  # Attach the web Security Group to the EC2 instances
  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  # Script that automatically runs when a new EC2 instance starts
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Start it using bash

    # Update Linux packages
    dnf update -y

    # Install Docker
    dnf install -y docker

    # Start Docker automatically after reboot
    systemctl enable docker

    # Start Docker now
    systemctl start docker

    # Create the directory containing the website
    mkdir -p /opt/innovatech

    # Create the basic Innovatech HTML page
    echo "<h1>Innovatech</h1><p>Server: $(hostname)</p>" > /opt/innovatech/index.html

    # Start the Nginx web-server container
    docker run -d \
      --name nginx \
      --restart always \
      -p 80:80 \
      -v /opt/innovatech:/usr/share/nginx/html:ro \
      nginx:latest

    # Start Node Exporter for server monitoring
    # Node exporter
    docker run -d \
      --name node-exporter \
      --restart always \
      # Uses direct EC2 network
      --network host \
      # Uses host PID namespace
      --pid host \
      -v "/:/host:ro,rslave" \
      prom/node-exporter:latest \
      --path.rootfs=/host
  EOF
  )
}