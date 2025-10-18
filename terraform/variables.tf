variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name (must exist in AWS)"
}

variable "db_name" {
  type    = string
  default = "bankappdb"
}

variable "db_user" {
  type    = string
  default = "root"
}

variable "db_password" {
  type      = string
  description = "RDS master password (sensitive)"
}
