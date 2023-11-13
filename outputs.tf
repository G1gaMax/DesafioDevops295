output "public_ip" {
  value = aws_instance.myEC2Instance.public_ip
}