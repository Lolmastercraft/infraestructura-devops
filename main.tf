// Configuración del proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"        // versión del proveedor AWS
    }
  }
}

provider "aws" {
  region = "us-east-1"          // Región AWS (ajusta si tu lab usa otra región)
}

// 1. VPC
resource "aws_vpc" "vpc_principal" {
  cidr_block           = "10.10.0.0/20"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AcademyVPC"
  }
}

// 2. Internet Gateway (IGW) para la VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_principal.id

  tags = {
    Name = "AcademyVPC-IGW"
  }
}

// 3. Subred pública
resource "aws_subnet" "subnet_publica" {
  vpc_id                  = aws_vpc.vpc_principal.id
  cidr_block              = "10.10.0.0/24"
  map_public_ip_on_launch = true   // Asignar IP pública automáticamente a instancias en esta subred
  availability_zone       = "us-east-1a"  // AZ a elegir; puedes cambiarla según la región

  tags = {
    Name = "Academy-Subnet-publica"
  }
}

// 4. Tabla de rutas pública (para Internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Academy-public-RT"
  }
}

// Asociar la tabla de rutas pública a la subred pública
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.subnet_publica.id
  route_table_id = aws_route_table.public_rt.id
}

// 5. Security Group para Jump Server
resource "aws_security_group" "sg_jump" {
  name        = "SG-JumpServer"
  description = "Permite SSH desde Internet al Jump Server"
  vpc_id      = aws_vpc.vpc_principal.id

  ingress {                      // Reglas de entrada
    description = "SSH desde cualquier lugar (0.0.0.0/0) - ajustar según requerimientos"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {                       // Reglas de salida
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG_Jump"
  }
}

// 6. Security Group para Web Servers
resource "aws_security_group" "sg_web" {
  name        = "SG-WebServers"
  description = "Permite SSH solo desde Jump Server; HTTP desde internet"
  vpc_id      = aws_vpc.vpc_principal.id

  ingress {
    description      = "SSH desde Jump Server"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    # Permitir entrada desde el SG del Jump Server
    security_groups  = [aws_security_group.sg_jump.id]
  }
  ingress {
    description = "HTTP desde cualquier lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG_Web"
  }
}

// 7. Key Pair (llave SSH) para las instancias
// *** Ver nota abajo sobre la creación de la llave devops-key ***
resource "aws_key_pair" "devops_key" {
  key_name   = "devops-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

// 8. Instancia EC2 Jump Server
resource "aws_instance" "jump_server" {
  ami           = "ami-0947d2ba12ee1ff75"   // ID AMI Amazon Linux 2 en us-east-1 (verificar y actualizar según región)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_publica.id
  key_name      = aws_key_pair.devops_key.key_name
  associate_public_ip_address = true
  security_groups = [aws_security_group.sg_jump.id]

  tags = {
    Name = "JumpServer"
  }
}

// 9. Instancias EC2 Web Servers (tres instancias utilizando count)
resource "aws_instance" "web_servers" {
  count         = 3                        // crea 3 instancias
  ami           = "ami-0947d2ba12ee1ff75"  // misma AMI de Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_publica.id
  key_name      = aws_key_pair.devops_key.key_name
  associate_public_ip_address = true
  security_groups = [aws_security_group.sg_web.id]

  tags = {
    Name = "WebServer-${count.index + 1}"
  }
}

// 10. (Opcional) Salida de las IP para fácil referencia
output "jump_public_ip" {
  description = "Dirección IP pública del Jump Server"
  value       = aws_instance.jump_server.public_ip
}
output "web_public_ips" {
  description = "Direcciones IP públicas de los servidores web"
  value       = [for inst in aws_instance.web_servers : inst.public_ip]
}
