provider "aws" {
  region = "us-east-1"
}

# Grupo de seguridad para Hazelcast
resource "aws_security_group" "hazelcast_sg" {
  name        = "hazelcast-sg"
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
  key_name      = "vockey"
  security_groups = [aws_security_group.hazelcast_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y java-17-amazon-corretto wget
    wget https://repo1.maven.org/maven2/com/hazelcast/hazelcast-distribution/5.3.8/hazelcast-distribution-5.3.8.tar.gz
    tar -xvzf hazelcast-distribution-5.3.8.tar.gz
    sudo mv hazelcast-5.3.8 /opt/hazelcast
    nohup java -cp /opt/hazelcast/lib/* com.hazelcast.core.server.HazelcastMember &
    echo "Hazelcast instance ready."
  EOF

  tags = {
    Name = "HazelcastInstance"
  }
}

# Grupo de seguridad para el Datamart
resource "aws_security_group" "datamart_sg" {
  name        = "datamart-sg"
  description = "Allow SSH access to the Datamart instance"

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
resource "aws_instance" "datamart_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "vockey"
  security_groups = [aws_security_group.datamart_sg.name]

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

    # Aplicar las variables de entorno
    source /etc/profile.d/maven.sh

    # Clonar el repositorio del Datamart
    git clone https://github.com/CreamsCode/datamart
    cd datamart

    # Crear archivo de configuración con la IP de Hazelcast (reemplazada dinámicamente)
    echo "hazelcast.ip=REPLACE_WITH_HAZELCAST_IP" > config.properties

    # Compilar el Datamart
    /opt/maven/bin/mvn clean package

    echo "Datamart instance ready."
  EOF

  tags = {
    Name = "DatamartInstance"
  }
}

