data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "admin_server" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.admin_server.id]
  iam_instance_profile   = aws_iam_instance_profile.admin_server.name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = var.instance_name
    Owner       = var.owner_name
    OwnerEmail  = var.owner_email
    Environment = "development"
    ManagedBy   = "terraform"
    Purpose     = "admin-server"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
