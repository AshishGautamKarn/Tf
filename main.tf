# 1. Define the required provider (AWS)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2. Configure the AWS Provider and set the region
provider "aws" {
  region = "us-east-1"
}

# 3. Define the resource to create
resource "aws_s3_bucket" "my_practice_bucket" {
  bucket = "terraform-practice-bucket-998877" # Change these numbers!
  
  tags = {
    Environment = "Learning"
  }
}

