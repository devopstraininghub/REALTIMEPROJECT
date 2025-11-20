output "public_ip_jenkins" {
  description = "Public IP of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.public_ip
}

output "public_ip_app" {
  description = "Public IP of the MyApp EC2 instance"
  value       = aws_instance.myapp.public_ip
}
