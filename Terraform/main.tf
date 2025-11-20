provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# ------------------------- KEY PAIR -------------------------
resource "aws_key_pair" "key_pair" {
  key_name   = "MyKey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC2dlxKnmfweH+cDrw9qCr/YFR+I/RS/Vkain0vLlm4OAyeZpmZS0xKkmTvDSHQXKqakY5USTP2EfT0rBjWkFJj4YjlxGhp3mpoDk9kq84Vt1M74CgECDJl2qfXqK7pJ5iPuaq0wA/nAHv79HwJrdmMBxIq7W/Fq7CJLbXAVJT6lTOGlutS71Ruko50qnGVQMhSvhLGFlQATi8mSWetIEjRELrj46HoNfCs+ubo5yD/ICsXMN1eaxtLKkK9wRGBgz1OM2KyLLwLEw7fd4L+D1OutA2/4+6ak9VJqOGc5rCn1wr8QlosIWIGoEifSlsvUHPmi9WjpUMdks0gmHzumicLFtV7y/dmV1IhJeyRC02jtypZUk6sbdXY2tvSfFehykCgrBu5ByR0s85AMJH5Gr8xczrfH6nU0xYDiUAXER8enb4XPOk5ea4kZcaFdykf/sPgfB8FT+aCE59Y6H0gWmG8ehw98Cj2RLvl2xG+SDcGbF0JrMF8f8JJ5zBVq8wN6ZE= Dell@MADHU-KIRAN"
}

# ------------------------- VPC -------------------------
resource "aws_vpc" "prod" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "prod" }
}

# ------------------------- SUBNET -------------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "172.20.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet" }
}

# ------------------------- INTERNET GATEWAY -------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod.id

  tags = { Name = "prod-igw" }
}

# ------------------------- ROUTE TABLE -------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-route-table" }
}

# ------------------------- ROUTE TABLE ASSOCIATION -------------------------
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------- SECURITY GROUP - JENKINS -------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  vpc_id      = aws_vpc.prod.id
  description = "SG for Jenkins Server"

  ingress {
    description = "Jenkins HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-sg" }
}

# ------------------------- SECURITY GROUP - MyApp -------------------------
resource "aws_security_group" "myapp_sg" {
  name        = "myapp-sg"
  vpc_id      = aws_vpc.prod.id
  description = "MyApp SG"

  ingress {
    description = "MyApp Port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All Inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "myapp-sg" }
}

# ------------------------- JENKINS INSTANCE -------------------------
resource "aws_instance" "jenkins" {
  ami                    = "ami-0fa3fe0fa7920f68e"
  instance_type          = "t2.large"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install wget git maven ansible docker -y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
      "sudo yum install jenkins -y",
      "sudo systemctl enable jenkins && sudo systemctl start jenkins",
      "sudo systemctl enable docker && sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",
      "sudo usermod -aG docker jenkins",
      "sudo chmod 666 /var/run/docker.sock",
      "sudo docker run -d --name sonar -p 9000:9000 sonarqube",
      "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm"
    ]
  }

  tags = { Name = "Jenkins-From-Terraform" }
}

# ------------------------- MyApp INSTANCE -------------------------
resource "aws_instance" "myapp" {
  ami                    = "ami-0fa3fe0fa7920f68e"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.myapp_sg.id]

  tags = { Name = "MyApp-From-Terraform" }
}
