provider "aws" {
  region = "us-east-2"
}

data "aws_secretsmanager_secret_version" "slack_credentials" {
  secret_id = "Hari_AI_SlackBot_Cred"  # Update this if your secret has a different name
}

locals {
  slack_secrets = jsondecode(data.aws_secretsmanager_secret_version.slack_credentials.secret_string)
}


#######################
# IAM Role & Policies #
#######################

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_slack_alert_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_secret_policy" {
  name = "LambdaSecretsAccess"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = "*"  # Or the specific ARN of your secret
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_secret_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_secret_policy.arn
}


###########################
# Lambda + Trigger Setup  #
###########################

resource "aws_lambda_function" "send_slack_message" {
  filename         = "lambda_function.zip"
  function_name    = "SendSlackWeeklyUpdate"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 10

  environment {
    variables = {
        SLACK_BOT_TOKEN  = local.slack_secrets.SLACK_BOT_TOKEN
        SLACK_CHANNEL_ID = local.slack_secrets.SLACK_CHANNEL_ID
    }
  }
}

resource "aws_cloudwatch_event_rule" "weekly_trigger" {
  name                = "SlackUpdateTrigger"
  schedule_expression = "cron(0 9 ? * 3,6 *)" # Wed & Fri 9 AM UTC
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_trigger.name
  target_id = "SendSlackMessageTarget"
  arn       = aws_lambda_function.send_slack_message.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_slack_message.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_trigger.arn
}
