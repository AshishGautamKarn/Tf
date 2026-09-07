# 1. Dynamically find the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Create a Security Group to act as a virtual firewall
resource "aws_security_group" "web_sg" {
  name        = "free-tier-web-sg"
  description = "Allow HTTP and SSH traffic"

  # Inbound rule: Allow SSH to connect to the server
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Note: In production, restrict this to your specific IP!
  }

  # Inbound rule: Allow web traffic
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow the server to access the internet (needed for updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Create the Free-Tier EC2 Instance
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro" # Strictly free-tier eligible

  # Attach the security group we created above
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Run this bash script when the server first boots up
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "MyFreeTierServer"
  }
}

# 4. Print the public IP to the terminal after deployment
output "instance_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Copy and paste this IP into your browser"
}

