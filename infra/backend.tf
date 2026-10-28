resource "aws_dynamodb_table" "counter" {
  name         = "resource-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "visits" {
  table_name = aws_dynamodb_table.counter.name
  hash_key   = aws_dynamodb_table.counter.hash_key

  item = jsonencode({
    id    = { S = "visits" }
    count = { N = "0" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../backend/app.py"
  output_path = "${path.module}/build/lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "resume-counter-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_dynamo" {
  statement {
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.counter.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamo" {
  name   = "update-counter"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_dynamo.json
}

resource "aws_lambda_function" "counter" {
  function_name    = "resume-counter"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.counter.name
      ALLOWED_ORIGIN = "https://${aws_cloudfront_distribution.site.domain_name}"
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/resume-counter"
  retention_in_days = 7
}

resource "aws_apigatewayv2_api" "api" {
  name          = "resume-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${aws_cloudfront_distribution.site.domain_name}"]
    allow_methods = ["GET"]
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.counter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "count" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 1
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}