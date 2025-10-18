terraform {
  backend "s3" {
    bucket = "my-springsboot-state-bucket"
    key    = "secure-devops-pipeline-minimal/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}
