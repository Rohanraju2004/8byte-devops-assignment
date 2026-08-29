data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region    = var.aws_region
    ecr_repo_url  = aws_ecr_repository.app.repository_url
    db_secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn
    db_endpoint   = aws_db_instance.main.endpoint
    db_name       = var.db_name
    app_port      = var.app_port
  })

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-app"
  }
}