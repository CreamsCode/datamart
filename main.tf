provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "datamart_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subred
resource "aws_subnet" "datamart_subnet" {
  vpc_id            = aws_vpc.datamart_vpc.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Grupo de seguridad para Hazelcast
resource "aws_security_group" "hazelcast_sg" {
  vpc_id      = aws_vpc.datamart_vpc.id
  description = "Allow Hazelcast traffic"

  ingress {
    from_port   = 5701
    to_port     = 5701
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
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.datamart_key.key_name
  subnet_id     = aws_subnet.datamart_subnet.id
  security_groups = [aws_security_group.hazelcast_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    # Actualizar el sistema
    sudo yum update -y

    # Instalar Java
    sudo yum install -y java-17-amazon-corretto

    # Descargar Hazelcast
    wget https://repo1.maven.org/maven2/com/hazelcast/hazelcast-distribution/5.3.8/hazelcast-distribution-5.3.8.tar.gz
    tar -xvzf hazelcast-distribution-5.3.8.tar.gz

    # Mover Hazelcast a un directorio conocido
    sudo mv hazelcast-5.3.8 /opt/hazelcast

    # Configurar Hazelcast como servicio
    sudo bash -c 'cat > /etc/systemd/system/hazelcast.service << EOF
    [Unit]
    Description=Hazelcast IMDG
    After=network.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/java -cp /opt/hazelcast/lib/* com.hazelcast.core.server.HazelcastMember
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF'

    # Habilitar y arrancar Hazelcast
    sudo systemctl daemon-reload
    sudo systemctl enable hazelcast
    sudo systemctl start hazelcast
  EOF

  tags = {
    Name = "HazelcastInstance"
  }
}

# Grupo de seguridad para el Datamart
resource "aws_security_group" "datamart_sg" {
  vpc_id      = aws_vpc.datamart_vpc.id
  description = "Allow traffic to Datamart"

  ingress {
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

# Instancia EC2 para el Datamart
resource "aws_instance" "datamart" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.datamart_key.key_name
  subnet_id     = aws_subnet.datamart_subnet.id
  security_groups = [aws_security_group.datamart_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    # Actualizar el sistema
    sudo apt update -y

    # Instalar Java, Maven y Git
    sudo apt install -y openjdk-17-jdk maven git

    # Clonar el repositorio del Datamart
    git clone https://github.com/CreamsCode/datamart
    cd datamart

    # Compilar el Datamart
    mvn clean package

    # Configurar Hazelcast en el código del Datamart (opcional si ya está configurado)
    echo "Hazelcast y Datamart configurados."
  EOF

  tags = {
    Name = "DatamartInstance"
  }
}

# Clave SSH
resource "aws_key_pair" "datamart_key" {
  key_name   = "datamart-key"
  public_key = file("my-key.pub")
}
