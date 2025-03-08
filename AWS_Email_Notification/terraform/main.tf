provider "aws" {
  region = "us-east-1"  # Cambia si usas otra región
}

resource "aws_s3_bucket" "lambda_code" {
  bucket = "notificacion-email-lambda-bucket"
}

resource "aws_sqs_queue" "email_queue" {
  name                      = "email-notification-queue"
  visibility_timeout_seconds = 30
}

resource "aws_sns_topic" "email_topic" {
  name = "email-notification-topic"
}

resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn = aws_sns_topic.email_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.email_queue.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_sqs_access" {
  name       = "lambda-sqs-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "email_sender_lambda" {
  function_name = "EmailSenderFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "email_sender.lambda_handler"
  runtime       = "python3.8"

  s3_bucket = aws_s3_bucket.lambda_code.bucket
  s3_key    = "email_sender.zip"

  # 🚀 Agregamos una etiqueta para forzar la actualización
  tags = {
    version = "1.1"
  }

  environment {
    variables = {
      EMAIL_SMTP_SERVER = "smtp.gmail.com"
      EMAIL_SMTP_PORT   = "587"
      EMAIL_USERNAME    = "jeisonjosedelossantos@gmail.com"
      EMAIL_PASSWORD    = "la clave como es privada la pondre en la presentacion de la tarea aqui estara vacia"
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.email_sender_lambda.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "LambdaErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Se ha detectado un error en la ejecución de Lambda."
  alarm_actions       = [aws_sns_topic.email_topic.arn]
  dimensions = {
    FunctionName = aws_lambda_function.email_sender_lambda.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_queue_length_alarm" {
  alarm_name          = "SQSQueueLengthAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Se han detectado más de 10 mensajes pendientes en la cola SQS."
  alarm_actions       = [aws_sns_topic.email_topic.arn]
  dimensions = {
    QueueName = aws_sqs_queue.email_queue.name
  }
}

