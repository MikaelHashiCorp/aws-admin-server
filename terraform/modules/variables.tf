variable "region" {
  description = "AWS region for resources"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "owner_name" {
  description = "Name of the infrastructure owner"
  type        = string
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "server_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.medium"
}

variable "allowlist_ip" {
  description = "IP address allowed to access the instance via SSH (CIDR notation)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 24.04"
  type        = string
  default     = ""
}
