resource "aws_security_group" "ecs" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_security_group" "efs" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port       = 2049
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ecs.id}"]
    to_port         = 2049
  }
}

resource "aws_security_group" "load_balancer" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 8080
    protocol  = "tcp"
    to_port   = 8080
  }
}
