output "api_id" {
  description = "AppSync Events API ID."
  value       = aws_appsync_api.this.api_id
}

output "api_arn" {
  description = "AppSync Events API ARN."
  value       = aws_appsync_api.this.api_arn
}

output "http_endpoint" {
  description = "IAM-signed HTTP publishing endpoint, including /event."
  value       = "https://${aws_appsync_api.this.dns["HTTP"]}/event"
}

output "websocket_endpoint" {
  description = "Cognito-authenticated WebSocket endpoint, including /event/realtime."
  value       = "wss://${aws_appsync_api.this.dns["REALTIME"]}/event/realtime"
}

output "namespace_arns" {
  description = "Namespace ARNs keyed by chat and notifications."
  value       = { for name, namespace in aws_appsync_channel_namespace.this : name => namespace.channel_namespace_arn }
}

output "backend_environment" {
  description = "Non-secret publishing configuration for the backend."
  value = {
    APPSYNC_EVENTS_HTTP_ENDPOINT = "https://${aws_appsync_api.this.dns["HTTP"]}/event"
    APPSYNC_EVENTS_REGION        = data.aws_region.current.region
  }
}
