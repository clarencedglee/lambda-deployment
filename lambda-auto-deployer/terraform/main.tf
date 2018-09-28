variable "bucket_name" {
  default = "bit-clarence-bucket"
  type = "string"
}
variable "deployer_fn_name" {
  default = "bit-clarence-lambda-auto-deployer"
  type = "string"
}

variable "target_fn_name" {
  default = "bit-clarence"
  type = "string"
}

variable "target_fn_zip_name" {
  default = "lambda.zip"
  type = "string"
}

locals {
  caller_account_id = "${data.aws_caller_identity.current.account_id}"
  caller_arn = "${data.aws_caller_identity.current.arn}"
  region = "${data.aws_region.current.name}"
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
  function_arn = "arn:aws:lambda:${local.region}:${local.caller_account_id}:function:${var.deployer_fn_name}"
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_lambda_function" "deployer" {
  function_name = "${var.deployer_fn_name}"
  filename      = "../build/lambda-auto-deployer.zip"
  handler       = "index.handler"
  runtime       = "nodejs8.10"
  role          = "${aws_iam_role.auto_deployer_role.arn}"
  environment {
    variables = {
      BUCKET_NAME = "${var.bucket_name}"
      BUCKET_KEY = "${var.target_fn_zip_name}"
      TARGET_FN_NAME = "${var.target_fn_name}"
    }
  }
}

resource "aws_iam_role" "auto_deployer_role" {
  name = "${var.deployer_fn_name}_role"
  assume_role_policy = "${data.aws_iam_policy_document.auto-deployer-assume.json}"
}

resource "aws_iam_role_policy" "policy" {
  role = "${aws_iam_role.auto_deployer_role.id}"
  policy = "${data.aws_iam_policy_document.auto-deployer.json}"
}

data "aws_iam_policy_document" "auto-deployer-assume" {
  statement = {
    actions = ["sts:AssumeRole"]
    principals = {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "auto-deployer" {
  statement {
    sid = "lambda"
    actions = [
      "lambda:UpdateFunctionCode",
    ]
    resources = ["arn:aws:lambda:${local.region}:${local.caller_account_id}:function:${var.target_fn_name}"]
  }
  statement {
    sid = "logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    sid = "s3"
    actions = [
      "s3:GetObject",
    ]
    resources = ["${local.bucket_arn}/*"]
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.deployer.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.source.arn}"
}


resource "aws_s3_bucket" "source" {
  bucket = "${var.bucket_name}"
  acl = "private"
  versioning {
    enabled = true
  }
  policy = "${data.aws_iam_policy_document.bucket_policy.json}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.source.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.deployer.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".zip"
  }
}
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid="allow-deploy"
    actions = ["s3:PutObject"]
    resources = ["${local.bucket_arn}/*"]
    principals = {
      type = "AWS"
      identifiers = ["${local.caller_arn}"]
    }
  }
  statement {
    sid="allow-lambda-get"
    actions = ["s3:GetObject"]
    resources = ["${local.bucket_arn}/*"]
    principals = {
      type = "AWS"
      identifiers = ["${aws_iam_role.auto_deployer_role.arn}"]
    }
  }
}
