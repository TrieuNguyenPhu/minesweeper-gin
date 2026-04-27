output "alb_url" {
  description = "URL của Application Load Balancer — mở link này trên browser sau khi deploy xong (~8 phút)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP của EC2 — dùng để SSH debug hoặc xem log user_data"
  value       = aws_instance.app.public_ip
}

output "ssh_command" {
  description = "Lệnh SSH vào EC2 để xem log user_data (xem tiến trình setup)"
  value       = "ssh -i .ssh/id_rsa_minesweeper ec2-user@${aws_instance.app.public_ip}"
}

output "ssh_private_key" {
  description = "SSH private key — lưu vào file để SSH vào EC2: terraform output -raw ssh_private_key > .ssh/id_rsa_minesweeper && chmod 600 .ssh/id_rsa_minesweeper"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "userdata_log_command" {
  description = "Lệnh xem log user_data trên EC2 (sau khi SSH vào)"
  value       = "sudo tail -f /var/log/user-data.log"
}
