locals {
  availability_zones = "${data.aws_availability_zones.current.names}"
}

data "aws_availability_zones" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.cidr_block}"
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  count = "${length(local.availability_zones)}"

  availability_zone       = "${element(local.availability_zones, count.index)}"
  cidr_block              = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 100 + count.index)}"
  map_public_ip_on_launch = true
  vpc_id                  = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "private" {
  count = "${length(local.availability_zones)}"

  availability_zone       = "${element(local.availability_zones, count.index)}"
  cidr_block              = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 200 + count.index)}"
  map_public_ip_on_launch = true
  vpc_id                  = "${aws_vpc.vpc.id}"
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
}

resource "aws_route_table_association" "public" {
  count = "${length(local.availability_zones)}"

  route_table_id = "${aws_route_table.public.id}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
}

resource "aws_eip" "ip" {
  vpc = true
}

resource "aws_nat_gateway" "gateway" {
  allocation_id = "${aws_eip.ip.id}"
  depends_on    = ["aws_internet_gateway.gateway"]
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gateway.id}"
  }
}

resource "aws_route_table_association" "private" {
  count = "${length(local.availability_zones)}"

  route_table_id = "${aws_route_table.private.id}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
}
