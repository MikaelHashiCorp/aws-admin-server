output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.admin_server.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.admin_server.instance_public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.admin_server.instance_private_ip
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = module.admin_server.ssh_key_name
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.admin_server.security_group_id
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = module.admin_server.iam_role_name
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = module.admin_server.ssh_connection_string
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ===== AWS Admin Server Deployed =====
    
    SSH Connection:
      ${module.admin_server.ssh_connection_string}
    
    Validation:
      Run: ./validate-instance.sh
    
    HashiCorp Tools Installed:
      - Consul, Nomad, Vault
      - Terraform, Packer
      - AWS CLI v2
    
    Instance Details:
      ID: ${module.admin_server.instance_id}
      Public IP: ${module.admin_server.instance_public_ip}
      Private IP: ${module.admin_server.instance_private_ip}
    
    ======================================
  EOT
}
