# ═══════════════════════════════════════════════════════════════════════════════
# PROVIDER WIRING: tls → aws
#
# tls_private_key sinh RSA key pair hoàn toàn trong Terraform state.
# public_key_openssh được wire vào aws_key_pair.public_key.
# EC2 instance dùng key pair này để cho phép SSH.
# Không cần tạo key tay hay import — đây là cross-provider dependency.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── TLS Provider: sinh SSH key pair ──────────────────────────────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ─── AWS Provider: đăng ký public key vào EC2 ────────────────────────────────
# tls_private_key.ssh.public_key_openssh → aws_key_pair.public_key
# Đây là điểm wire giữa TLS provider và AWS provider
resource "aws_key_pair" "main" {
  key_name   = "${var.app_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh   # <── cross-provider wire

  tags = { Name = "${var.app_name}-key" }
}

# ─── AMI: Amazon Linux 2023 (tự động lookup theo region) ─────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ─── EC2 User Data Script ──────────────────────────────────────────────────────
# Chạy tự động khi EC2 boot lần đầu.
# Toàn bộ quá trình: cài Docker → cài minikube → tạo cluster → build image → deploy K8s
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

    # Cloud-init không set HOME → kubectl/minikube không tìm được config.
    export HOME=/root
    export KUBECONFIG=/root/.kube/config

    echo "========================================"
    echo " Minesweeper K8s Setup — $(date)"
    echo "========================================"

    # ── [1/7] Update & install deps ──────────────────────────────────────────
    echo "[1/7] Installing system packages..."
    dnf update -y
    dnf install -y docker git conntrack-tools --allowerasing

    # ── [2/7] Start Docker ───────────────────────────────────────────────────
    echo "[2/7] Starting Docker..."
    systemctl enable --now docker

    # ── [3/7] Install kubectl ────────────────────────────────────────────────
    echo "[3/7] Installing kubectl..."
    KVER=$(curl -sL https://dl.k8s.io/release/stable.txt)
    curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
    kubectl version --client --short 2>/dev/null || kubectl version --client

    # ── [4/7] Install minikube ───────────────────────────────────────────────
    echo "[4/7] Installing minikube..."
    curl -Lo /usr/local/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    chmod +x /usr/local/bin/minikube
    minikube version

    # ── [5/7] Start minikube cluster with NodePort mapping ───────────────────
    echo "[5/7] Starting minikube cluster..."
    # --driver=docker : chạy K8s trong Docker container (giống kind)
    # --ports=30080:30080 : map NodePort 30080 từ minikube container ra EC2 host
    # --force : cho phép chạy dưới root (cloud-init chạy root)
    minikube start \
      --driver=docker \
      --ports=30080:30080 \
      --force \
      --wait=all

    kubectl get nodes -o wide

    # ── [6/7] Build Docker image & load into minikube ─────────────────────────
    echo "[6/7] Building app image..."
    git clone ${var.github_repo} /opt/minesweeper
    cd /opt/minesweeper
    docker build -t minesweeper-gin:local .

    echo "[6/7] Loading image into minikube cluster..."
    minikube image load minesweeper-gin:local

    # ── [7/7] Deploy to Kubernetes ────────────────────────────────────────────
    echo "[7/7] Deploying to Kubernetes..."
    kubectl apply -f /opt/minesweeper/k8s/
    kubectl rollout status deployment/minesweeper --timeout=300s
    kubectl get pods -o wide
    kubectl get svc

    echo "========================================"
    echo " Setup complete! App is live on :30080"
    echo " $(date)"
    echo "========================================"
  EOT
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 30    # GB — cần thêm dung lượng cho Docker images  
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "${var.app_name}-ec2" }
}

# ─── Attach EC2 to ALB Target Group ──────────────────────────────────────────
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 30080
}
