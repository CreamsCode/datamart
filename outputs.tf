output "hazelcast_public_ip" {
  value = aws_instance.hazelcast_instance.public_ip
  description = "Public IP of the Hazelcast server instance"
}

output "datamart_instance_public_ip" { # Renombrado para evitar conflicto
  value = aws_instance.datamart_instance.public_ip
  description = "Public IP of the Datamart instance"
}
