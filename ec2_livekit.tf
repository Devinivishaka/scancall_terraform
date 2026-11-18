# Generate SSH Key Pair if not supplied
resource "tls_private_key" "ec2" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the generated private key locally as a .pem file
resource "local_sensitive_file" "private_key" {
  count           = var.ssh_public_key == "" ? 1 : 0
  content         = tls_private_key.ec2[0].private_key_pem
  filename        = "${path.module}/scancall-livekit-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "livekit" {
  key_name   = "${var.project_name}-livekit-key-${var.environment}"
  public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ec2[0].public_key_openssh

  tags = {
    Name = "${var.project_name}-livekit-key-${var.environment}"
  }
}

# Latest Ubuntu 22.04 LTS AMI — Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical Ltd.

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------------------------------------------------------------------
# LiveKit EC2 VM — Public Subnet AZ1
# ---------------------------------------------------------------------------
resource "aws_instance" "livekit" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.livekit_instance_type != "" ? var.livekit_instance_type : local.livekit_instance_type[var.environment]
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.livekit.id]
  key_name                    = aws_key_pair.livekit.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # Supports both IMDSv1 and IMDSv2 (matches live setup)
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-livekit-ec2-${var.environment}"
    Role = "LiveKit-Media-Server"
  }
}

# Elastic IP — fixed permanent public address for LiveKit (never changes)
resource "aws_eip" "livekit" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-livekit-eip-${var.environment}"
  }
}

# Decoupled association ensures the Elastic IP is never recreated even if the EC2 VM is replaced
resource "aws_eip_association" "livekit" {
  instance_id   = aws_instance.livekit.id
  allocation_id = aws_eip.livekit.id
}
