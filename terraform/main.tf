provider "aws" {
  region = "${var.region}"

  allowed_account_ids = ["${var.allowed_account_ids}"]
}

data "aws_caller_identity" "packer" {}

data "aws_region" "packer" {
  current = true
}

data "aws_availability_zones" "packer" {
  state = "available"
}

data "external" "packer" {
  count = "${length(var.allowed_cidr_blocks) != 0 ? 0 : 1}"

  program = ["bash", "${path.module}/scripts/origin.sh"]

  query = {
    add_cidr = true
  }
}

resource "random_shuffle" "packer" {
  input = [
    "${data.aws_availability_zones.packer.names}"
  ]
  result_count = 1
}

resource "aws_vpc" "packer" {
  cidr_block = "${var.vpc_cidr_block}"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = "${merge(map(
    "Name",      "${format("%s-vpc", var.stack_name)}",
    "StackName", "${var.stack_name}",
  ), var.tags)}"
}

resource "aws_internet_gateway" "packer" {
  vpc_id = "${aws_vpc.packer.id}"

  tags = "${merge(map(
    "Name",      "${format("%s-internet-gateway", var.stack_name)}",
    "StackName", "${var.stack_name}",
  ), var.tags)}"
}

resource "aws_subnet" "packer" {
  vpc_id = "${aws_vpc.packer.id}"

  cidr_block        = "${cidrsubnet(aws_vpc.packer.cidr_block, 8, 1)}"
  availability_zone = "${element(random_shuffle.packer.result, 0)}"

  map_public_ip_on_launch = true

  tags = "${merge(map(
    "Name",      "${format("%s-%s-public-%s-subnet", var.stack_name,
                    data.aws_region.packer.name, substr(element(
                    random_shuffle.packer.result, 0), -1, 1))}",
    "StackName", "${var.stack_name}",
  ), var.tags)}"
}

resource "aws_route_table" "packer" {
  vpc_id = "${aws_vpc.packer.id}"

  tags = "${merge(map(
    "Name",      "${format("%s-public-route-table", var.stack_name)}",
    "StackName", "${var.stack_name}",
  ), var.tags)}"
}

resource "aws_route" "packer" {
  route_table_id = "${aws_route_table.packer.id}"

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.packer.id}"
}

resource "aws_route_table_association" "packer" {
  route_table_id = "${aws_route_table.packer.id}"
  subnet_id      = "${aws_subnet.packer.id}"
}

resource "aws_security_group" "packer" {
  name        = "${format("%s-packer-security-group", var.stack_name)}"
  description = "Security Group for Packer"

  vpc_id = "${aws_vpc.packer.id}"

  tags = "${merge(map(
    "Name",      "${format("%s-packer-security-group", var.stack_name)}",
    "StackName", "${var.stack_name}",
  ), var.tags)}"
}

resource "aws_security_group_rule" "packer_ingress_allow_icmp" {
  type = "ingress"

  protocol  = "icmp"
  from_port = -1
  to_port   = -1

  cidr_blocks = ["${coalescelist(var.allowed_cidr_blocks, formatlist("%s",
                    list(coalesce(join("", data.external.packer.*.result.origin),
                    var.default_allowed_cidr_block))))}"]

  security_group_id = "${aws_security_group.packer.id}"
}

resource "aws_security_group_rule" "packer_ingress_allow_tcp_22" {
  type = "ingress"

  protocol  = "tcp"
  from_port = 22
  to_port   = 22

  cidr_blocks = ["${coalescelist(var.allowed_cidr_blocks, formatlist("%s",
                    list(coalesce(join("", data.external.packer.*.result.origin),
                    var.default_allowed_cidr_block))))}"]

  security_group_id = "${aws_security_group.packer.id}"
}

resource "aws_security_group_rule" "packer_egress_allow_all" {
  type = "egress"

  protocol  = -1
  from_port = 0
  to_port   = 0

  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.packer.id}"
}
