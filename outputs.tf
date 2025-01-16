output "instance_id" {
  value = aws_instance.datamart_instance.id
  description = "ID de la instancia creada en AWS."
}

# Output para verificar la IP Pública
output "datamart_public_ip" {
  value = aws_instance.datamart_instance.public_ip
  description = "Public IP of the Datamart instance"
}

