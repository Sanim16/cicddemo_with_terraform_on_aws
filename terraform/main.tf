terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  ##Used to create a remote backend in s3 so that the .tfstate file can
  ##be accessed by more than one person in a team setting

  ##The backend code block doesn't accept variables
  ##A backend block cannot refer to named values (like input variables, locals, or data source attributes).
  
  backend "s3" {
    bucket = "ms-tfstate-bucket" #Bucket name in S3
    key    = "terraform/remotestate" #Key to object in S3
    region = "us-east-1"
    #shared_credentials_file = "" #use env variable from github actions for login to Aws
    #profile = "" #profile to use #use env variable from github actions for login to Aws
  }

}

provider "aws" {
  region     = var.AWS_REGION
  #shared_credentials_file = "" #use env variable from github actions for login to Aws
  #profile = "" #profile to use #use env variable from github actions for login to Aws
}

resource "aws_instance" "web_server" {
  ami = "ami-08c40ec9ead489470"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_name.key_name
  vpc_security_group_ids = [ aws_security_group.cicd-demo-sg.id ]
  #availability_zone = ""
  associate_public_ip_address = true
  subnet_id = aws_subnet.public-subnet-01.id
  iam_instance_profile = aws_iam_instance_profile.cicddemo_ecr_profile.name

  connection {
    type = "ssh"
    host = self.public_ip
    user = "ubuntu"
    private_key = var.private_key
    timeout = "4m"
  }
  tags = {
    "Name" = "Web Server"
  }
}

resource "aws_key_pair" "key_name" {
  key_name = var.key_name  ##"terraformawskey"
  public_key = var.public_key  ##file("${var.PUB_KEY}")
}

resource "aws_security_group" "cicd-demo-sg" {
  name        = "cicddemo-sg"
  description = "Allow SSH, HTTP & HTTPS inbound traffic"
  vpc_id = aws_vpc.cicddemo.id

  ingress = [ {
    cidr_blocks = [ "0.0.0.0/0" ] ##this should be your IP address for ssh
    description = "allow SSH from my IP"
    from_port = 22
    protocol = "tcp"
    self = false
    to_port = 22
  },
  {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  },
  {
    description      = "HTTPS from everywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  } ]

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cicddemo-sg"
  }
}

resource "aws_iam_instance_profile" "cicddemo_ecr_profile" {
    name = "cicddemo_ecr_profile"  
    role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "test_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr-public:GetAuthorizationToken",
                "sts:GetServiceBearerToken",
                "ecr-public:BatchCheckLayerAvailability",
                "ecr-public:GetRepositoryPolicy",
                "ecr-public:DescribeRepositories",
                "ecr-public:DescribeRegistries",
                "ecr-public:DescribeImages",
                "ecr-public:DescribeImageTags",
                "ecr-public:GetRepositoryCatalogData",
                "ecr-public:GetRegistryCatalogData",
                "ecr-public:InitiateLayerUpload",
                "ecr-public:UploadLayerPart",
                "ecr-public:CompleteLayerUpload",
                "ecr-public:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
  sensitive = true
}