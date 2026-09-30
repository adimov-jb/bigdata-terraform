terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_password" "airflow_admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "airflow_admin" {
  name                    = "${var.name_prefix}/airflow/admin"
  description             = "Credenciais do usuário admin do Airflow"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "airflow_admin" {
  secret_id = aws_secretsmanager_secret.airflow_admin.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.airflow_admin.result
  })
}
