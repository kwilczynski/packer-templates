variable "region" {}

variable "stack_name" {
  default = "packer"
}

variable "allowed_account_ids" {
  default = []
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  default = []
}

variable "default_allowed_cidr_block" {
  default = "0.0.0.0/0"
}

variable "tags" {
  default = {}
}
