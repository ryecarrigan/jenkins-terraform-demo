locals {
  container_definitions = <<EOF
[
  {
    "name": "jenkins",
    "image": "${var.image_name}",
    "cpu": 2048,
    "memory": 1536,
    "essential": true,
    "mountPoints": [
      {
        "containerPath":  "/var/jenkins_home",
        "sourceVolume": "${var.volume_name}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.stack_name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "${var.stack_name}"
      }
    },
    "portMappings": [
      {
        "containerPort": ${local.service_port}
      }
    ],
    "user": "jenkins"
  }
]

EOF

  efs_driver_options = "nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,addr=${aws_efs_file_system.efs.dns_name}"
  service_port = 8080
}

data "aws_region" "current" {}
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-*-ecs-optimized"]
  }
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "${var.stack_name}"
}

resource "aws_launch_configuration" "instances" {
  name_prefix                 = "${var.stack_name} "
  associate_public_ip_address = false
  image_id                    = "${data.aws_ami.ecs.id}"
  instance_type               = "t3.small"
  iam_instance_profile        = "${var.instance_profile}"
  security_groups             = ["${aws_security_group.ecs.id}"]
  user_data                   = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
while [[ -z $(docker ps -q --filter name=ecs-agent) ]]
do
  service docker restart
  start ecs
  sleep 5
done
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "${var.stack_name}"
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.instances.id}"
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier  = ["${aws_subnet.private.*.id}"]
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.stack_name}"
}

resource "aws_ecs_service" "service" {
  cluster         = "${aws_ecs_cluster.cluster.name}"
  depends_on      = ["aws_instance.bastion", "aws_lb_listener.listener", "aws_efs_mount_target.efs"]
  desired_count   = "${var.desired_count}"
  name            = "${var.stack_name}"
  task_definition = "${aws_ecs_task_definition.task_def.arn}"

  load_balancer {
    container_name   = "jenkins"
    container_port   = "${local.service_port}"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }

  network_configuration {
    security_groups = ["${aws_security_group.ecs.id}"]
    subnets         = ["${aws_subnet.private.*.id}"]
  }
}

resource "aws_efs_file_system" "efs" {}
resource "aws_efs_mount_target" "efs" {
  count = "${length(local.availability_zones)}"

  file_system_id  = "${aws_efs_file_system.efs.id}"
  security_groups = ["${aws_security_group.efs.id}"]
  subnet_id       = "${element(aws_subnet.private.*.id, count.index)}"
}

resource "aws_ecs_task_definition" "task_def" {
  container_definitions    = "${local.container_definitions}"
  network_mode             = "awsvpc"
  family                   = "${var.stack_name}"
  requires_compatibilities = ["EC2"]

  volume {
    name = "${var.volume_name}"
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
  security_groups = ["${aws_security_group.load_balancer.id}"]
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.stack_name}"
  port        = "${var.service_port}"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_vpc.vpc.id}"

  health_check {
    matcher = "200"
    path    = "/robots.txt"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = 80

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  certificate_arn   = "${aws_acm_certificate.cert.arn}"
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

data "aws_route53_zone" "domain" {
  name = "${var.domain_name}"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.domain.id}"
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.*.fqdn}"]
}

resource "aws_route53_record" "jenkins" {
  name    = "${var.stack_name}.${data.aws_route53_zone.domain.name}"
  records = ["${aws_lb.load_balancer.dns_name}"]
  type    = "CNAME"
  ttl     = "300"
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.stack_name}.${data.aws_route53_zone.domain.name}"
  validation_method = "DNS"
}
