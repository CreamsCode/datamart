provider "aws" {
  region = "us-east-1"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/vpc/id"
}

data "aws_ssm_parameter" "igw_id" {
  name = "/shared/vpc/igw_id"
}

data "aws_ssm_parameter" "route_table_id" {
  name = "/shared/vpc/route_table_id"
}

resource "aws_subnet" "datamart_subnet" {
  vpc_id                  = data.aws_ssm_parameter.vpc_id.value
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "DatamartSubnet"
  }
}

resource "aws_route_table_association" "datamart_subnet_association" {
  subnet_id      = aws_subnet.datamart_subnet.id
  route_table_id = data.aws_ssm_parameter.route_table_id.value
}

resource "aws_security_group" "hazelcast_sg" {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  tags = {
    Name = "HazelcastSecurityGroup"
  }

  ingress {
    description = "Hazelcast Port"
    from_port   = 5701
    to_port     = 5710
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

resource "aws_security_group" "datamart_sg" {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
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

resource "aws_instance" "hazelcast_instance" {
  ami           = "ami-05576a079321f21f8"
  instance_type = "t2.micro"
  key_name      = "vockey"
  subnet_id     = aws_subnet.datamart_subnet.id
  vpc_security_group_ids = [aws_security_group.hazelcast_sg.id]
  iam_instance_profile   = "EMR_EC2_DefaultRole"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y java-17-amazon-corretto wget

    # Descargar y configurar Hazelcast
    wget https://repository.hazelcast.com/rpm/stable/hazelcast-rpm-stable.repo -O hazelcast-rpm-stable.repo
    sudo mv hazelcast-rpm-stable.repo /etc/yum.repos.d/
    sudo yum install hazelcast-5.5.0 -y

    CONFIG_PATH="/usr/lib/hazelcast/config/hazelcast.xml"

    # Asegurarse de que el archivo de configuración existe
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "El archivo $CONFIG_PATH no existe. Asegúrate de que Hazelcast está instalado correctamente."
        exit 1
    fi

    # Modificar el cluster-name
    sudo sed -i 's|<cluster-name>.*</cluster-name>|<cluster-name>dev</cluster-name>|g' "$CONFIG_PATH"

    # Habilitar hazelcast.socket.bind.any
    sudo sed -i 's|<property name="hazelcast.socket.bind.any">.*</property>|<property name="hazelcast.socket.bind.any">true</property>|g' "$CONFIG_PATH"

    # Configurar la sección <join>
    sudo sed -i 's|<multicast enabled=".*"|<multicast enabled="false"|g' "$CONFIG_PATH"
    sudo sed -i 's|<tcp-ip enabled=".*"|<tcp-ip enabled="true"|g' "$CONFIG_PATH"

    # Configurar la sección <network> para conexiones externas
    sudo sed -i '/<network>/,/<\/network>/c\
        <network>\n\
            <interfaces enabled="false" />\n\
            <rest-api enabled="true">\n\
                <endpoint-group name="HEALTH_CHECK" enabled="true" />\n\
                <endpoint-group name="CLUSTER_READ" enabled="true" />\n\
            </rest-api>\n\
        </network>' "$CONFIG_PATH"

    # Reiniciar Hazelcast
    sudo systemctl restart hazelcast

    hz start

    echo "Hazelcast server ready."
  EOF


  tags = {
    Name = "HazelcastInstance"
  }
}

resource "aws_instance" "datamart_instance" {
  ami           = "ami-05576a079321f21f8"
  instance_type = "t2.micro"
  key_name      = "vockey"
  subnet_id     = aws_subnet.datamart_subnet.id
  vpc_security_group_ids = [aws_security_group.datamart_sg.id]
  iam_instance_profile   = "EMR_EC2_DefaultRole"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y java-17-amazon-corretto git wget

    # Configuración de Maven
    wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
    sudo tar -xvzf apache-maven-3.9.9-bin.tar.gz -C /opt
    sudo mv /opt/apache-maven-3.9.9 /opt/maven
    echo "export M2_HOME=/opt/maven" | sudo tee /etc/profile.d/maven.sh
    echo "export PATH=\$M2_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/maven.sh
    source /etc/profile.d/maven.sh

    # Clonar repositorio Datamart
    git clone https://github.com/CreamsCode/datamart /home/ec2-user/datamart
    cd /home/ec2-user/datamart

    export HAZELCAST_IP=${aws_instance.hazelcast_instance.public_ip}
    export MONGO_IP="${var.mongodb_ip}"

    echo "Hazelcast IP: $HAZELCAST_IP"
    echo "Mongo IP: $MONGO_IP"

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
