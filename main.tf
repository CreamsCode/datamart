provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "datamart_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "DatamartVPC"
  }
}

# Subnet Pública
resource "aws_subnet" "datamart_subnet" {
  vpc_id                  = aws_vpc.datamart_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "DatamartSubnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "datamart_igw" {
  vpc_id = aws_vpc.datamart_vpc.id
  tags = {
    Name = "DatamartInternetGateway"
  }
}

# Route Table para la Subnet Pública
resource "aws_route_table" "datamart_route_table" {
  vpc_id = aws_vpc.datamart_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.datamart_igw.id
  }
  tags = {
    Name = "DatamartRouteTable"
  }
}

# Asociar la Route Table a la Subnet Pública
resource "aws_route_table_association" "datamart_subnet_association" {
  subnet_id      = aws_subnet.datamart_subnet.id
  route_table_id = aws_route_table.datamart_route_table.id
}

# Grupo de Seguridad para Hazelcast
resource "aws_security_group" "hazelcast_sg" {
  vpc_id = aws_vpc.datamart_vpc.id
  tags = {
    Name = "HazelcastSecurityGroup"
  }

  ingress {
    description = "Hazelcast Port"
    from_port   = 5701
    to_port     = 5701
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Grupo de Seguridad para el Datamart
resource "aws_security_group" "datamart_sg" {
  vpc_id = aws_vpc.datamart_vpc.id
  tags = {
    Name = "DatamartSecurityGroup"
  }

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application Port Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instancia EC2 para Hazelcast
resource "aws_instance" "hazelcast_instance" {
  ami           = "ami-05576a079321f21f8" # Cambia esto si es necesario
  instance_type = "t2.micro"
  key_name      = "vockey" # Cambia esto por el nombre correcto de tu par de claves
  subnet_id     = aws_subnet.datamart_subnet.id
  vpc_security_group_ids = [aws_security_group.hazelcast_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y java-17-amazon-corretto wget

    # Descargar y configurar Hazelcast
    wget https://repository.hazelcast.com/rpm/stable/hazelcast-rpm-stable.repo -O hazelcast-rpm-stable.repo
    sudo mv hazelcast-rpm-stable.repo /etc/yum.repos.d/
    sudo yum install hazelcast-5.5.0 -y

    sudo systemctl start hazelcast

    hz start

    echo "Hazelcast server ready."
  EOF

  tags = {
    Name = "HazelcastInstance"
  }
}

# Instancia EC2 para el Datamart
resource "aws_instance" "datamart_instance" {
  ami           = "ami-05576a079321f21f8" # Cambia esto si es necesario
  instance_type = "t2.micro"
  key_name      = "vockey" # Cambia esto por el nombre correcto de tu par de claves
  subnet_id     = aws_subnet.datamart_subnet.id
  vpc_security_group_ids = [aws_security_group.datamart_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y java-17-amazon-corretto git wget

    # Descargar y extraer Maven
    wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
    sudo tar -xvzf apache-maven-3.9.9-bin.tar.gz -C /opt
    sudo mv /opt/apache-maven-3.9.9 /opt/maven

    # Configurar variables de entorno para Maven
    echo "export M2_HOME=/opt/maven" | sudo tee /etc/profile.d/maven.sh
    echo "export PATH=\$M2_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/maven.sh
    source /etc/profile.d/maven.sh

    # Clonar el repositorio del Datamart
    git clone https://github.com/CreamsCode/datamart /home/ec2-user/datamart
    cd /home/ec2-user/datamart

    # Compilar y ejecutar el Datamart
    /opt/maven/bin/mvn clean package
    java -jar target/datamart-1.0-SNAPSHOT.jar

    echo "Datamart instance ready."
  EOF

  tags = {
    Name = "DatamartInstance"
  }
}

resource "aws_ssm_parameter" "datamart_ip" {
  name  = "datamart_ip"
  type  = "String"
  overwrite = true
  value = aws_instance.datamart_instance.public_ip
}

resource "aws_ssm_parameter" "hazelcast_ip" {
  name  = "hazelcast_ip"
  type  = "String"
  overwrite = true
  value = aws_instance.hazelcast_instance.public_ip
}
