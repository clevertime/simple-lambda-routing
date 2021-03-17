
provider "aws" {
  region  = "us-west-2"
  profile = "sunflwr" # use credentials for your aws account
}

variable "deployment_ratio" {
  default     = 0.25
  description = "amount of request routed to new version; will not affect initial deployment"
}

locals {
  prefix           = "simple-lambda-routing"
  deployment_ratio = var.deployment_ration
  function_name    = "hello"
}

resource "aws_iam_role" "lambda" {
  name = local.prefix

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/local.function_name.py"
  output_path = "${path.module}/local.function_name.zip"
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  function_name    = join("-", [local.prefix, "local.function_name"])
  role             = aws_iam_role.lambda.arn
  handler          = "local.function_name.lambda_handler"
  source_code_hash = filebase64sha256(data.archive_file.this.output_path)
  runtime          = "python3.8"
  publish          = true
}

resource "aws_lambda_alias" "this" {
  name             = join("-", [local.prefix, "local.function_name"])
  function_name    = aws_lambda_function.this.arn

  # initial version will be set to 1.0
  function_version = aws_lambda_function.this.version - 1 == 0 ? aws_lambda_function.this.version - 1 : aws_lambda_function.this.version - 1

  routing_config {
    additional_version_weights = {
      tostring(aws_lambda_function.this.version) = local.deployment_ratio
    }
  }
}
