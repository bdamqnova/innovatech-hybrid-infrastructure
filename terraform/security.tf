

resource "aws_security_group" "alb" { #Application load balancer sg
  name        = "${var.project_name}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
} #closes the security Group Resource

resource "aws_vpc_security_group_ingress_rule" "alb_http" { #allowing internet
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0" # allowing internet from everywhere     #firewall rule for the alb
  from_port   = 80          #start
  to_port     = 80          #end
  ip_protocol = "tcp"       #allowed port
}



# WEB SERVER SECURITY GROUP


resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for the web servers" #security group for web server 
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id # applying this rule for the web servers

  referenced_security_group_id = aws_security_group.alb.id #allowing only alb traffic enter 

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id

  cidr_ipv4   = "0.0.0.0/0" #allow ipv4 from everywhere
  ip_protocol = "-1"        #all protocols
}



# DATABASE SECURITY GROUP


resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.web.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id = aws_security_group.alb.id

  referenced_security_group_id = aws_security_group.web.id #this sg will send traffic to the other written sg

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# MONITORING SECURITY GROUP

resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Security group for Prometheus and Grafana monitoring server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}

# Allow monitoring server to make outbound connections
resource "aws_vpc_security_group_egress_rule" "monitoring_outbound" {
  security_group_id = aws_security_group.monitoring.id

  cidr_ipv4   = "0.0.0.0/0" # allow outbound traffic to any IPv4 destination
  ip_protocol = "-1"
}

# Allow Prometheus to collect Node Exporter metrics from web servers
resource "aws_vpc_security_group_ingress_rule" "web_node_exporter" {
  security_group_id = aws_security_group.web.id

  referenced_security_group_id = aws_security_group.monitoring.id

  from_port   = 9100
  to_port     = 9100
  ip_protocol = "tcp"
}

# Allow Prometheus to collect PostgreSQL metrics
resource "aws_vpc_security_group_ingress_rule" "db_postgres_exporter" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.monitoring.id

  from_port   = 9187
  to_port     = 9187
  ip_protocol = "tcp"
}


