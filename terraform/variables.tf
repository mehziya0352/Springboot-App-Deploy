variable "region" { default = "us-east-1" }
variable "instance_type" { default = "t2.micro" }
variable "key_name" { type = string }
variable "db_user" { default = "admin" }
variable "db_password" { type = string }
variable "my_ip" { type = string } # your public IP /32
