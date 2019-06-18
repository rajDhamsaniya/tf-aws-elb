provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "ap-south-1"
}

variable "avail_zone" {
  default = ["ap-south-1a","ap-south-1b"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "local_file" "key" {
    filename = "/home/raj_dhamsaniya/.ssh/newpair.pem"
}

resource "aws_security_group" "tfsg" {
  name        = "tfsg"
  description = "Allow HTTP trafic"

  ingress{
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  count           = 3
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "t2.micro"
  key_name        = "newpair"
  security_groups = ["${aws_security_group.tfsg.name}"]
  availability_zone = "${element(var.avail_zone,count.index)}"
  provisioner "remote-exec"{
    
    connection{
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${data.local_file.key.content}"
    }
    
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx"
    ]
  }
}

resource "aws_elb" "load_balancer" {
  name               = "terraform-elb"
  availability_zones = ["${aws_instance.example.*.availability_zone}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = ["${aws_instance.example.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "terraform-elb"
  }
}


output "public_ip_instances" {
  value = ["${aws_instance.example.*.public_dns}"]
}
output "public_dns" {
  value = "${aws_elb.load_balancer.dns_name}"
}

/*
REFERENCE: 

terraform documentation, https://www.terraform.io/docs
learn Hashicorp, https://learn.hashicorp.com/terraform
aws documentation, https://docs.aws.amazon.com/
terraform issue github, https://github.com/hashicorp/terraform/issues
Andrea Grandi, "getting latest ubuntu ami with terraform", https://www.andreagrandi.it/2017/08/25/getting-latest-ubuntu-ami-with-terraform/

*/
