terraform {
  required_version = ">= 1.6"

  required_providers {
    # Provider 1: AWS — quản lý toàn bộ hạ tầng cloud
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Provider 2: TLS — sinh SSH key pair tự động, không cần tạo tay
    # Output (public key) được wire trực tiếp vào aws_key_pair resource
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.app_name
      ManagedBy   = "Terraform"
    }
  }
}

# TLS provider không cần cấu hình — chỉ cần khai báo
provider "tls" {}
