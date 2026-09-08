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

   # Inbound rule: Allow postgres traffic
  ingress {
    description = "Allow PG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1 
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              # 1. Log all user-data output for troubleshooting

              # 2. Install PostgreSQL 15/16 and contrib modules
              dnf update -y
              dnf install -y postgresql15-server postgresql15-contrib

              # 3. Initialize the database cluster
              PGDATA=/var/lib/pgsql/data
              postgresql-setup --initdb

              # 4. Apply Advanced PostgreSQL Configurations
              cat <<EOT >> $PGDATA/postgresql.conf
              # Connection Settings
              listen_addresses = '*'
              max_connections = 300

              # Memory & Execution Plan Tuning (Placeholders to scale based on instance size)
              shared_buffers = '256MB'             # Scale to ~25% of available RAM
              effective_cache_size = '1GB'       # Scale to ~75% of available RAM
              work_mem = '32MB'
              maintenance_work_mem = '256MB'
              random_page_cost = 1.1             # Optimized for SSDs/gp3

              # WAL and Replication
              wal_level = logical                # Prepared for logical decoding/replication
              max_wal_senders = 10
              wal_keep_size = '2GB'
              checkpoint_timeout = '15min'
              checkpoint_completion_target = 0.9

              # Query Tuning and Observability
              logging_collector = on
              log_min_duration_statement = 1000  # Log queries slower than 1s
              shared_preload_libraries = 'pg_stat_statements'

              # Autovacuum Cost Optimization (Aggressive for high TPS)
              autovacuum_max_workers = 1
              autovacuum_vacuum_scale_factor = 0.05
              autovacuum_analyze_scale_factor = 0.02
              autovacuum_vacuum_cost_delay = 2ms
              EOT

              # 5. Secure pg_hba.conf for network access
              # Enforce scram-sha-256 instead of default ident/trust
              sed -i 's/ident/scram-sha-256/g' $PGDATA/pg_hba.conf
              echo "host    all             all             10.0.0.0/16             scram-sha-256" >> $PGDATA/pg_hba.conf

              # 6. Enable and start the service
              systemctl enable postgresql
              systemctl start postgresql
              
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

