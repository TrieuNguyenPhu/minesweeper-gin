variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type (needs ≥2 vCPU + 2 GB RAM for minikube)"
  type        = string
  default     = "t3.medium"
}

variable "app_name" {
  description = "Application name — used as a prefix for all resource names and tags"
  type        = string
  default     = "minesweeper"
}

variable "github_repo" {
  description = "Public GitHub repo URL — EC2 will clone this to build the Docker image"
  type        = string
  default     = "https://github.com/TrieuNguyenPhu/minesweeper-gin.git"
}
