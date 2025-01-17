variable "ami_id" {
  description = "AMI ID para la instancia de AWS"
  default     = "ami-0c02fb55956c7d316" # Cambia esto según sea necesario
}

variable "instance_type" {
  description = "Tipo de instancia de AWS (por ejemplo, t2.micro)"
  default     = "t2.micro"
}

variable "mongodb_ip" {
  description = "IP of MongoServer"
  type        = string
}