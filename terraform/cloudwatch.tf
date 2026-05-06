# logs del lambda de subida
resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.upload_lambda.function_name}"
  retention_in_days = 14 
}

# logs del lambda de recorte
resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.crop_lambda.function_name}"
  retention_in_days = 14
}

# logs del api
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/image-processor-${terraform.workspace}-api"
  retention_in_days = 14
}

# canal de notificaciones
resource "aws_sns_topic" "alerts" {
  name = "image-processor-${terraform.workspace}-alerts"
}

# alarma para cuando fallen los mensajes
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "dlq-messages-alarm-${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold" 
  evaluation_periods  = 1                      
  metric_name         = "ApproximateNumberOfMessagesVisible" 
  namespace           = "AWS/SQS"              
  period              = 60                     
  statistic           = "Maximum"              
  threshold           = 0                      
  alarm_description   = "Alarm when DLQ has visible messages"
  
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}
