resource "aws_instance" "database" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = "t3.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm.name

  subnet_id = aws_subnet.db_a.id

  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  associate_public_ip_address = false

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash

    # Install PostgreSQL
    dnf install -y postgresql15-server postgresql15

    # Initialize PostgreSQL database
    postgresql-setup --initdb --unit postgresql

    # Allow PostgreSQL to listen for network connections
    echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf

    # Allow web-server subnets to connect to PostgreSQL
    echo "host all all 10.0.10.0/24 scram-sha-256" >> /var/lib/pgsql/data/pg_hba.conf
    echo "host all all 10.0.11.0/24 scram-sha-256" >> /var/lib/pgsql/data/pg_hba.conf

    # Start PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql

    # Create Innovatech database
    sudo -u postgres psql -c "CREATE DATABASE innovatech;"

    # Install Docker and OpenSSL for PostgreSQL Exporter
    dnf install -y docker openssl

    systemctl enable docker
    systemctl start docker

    # Generate a random password for the monitoring database user
    EXPORTER_PASSWORD=$(openssl rand -hex 16)

    # Create PostgreSQL monitoring user
    sudo -u postgres psql -c "CREATE USER postgres_exporter WITH PASSWORD '$EXPORTER_PASSWORD';"

    # Give monitoring user permission to read PostgreSQL statistics
    sudo -u postgres psql -c "GRANT pg_monitor TO postgres_exporter;"

    # Allow monitoring user to connect to Innovatech database
    sudo -u postgres psql -c "GRANT CONNECT ON DATABASE innovatech TO postgres_exporter;"

    # Allow PostgreSQL Exporter to authenticate locally
    sed -i "1ihost innovatech postgres_exporter 127.0.0.1/32 scram-sha-256" /var/lib/pgsql/data/pg_hba.conf

    # Reload PostgreSQL configuration
    systemctl reload postgresql

    # Start PostgreSQL Exporter
    docker run -d \
      --name postgres-exporter \
      --restart always \
      --network host \
      -e DATA_SOURCE_NAME="postgresql://postgres_exporter:$EXPORTER_PASSWORD@127.0.0.1:5432/innovatech?sslmode=disable" \
      prometheuscommunity/postgres-exporter:latest
  EOF

  tags = {
    Name = "${var.project_name}-database"
  }
}