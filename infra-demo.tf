# Setup Providers
provider "aws" {
  version = "~> 2.61"
}

variable "default_tags" {
  type = map
  default = {
    Env = "Demo"
    App = "TeknoCerdas"
    FromTerraform = "true"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "LambdaBasicExec"
  tags = var.default_tags
  description = "Allows Lambda functions to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role = aws_iam_role.lambda_exec.name
  # AWS Managed
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "bash_word_counter" {
  function_name = "BashWordCounter"
  handler       = "functions.handler"
  role          = aws_iam_role.lambda_exec.arn
  memory_size   = 128
  runtime       = "provided"
  tags          = var.default_tags

  filename = "build/lambda.zip"
  source_code_hash = filebase64sha256("build/lambda.zip")
}

resource "aws_apigatewayv2_api" "bash_word_counter" {
  name          = "WordCounterAPI"
  protocol_type = "HTTP"
  tags          = var.default_tags
}

resource "aws_apigatewayv2_integration" "bash_word_counter" {
  api_id              = aws_apigatewayv2_api.bash_word_counter.id
  integration_uri     = aws_lambda_function.bash_word_counter.arn
  integration_type    = "AWS_PROXY"
  integration_method  = "POST"
  connection_type     = "INTERNET"
  payload_format_version = "2.0"

  # Terraform bug?
  # passthrough_behavior only valid for WEBSOCKET but it detect changes for HTTP
  lifecycle {
    ignore_changes = [passthrough_behavior]
  }
}

resource "aws_apigatewayv2_route" "bash_word_counter" {
  api_id    = aws_apigatewayv2_api.bash_word_counter.id
  route_key = "POST /words"
  authorization_type = "NONE"
  target    = "integrations/${aws_apigatewayv2_integration.bash_word_counter.id}"
}

resource "aws_apigatewayv2_stage" "bash_word_counter" {
  api_id    = aws_apigatewayv2_api.bash_word_counter.id
  tags      = var.default_tags
  name      = "$default"
  auto_deploy = "true"

  # Terraform bug
  # https://github.com/terraform-providers/terraform-provider-aws/issues/12893
  lifecycle {
    ignore_changes = [deployment_id, default_route_settings]
  }
}

# By default other AWS resource can not call Lambda function
# It needs to be granted manually by giving lambda:InvokeFunction permission
resource "aws_lambda_permission" "bash_word_counter" {
  statement_id  = "AllowApiGatewayToInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bash_word_counter.function_name
  principal     = "apigateway.amazonaws.com"

  # /*/*/* = Any stage / any method / any path
  source_arn    = "${aws_apigatewayv2_api.bash_word_counter.execution_arn}/*/*/words"
}