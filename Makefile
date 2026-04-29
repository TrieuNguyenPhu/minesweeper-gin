# ==============================================================================
# Makefile for Minesweeper Gin & Terraform deployment
# ==============================================================================

.PHONY: help go-run go-build go-test tf-init tf-plan tf-apply tf-destroy tf-deploy tf-output tf-ssh

# Default target
help:
	@echo "Các lệnh có sẵn:"
	@echo "  --- GO DEVELOPMENT ---"
	@echo "  make go-run          - Chạy ứng dụng Go/Gin cục bộ"
	@echo "  make go-build        - Biên dịch ứng dụng Go"
	@echo "  make go-test         - Chạy unit tests"
	@echo ""
	@echo "  --- TERRAFORM ---"
	@echo "  make tf-init         - Khởi tạo Terraform"
	@echo "  make tf-plan         - Xem trước kế hoạch thay đổi (terraform plan)"
	@echo "  make tf-apply        - Deploy tài nguyên lên AWS (auto-approve)"
	@echo "  make tf-destroy      - Hủy toàn bộ tài nguyên trên AWS (auto-approve)"
	@echo "  make tf-deploy       - Khởi tạo VÀ deploy cùng một lúc (init + apply)"
	@echo "  make tf-output       - Hiển thị đầu ra của Terraform"
	@echo "  make tf-ssh          - Lấy SSH private key và chuẩn bị kết nối SSH"

# Go targets
go-run:
	go run main.go

go-build:
	go build -o bin/minesweeper main.go

go-test:
	go test ./... -v

# Terraform targets (Sử dụng -chdir=terraform để chạy trực tiếp từ thư mục gốc)
tf-init:
	terraform -chdir=terraform init

tf-plan:
	terraform -chdir=terraform plan

tf-apply:
	terraform -chdir=terraform apply -auto-approve

tf-destroy:
	terraform -chdir=terraform destroy -auto-approve

tf-deploy:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply -auto-approve

tf-output:
	terraform -chdir=terraform output

tf-ssh:
	@mkdir -p .ssh
	terraform -chdir=terraform output -raw ssh_private_key > .ssh/id_rsa_minesweeper
	@echo "SSH private key đã được lưu vào .ssh/id_rsa_minesweeper"
	@echo "Dùng lệnh sau để SSH vào EC2:"
	@echo "ssh -i .ssh/id_rsa_minesweeper ec2-user\$$$(shell terraform -chdir=terraform output -raw ec2_public_ip)"
