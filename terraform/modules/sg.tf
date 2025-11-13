resource "aws_security_group" "admin_server" {
  name        = "${var.instance_name}-sg"
  description = "Security group for AWS admin server"

  tags = {
    Name       = "${var.instance_name}-sg"
    Owner      = var.owner_name
    OwnerEmail = var.owner_email
    ManagedBy  = "terraform"
  }
}

resource "aws_security_group_rule" "ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowlist_ip]
  security_group_id = aws_security_group.admin_server.id
  description       = "SSH access from allowlisted IP"
}

resource "aws_security_group_rule" "consul_http" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = [var.allowlist_ip]
  security_group_id = aws_security_group.admin_server.id
  description       = "Consul HTTP API"
}

resource "aws_security_group_rule" "nomad_http" {
  type              = "ingress"
  from_port         = 4646
  to_port           = 4646
  protocol          = "tcp"
  cidr_blocks       = [var.allowlist_ip]
  security_group_id = aws_security_group.admin_server.id
  description       = "Nomad HTTP API"
}

resource "aws_security_group_rule" "vault_http" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = [var.allowlist_ip]
  security_group_id = aws_security_group.admin_server.id
  description       = "Vault HTTP API"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.admin_server.id
  description       = "Allow all outbound traffic"
}
