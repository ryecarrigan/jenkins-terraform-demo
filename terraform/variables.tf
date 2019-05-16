variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "desired_count" {
  default = 1
}

variable "domain_name" {}

variable "image_name" {
  default = "jenkins/jenkins:latest"
}

variable "instance_profile" {
  default = "ecsInstanceRole"
}

variable "service_port" {
  default = 8080
}

variable "ssh_cidr" {}
variable "stack_name" {
  default = "jenkins"
}

variable "volume_name" {
  default = "jenkins_home"
}
