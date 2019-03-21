locals {
  service_port = 8080
  container_definitions = <<EOF
[
  {
    "name": "jenkins",
    "image": "library/jenkins:latest",
    "cpu": 1024,
    "memory": 3072,
    "essential": true,
    "mountPoints": [
      {
        "containerPath":  "/var/jenkins_home",
        "sourceVolume": "jenkins_home"
      }
    ],
    "portMappings": [
      {
        "containerPort": ${local.service_port}
      }
    ],
    "user": "jenkins"
  }
]

EOF
}

variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "desired_count" {
  default = 1
}

variable "service_port" {
  default = 8080
}

variable "stack_name" {
  default = "jenkins"
}
