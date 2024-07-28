provider "aws" {
  region = "us-east-1"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_account_id" {
  default = "309676119673"
}

resource "aws_ecr_repository" "webapp" {
  name = "webapp"
}

resource "aws_ecr_repository" "mysql" {
  name = "mysql"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.31.16.0/20"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "my_security_group" {
  name        = "my_security_group"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_instance" {
  count                  = 1
  ami                    = "ami-0d191299f2822b1fa" # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  key_name               = "assignment2" # Update with your key pair name
  subnet_id              = "subnet-0350371e16326ddef"  # Replace with your subnet ID
  vpc_security_group_ids = ["sg-0d4939c8c5320231f"]
  associate_public_ip_address = true
  
  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl start docker
    sudo usermod -a -G docker ec2-user
    curl -sLo kind https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64
    sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
    rm -f ./kind
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f ./kubectl​
  EOF

  
  tags = {
    Name = "my-instance"
  }
}
