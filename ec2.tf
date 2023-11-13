provider "aws" {
  region  = "us-east-1"
  profile = "maxi8815"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_security_group" "mySG" {
  name        = "allow_http"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "myEC2Instance" {
  ami             = "ami-05c13eab67c5d8861"
  instance_type   = "t2.micro"
  key_name        = "ec2-key"
  subnet_id       = aws_subnet.my_subnet.id
  security_groups = [aws_security_group.mySG.id]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

resource "aws_route_table" "myRouteTable" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "MyRouterTable"
  }
}

resource "aws_route_table_association" "myRouterTableAssoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.myRouteTable.id
}

resource "null_resource" "name" {

  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/ec2-key.pem")
    host        = aws_instance.myEC2Instance.public_ip
  }

  # copy the install_jenkins.sh file from your computer to the ec2 instance 
  provisioner "file" {
    source      = "userdata.sh"
    destination = "/tmp/userdata.sh"
  }

  # set permissions and run the install_jenkins.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/userdata.sh",
      "sh /tmp/userdata.sh",
    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.myEC2Instance]
}


output "ec2_dns" {
    value = aws_instance.myEC2Instance.public_dns
  
}