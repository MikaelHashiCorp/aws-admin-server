output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.admin_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.admin_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.admin_server.private_ip
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = var.key_name
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.admin_server.id
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.admin_server.name
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.admin_server.public_ip}"
}
