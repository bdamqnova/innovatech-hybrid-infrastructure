data "aws_availability_zones" "available" { #search for available zones 
  state = "available"
}

#PUBLIC SUBNETS

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-public-b"
  }
}

#PRIVATE WEB SUBNETS

resource "aws_subnet" "web_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-web-a"
  }
}

resource "aws_subnet" "web_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-web-b"
  }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-db-a"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-db-b"
  }
}

#INTERNET GATEWAY

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#Public route table 

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" { #creating elastic ip for the NAT gateway
  domain = "vpc"           #it is for use inside the VPC

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {      #creating a NAT gateway
  allocation_id = aws_eip.nat.id         #giving the elastic ip to NAT gateway 
  subnet_id     = aws_subnet.public_a.id #placing the nat gateway inside one of the public subnets

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.main] # do not create Nat gateway until Internet Gateway exists
}

resource "aws_route_table" "web_private" {
  vpc_id = aws_vpc.main.id #creates a table for the routes 

  tags = {
    Name = "${var.project_name}-web-private-rt"
  }
}

resource "aws_route" "web_internet" {
  route_table_id         = aws_route_table.web_private.id #adds a default route to the web route table through Nat gateway
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "web_a" { #creates a route to routing table  for web_a 
  subnet_id      = aws_subnet.web_a.id
  route_table_id = aws_route_table.web_private.id
}

resource "aws_route_table_association" "web_b" {
  subnet_id      = aws_subnet.web_b.id #creates a route for the routing table for web_b
  route_table_id = aws_route_table.web_private.id
}

resource "aws_route_table" "db_private" { #Creates a routing table for database subnets
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-private-rt"
  }
}

resource "aws_route" "db_internet" {
  route_table_id         = aws_route_table.db_private.id #defaoult route for the db routing table through the Nat Gateway
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "db_a" { #creates a route for the routing table db_a 
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db_private.id
}

resource "aws_route_table_association" "db_b" { #creates a route for routing table db_b
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.db_private.id
}
resource "aws_vpc_security_group_egress_rule" "db_outbound" { # creating a resource for the outbound traffic 
  security_group_id = aws_security_group.db.id                #This rule is applied for aws_security-GROUP.DB
  cidr_ipv4         = "0.0.0.0/0"                             #The destination can be any IPv4
  ip_protocol       = "-1"                                    #all protocols allowed 
}

# MONITORING PRIVATE SUBNET/ I need to learn this

resource "aws_subnet" "monitoring_a" {                               #creates monitoring subnet
  vpc_id            = aws_vpc.main.id                                #inserts the subnet inside the vpc
  cidr_block        = "10.0.30.0/24"                                 #sets the ip range
  availability_zone = data.aws_availability_zones.available.names[0] #places inside the first AZ

  tags = {
    Name = "${var.project_name}-monitoring-a" #Innovatech-monitoring-a
  }
}

# Route table for the monitoring subnet

resource "aws_route_table" "monitoring_private" { #creates the monitoring routing table 
  vpc_id = aws_vpc.main.id                        #lets it inside the main VPC

  tags = {
    Name = "${var.project_name}-monitoring-private-rt" #creates a name Innovatech-monitoring-pr-rt
  }
}

# Allow monitoring EC2 to access the internet through NAT

resource "aws_route" "monitoring_internet" {                     #creates a default route for the Nat Gateway		
  route_table_id         = aws_route_table.monitoring_private.id #connects to the monitoring routing table 
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Connect monitoring subnet to its route table

resource "aws_route_table_association" "monitoring_a" {
  subnet_id      = aws_subnet.monitoring_a.id
  route_table_id = aws_route_table.monitoring_private.id
}