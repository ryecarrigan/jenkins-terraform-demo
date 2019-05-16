resource "aws_security_group" "bastion" {
  name_prefix = "${var.stack_name}_bastion"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    cidr_blocks = ["${var.ssh_cidr}"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
  }
}


resource "aws_security_group" "ecs" {
  name_prefix = "${var.stack_name}_ecs"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port       = 8080
    protocol        = "tcp"
    security_groups = ["${aws_security_group.load_balancer.id}"]
    to_port         = 8080
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.stack_name}_efs"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port       = 2049
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion.id}", "${aws_security_group.ecs.id}"]
    to_port         = 2049
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
  }
}

resource "aws_security_group" "load_balancer" {
  name_prefix = "${var.stack_name}_load_balancer"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
  }
}
