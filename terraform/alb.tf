# ─── Application Load Balancer ────────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false                  # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  # ALB yêu cầu tối thiểu 2 subnet ở 2 AZ khác nhau
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]

  tags = { Name = "${var.app_name}-alb" }
}

# ─── Target Group ─────────────────────────────────────────────────────────────
# Trỏ vào EC2 instance (instance type), port 30080 = minikube NodePort
resource "aws_lb_target_group" "app" {
  name     = "${var.app_name}-tg"
  port     = 30080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.app_name}-tg" }
}

# ─── Listener: HTTP :80 → forward to Target Group ────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
