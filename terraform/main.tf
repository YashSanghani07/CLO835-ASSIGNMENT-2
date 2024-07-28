provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.12.0"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "k8s" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 16
  }

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
    rm -f ./kubectl
    kind create cluster --config kind.yaml
  EOF

  vpc_security_group_ids = [aws_security_group.my_sg.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    project = "A2"
  }

  key_name                = "assignment2"
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

resource "aws_key_pair" "k8s" {
  key_name   = "assignment2"
  public_key = file("${path.module}/assignment2.pub")
}

resource "aws_ecr_repository" "database" {
  name = "database"
  tags = {
    Name = "A2_database"
  }
}

resource "aws_ecr_repository" "application" {
  name = "application"
  tags = {
    Name = "A2_application"
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_ecr_repository_policy" "ecr_policy_database" {
  repository = aws_ecr_repository.database.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.lab_role.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "ecr_policy_application" {
  repository = aws_ecr_repository.application.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.lab_role.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.k8s.public_ip
}

variable "container_ports" {
  type = map(number)
  default = {
    blue = 8081
    pink = 8082
    lime = 8083
  }
}

resource "aws_security_group" "my_sg" {
  name        = "allow_ssh_a2"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  dynamic "ingress" {
    for_each = var.container_ports
    content {
      description = "to run ${ingress.key} container"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
