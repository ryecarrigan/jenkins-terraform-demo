resource "aws_ecs_cluster" "cluster" {
  name = "${var.stack_name}"
}

resource "aws_ecs_service" "service" {
  cluster         = "${aws_ecs_cluster.cluster.name}"
  desired_count   = "${var.desired_count}"
  name            = "${var.stack_name}"
  task_definition = "${aws_ecs_task_definition.task_def.arn}"
}

resource "aws_efs_file_system" "efs" {}
resource "aws_efs_mount_target" "efs" {
  count = "${length(local.availability_zones)}"

  file_system_id  = "${aws_efs_file_system.efs.id}"
  security_groups = ["${aws_security_group.efs.id}"]
  subnet_id       = "${element(aws_subnet.private.*.id, count.index)}"
}

locals {
  efs_driver_options = "nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,addr=${aws_efs_file_system.efs.dns_name}"
}

resource "aws_ecs_task_definition" "task_def" {
  container_definitions = "${local.container_definitions}"
  family                = "${var.stack_name}"

  volume {
    name = "jenkins_home"
    docker_volume_configuration {
      driver = "local"
      scope  = "task"
      driver_opts {
        device = ":/"
        o      = "${local.efs_driver_options}"
        type   = "nfs"
      }
    }
  }
}

resource "aws_lb" "load_balancer" {
  name            = "${var.stack_name}-lb"
  internal        = false
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.load_balancer.name}"]
}

resource "aws_lb_target_group" "target_group" {
  name     = "${var.stack_name}"
  port     = "${var.service_port}"
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
}
