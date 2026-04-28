# Minesweeper Gin — K8s on AWS (Terraform 1-Click)

> Deploy game Minesweeper lên Kubernetes chạy trong kind trên EC2, expose qua AWS ALB — **1 lệnh duy nhất**.

---

## Kiến trúc

```
                         ┌─────────────────────────────────────────┐
Internet ──── :80 ──────▶│   AWS Application Load Balancer (ALB)  │
                         │   (internet-facing, 2 AZs)             │
                         └──────────────┬──────────────────────────┘
                                        │ HTTP :30080 (Target Group)
                                        ▼
                         ┌─────────────────────────────────────────┐
                         │  EC2  t3.medium  (Amazon Linux 2023)    │
                         │  ┌───────────────────────────────────┐  │
                         │  │  kind cluster (1-node)            │  │
                         │  │  ┌─────────────────────────────┐  │  │
                         │  │  │  Pod: minesweeper-gin       │  │  │
                         │  │  │  image: minesweeper-gin:local│  │  │
                         │  │  │  port: 8080                 │  │  │
                         │  │  └─────────────────────────────┘  │  │
                         │  │  Service: NodePort 30080          │  │
                         │  └───────────────────────────────────┘  │
                         │  Security Group: :22, :30080(from ALB)  │
                         └─────────────────────────────────────────┘
```

### Luồng request

```
User browser
  → ALB :80
  → Target Group → EC2 :30080 (NodePort trên host)
  → kind extraPortMappings → container :30080
  → K8s Service ClusterIP :8080
  → Pod minesweeper-gin :8080
```

---

## Providers Terraform (≥2 — bắt buộc)

| Provider | Version | Mục đích |
|---|---|---|
| `hashicorp/aws` | ~> 5.0 | EC2, VPC, SG, ALB, Target Group, Key Pair |
| `hashicorp/tls` | ~> 4.0 | Tự động sinh RSA SSH key pair |

### Cách wire provider

```
tls_private_key.ssh          (TLS provider)
       │
       │ .public_key_openssh
       ▼
aws_key_pair.main.public_key  (AWS provider)
       │
       │ .key_name
       ▼
aws_instance.app.key_name     (AWS provider)
```

**Tại sao dùng TLS provider?** Thay vì tạo SSH key tay và import vào AWS, `tls_private_key` sinh key RSA-4096 ngay trong Terraform state. `public_key_openssh` (output của TLS provider) được wire trực tiếp vào `aws_key_pair.public_key` (input của AWS provider). Đây là cross-provider dependency điển hình trong Terraform.

---

## Cấu trúc thư mục

```
minesweeper-gin/
├── Dockerfile              # Multi-stage: golang builder → alpine runtime
├── k8s/
│   ├── deployment.yaml     # K8s Deployment (imagePullPolicy: Never)
│   └── service.yaml        # K8s NodePort Service (:30080)
├── terraform/
│   ├── main.tf             # Provider config (aws + tls)
│   ├── variables.tf        # Biến cấu hình
│   ├── vpc.tf              # VPC, 2 public subnet, IGW, route table
│   ├── security_group.tf   # SG cho ALB và EC2
│   ├── ec2.tf              # tls key → aws key pair → EC2 + user_data
│   ├── alb.tf              # ALB, Target Group, Listener
│   └── outputs.tf          # ALB URL, EC2 IP, SSH key
└── README.md
```

---

## Prerequisites

```bash
# Cần cài sẵn trên máy local:
terraform --version   # >= 1.6
aws configure         # AWS credentials (Access Key + Secret)
```

---

## 🚀 Deploy (1-click)

```bash
cd terraform

# Bước 1: Khởi tạo providers
terraform init

# Bước 2: Xem kế hoạch (optional)
terraform plan

# Bước 3: Deploy toàn bộ hạ tầng (1 lệnh)
terraform apply -auto-approve
```

**Output sau khi apply xong:**

```
alb_url           = "http://minesweeper-alb-xxxx.ap-southeast-1.elb.amazonaws.com"
ec2_public_ip     = "x.x.x.x"
ssh_command       = "ssh -i .ssh/id_rsa_minesweeper ec2-user@x.x.x.x"
ssh_private_key   = <sensitive>
```

> ⏳ **Lưu ý**: ALB URL sẽ mất ~5-8 phút để app sẵn sàng (EC2 cần boot, cài Docker, build image, deploy K8s). ALB health check sẽ tự chuyển sang `healthy` khi app lên.

---

## Debug (xem log setup)

```bash
# Lấy SSH key
terraform output -raw ssh_private_key > ../.ssh/id_rsa_minesweeper
chmod 600 ../.ssh/id_rsa_minesweeper

# SSH vào EC2
ssh -i ../.ssh/id_rsa_minesweeper ec2-user@$(terraform output -raw ec2_public_ip)

# Xem log user_data
sudo tail -f /var/log/user-data.log

# Kiểm tra K8s trực tiếp trên EC2
sudo kubectl get pods
sudo kubectl get svc
sudo kubectl logs deployment/minesweeper
```

---

## 🗑️ Destroy (dọn sạch)

```bash
cd terraform
terraform destroy -auto-approve
```

---

## Giải thích thiết kế

### Tại sao kind thay vì minikube?

kind (Kubernetes IN Docker) phù hợp hơn cho EC2 vì:
- Không cần driver VM (không cần KVM hay VirtualBox)
- Chạy tốt trên EC2 với Docker sẵn có
- `extraPortMappings` cho phép expose NodePort ra host một cách tường minh

### Tại sao NodePort thay vì Ingress?

- Đơn giản, không cần thêm Ingress Controller (nginx/traefik)
- ALB Target Group trỏ thẳng vào `EC2:NodePort` — 1 hop duy nhất
- Phù hợp với 1-node cluster trong bài lab

### Tại sao build image trực tiếp trên EC2?

- AWS account bị lock → không push được lên ECR
- Repo public trên GitHub → EC2 clone về và `docker build`
- `kind load docker-image` nạp image vào containerd của kind cluster (không cần registry)
- `imagePullPolicy: Never` đảm bảo K8s dùng image local

### VPC với 2 public subnet

ALB yêu cầu tối thiểu 2 subnet ở 2 AZ khác nhau. EC2 chỉ cần 1 subnet nhưng cần `map_public_ip_on_launch = true` để có public IP cho ALB reach được.

---

## API

| Method | Path | Mô tả |
|---|---|---|
| GET | `/` | Trang game chính |
| POST | `/api/games` | Tạo ván mới (9×9, 10 mìn) |
| POST | `/api/games/:id/reveal` | Mở ô `{ "row": 0, "col": 0 }` |
| POST | `/api/games/:id/flag` | Cắm/gỡ cờ `{ "row": 0, "col": 0 }` |
