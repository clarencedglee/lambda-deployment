provider "aws" {
  region = "eu-west-1"
}

resource "aws_lambda_function" "bit-clarence" {
  function_name = "bit-clarence"
  s3_bucket     = "bit-clarence-bucket"
  s3_key        = "lambda.zip"
  handler       = "index.handler"
  runtime       = "nodejs8.10"
  role          = "${aws_iam_role.role.arn}"
}

resource "aws_iam_role" "role" {
  name = "bit-clarence-lambda"

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
