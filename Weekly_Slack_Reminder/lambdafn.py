import os
import json
import requests
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    slack_token = os.environ["SLACK_BOT_TOKEN"]
    slack_channel = os.environ["SLACK_CHANNEL_ID"]

    message = {
        "channel": slack_channel,
        "text": (
            "👋 *Hey team!*\n\n"
            "It’s time for your *weekly update*.\n\n"
            "Please share your progress along with Jira ticket numbers and a brief status.\n\n"
            "Thank you! 🙌"
        ),
    }

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {slack_token}"
    }

    response = requests.post("https://slack.com/api/chat.postMessage", headers=headers, data=json.dumps(message))
    slack_response = response.json()

    if response.status_code != 200 or not slack_response.get("ok", False):
        logger.error(f"Slack API error: {response.status_code} - {response.text}")
        raise Exception("Failed to send message to Slack.")

    logger.info("Message sent successfully to Slack.")
    return {
        'statusCode': 200,
        'body': json.dumps('Message sent to Slack!')
    }
