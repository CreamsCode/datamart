output "hazelcast_public_ip" {
  value = aws_instance.hazelcast_instance.public_ip
  description = "Public IP of the Hazelcast server instance"
}

output "datamart_public_ip" {
  value = aws_instance.datamart_instance.public_ip
  description = "Public IP of the Datamart instance"
}
