output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.learnai_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.learnai_client.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.textbook_bucket.id
}

output "ec2_instance_public_ip" {
  value = aws_instance.learnai_app.public_ip
}