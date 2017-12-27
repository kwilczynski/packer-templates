output "account_id" {
  value = "${data.aws_caller_identity.packer.account_id}"
}

output "region" {
  value = "${data.aws_region.packer.name}"
}

output "vpc_id" {
  value = "${aws_vpc.packer.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.packer.cidr_block}"
}

output "public_subnet_id" {
  value = "${aws_subnet.packer.id}"
}

output "security_group_id" {
  value = "${aws_security_group.packer.id}"
}

output "origin" {
  value = "${coalesce(join("", data.external.packer.*.result.origin),
             var.default_allowed_cidr_block)}"
}
