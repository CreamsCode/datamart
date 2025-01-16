output "instance_id" {
  value = aws_instance.datamart.id
  description = "ID de la instancia creada en AWS."
}

output "public_ip" {
  value = aws_instance.datamart.public_ip
  description = "IP pública de la instancia creada en AWS."
}