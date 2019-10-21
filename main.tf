provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  required_version = ">= 0.12"
  backend "s3" {
    bucket = "awssa-ex1v4"
    key    = "dev/ex1v4.tfstate"
    region = "eu-west-2"
  }
}

# create a new VPC
resource "aws_vpc" "ex1v4_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "ex1v4_vpc"
    Environment = "ex1v4_dev"
  }
}

resource "aws_internet_gateway" "ex1v4_ig" {
  vpc_id = "${aws_vpc.ex1v4_vpc.id}"
  tags = {
    Name = "ex1v4_ig"
    Environment = "dev"
  }
}

resource "aws_route_table" "ex1v4_routetable" {
  vpc_id = "${aws_vpc.ex1v4_vpc.id}"
  tags = {
    Name = "ex1v4_routetable"
    Environment = "dev"
  }
}

resource "aws_route" "ex1v4_route" {
  route_table_id            = "${aws_route_table.ex1v4_routetable.id}"
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.ex1v4_ig.id}"
}


resource "aws_subnet" "ex1v4_public_subnet1" {
  vpc_id                  = "${aws_vpc.ex1v4_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "ex1v4_public_subnet1"
    Environment = "dev"
  }
}

resource "aws_subnet" "ex1v4_public_subnet2" {
  vpc_id                  = "${aws_vpc.ex1v4_vpc.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "ex1v4_public_subnet2"
    Environment = "dev"
  }
}

resource "aws_security_group" "ex1v4_sg" {
  name        = "ex1v4_sg"
  description = "ex1v4_sg"
  vpc_id      = "${aws_vpc.ex1v4_vpc.id}"

  tags = {
    Name = "ex1v4_sg"
    Environment = "dev"
  }
}

  resource "aws_security_group_rule" "ingress_80" {
    security_group_id = "${aws_security_group.ex1v4_sg.id}"
    type              = "ingress"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port = "80"
    to_port   = "80"
    protocol  = "tcp"
}
#
resource "aws_security_group_rule" "ingress_22" {
  security_group_id = "${aws_security_group.ex1v4_sg.id}"
  type              = "ingress"
  cidr_blocks      = ["2.218.90.129/32"]
  from_port = "22"
  to_port   = "22"
  protocol  = "tcp"
}
resource "aws_security_group_rule" "egress_any" {
  security_group_id = "${aws_security_group.ex1v4_sg.id}"
  type              = "egress"
  cidr_blocks      = ["0.0.0.0/0"]
  from_port = "0"
  to_port   = "0"
  protocol  = "-1"
}

resource "aws_instance" "ex1v4_linuxinstance1" {
  # Amazon Linux 2 AMI (HVM), SSD Volume Type
  ami           = "ami-048a01c78f7bae4aa"
  instance_type = "t2.micro"

  associate_public_ip_address = "true"
  subnet_id                   = "${aws_subnet.ex1v4_public_subnet1.id}"
  vpc_security_group_ids      = ["${aws_security_group.ex1v4_sg.id}"]
  key_name = "ex1v4"

  user_data = <<-EOF
      #! /bin/bash
      sudo yum update -y

      # file system creation
      sudo mkfs -t xfs /dev/xvdh
      sudo mkdir /data
      sudo mount /dev/xvdh /data
      sleep 5
      uuid=`sudo blkid | grep "xvdh" | cut -d\" -f 2`
      echo "UUID=$uuid /data xfs defaults,nofail 0 2" >> /etc/fstab
      echo "<h1>Hello AWS World – running on Linux – on port 80</h1>" | sudo tee /data/index.html

      sudo yum install -y httpd
      sudo systemctl start httpd
      sudo systemctl enable httpd
      sudo rm /var/www/html/index.html
      sudo ln -s /data/index.html /var/www/html/index.html
	  EOF

  tags = {
    Name = "ex1v4_linuxinstance1"
    Environment = "dev"
  }
}

resource "aws_ebs_volume" "ex1v4_ebslinuxvol1" {
  availability_zone = "ap-southeast-1a"
  size              = 1
  tags = {
    Name = "ex1v4_ebslinuxvol1"
    Environment = "dev"
  }
}

resource "aws_volume_attachment" "ex1v4_volattachment" {
  device_name = "/dev/sdh"
  force_detach = "true"
  volume_id   = "${aws_ebs_volume.ex1v4_ebslinuxvol1.id}"
  instance_id = "${aws_instance.ex1v4_linuxinstance1.id}"
}

resource "aws_elb" "ex1v4_elb" {
  subnets         = ["${aws_subnet.ex1v4_public_subnet1.id}", "${aws_subnet.ex1v4_public_subnet2.id}"]

  internal        = "false"
  security_groups = ["${aws_security_group.ex1v4_sg.id}"]


  cross_zone_load_balancing   = "true"
  idle_timeout                = "60"
  connection_draining         = "true"
  connection_draining_timeout = "300"

  listener {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  tags = {
    Name = "ex1v4_lb"
    Environment = "dev"
  }
}

# attach linux instance
resource "aws_elb_attachment" "ex1v4_attachment1" {
  elb      = "${aws_elb.ex1v4_elb.id}"
  instance = "${aws_instance.ex1v4_linuxinstance1.id}"
}

# Create S3 bucket in singapore region and make it publicly readable
resource "aws_s3_bucket" "ex1v4_public" {
  bucket        = "aws-sa-ex1v4-public"
  acl           = "public-read"

  tags = {
    Name = "AWS SA Ex1 Public bucket"
    Environment = "dev"
  }
}
