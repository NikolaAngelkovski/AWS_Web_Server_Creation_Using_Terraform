terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
}

# Step 1 - Create a vpc
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
 Name = "Main VPC"
  }
}

# Step 2 - Create an internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main_internet_gateway"
  }
}

# Step 3 - Create a custom route table
resource "aws_route_table" "test_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }
    route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
    }
  

  tags = {
    Name = "Terraform Route Table"
  }
}

# Step 4 - Create a subnet
resource "aws_subnet" "terraform_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Terraform Subnet"
  }
}

# Step 5 - Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.terraform_subnet.id
  route_table_id = aws_route_table.test_route_table.id
}

# Step 6 - Create a security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress  {
      description      = "HTTPS from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
  ingress {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  

  tags = {
    Name = "allow_web"
  }
}
# Step 7 - Create a network interface
resource "aws_network_interface" "terraform_network_interface" {
  subnet_id       = aws_subnet.terraform_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Step 8 - Assign an elastic IP address
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.terraform_network_interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# Step 9 - Create an Ubuntu server and install/enable apache2
resource "aws_instance" "terraform_web_server_instance" {
ami = "ami-09e67e426f25ce0d7"
instance_type = "t2.micro"
availability_zone = "us-east-1a"
key_name = "Terraform Test Key Pair"
network_interface {
  device_index = 0
  network_interface_id = aws_network_interface.terraform_network_interface.id
}
user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache 2
              sudo bash -c 'echo your Terraform web server > /var/www/html/index.html'
              EOF
              tags = {
                Name = "Terraform_web_server"
              }
}
