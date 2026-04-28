# ─── ALB Security Group ─────────────────────────────────────────────────────────
# ALB nhận HTTP từ Internet, forward ra EC2 port 30080
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Allow HTTP inbound from Internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (to reach EC2)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-alb-sg" }
}

# ─── EC2 Security Group ──────────────────────────────────────────────────────────
# EC2 nhận NodePort traffic từ ALB SG, và SSH từ mọi nơi (để debug)
resource "aws_security_group" "ec2" {
  name        = "${var.app_name}-ec2-sg"
  description = "Allow NodePort from ALB and SSH for debugging"
  vpc_id      = aws_vpc.main.id

  # ALB → EC2 NodePort (minikube service)
  ingress {
    description     = "NodePort from ALB"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH (optional, dùng để debug user_data nếu cần)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (EC2 pull packages, clone git, pull minikube images)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-ec2-sg" }
}
