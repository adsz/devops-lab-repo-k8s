import json
import urllib3
import os
import boto3

_secrets_client = boto3.client("secretsmanager")
_cached_credentials = None

def lambda_handler(event, context):
    """
    AWS Lambda function to send SNS notifications to Telegram
    """
    
    # Load credentials from Secrets Manager (cached for subsequent invocations)
    bot_token, chat_id = get_telegram_credentials()
    
    # Parse SNS message
    message = json.loads(event['Records'][0]['Sns']['Message'])
    subject = event['Records'][0]['Sns']['Subject']
    
    # Format message for Telegram
    telegram_message = format_telegram_message(subject, message)
    
    # Send to Telegram
    send_telegram_message(bot_token, chat_id, telegram_message)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Message sent successfully')
    }

def format_telegram_message(subject, message):
    """
    Format SNS message for Telegram with enterprise backup context
    """
    
    # Enterprise backup notification formatting
    if 'backup' in subject.lower() or 'velero' in str(message).lower():
        icon = "🔄" if "success" in str(message).lower() else "❌" if "fail" in str(message).lower() else "⚠️"
        
        formatted_message = f"{icon} *Kubernetes Backup Alert*\n\n"
        formatted_message += f"*Subject:* {subject}\n\n"
        
        if isinstance(message, dict):
            for key, value in message.items():
                formatted_message += f"*{key.title()}:* {value}\n"
        else:
            formatted_message += f"*Details:* {message}\n"
            
        formatted_message += f"\n*Cluster:* Production K8s\n"
        formatted_message += f"*Time:* {context.aws_request_id[:8]}...\n"
        
    else:
        # Generic notification formatting
        formatted_message = f"📢 *AWS Notification*\n\n"
        formatted_message += f"*Subject:* {subject}\n\n"
        formatted_message += f"*Message:* {message}\n"
    
    return formatted_message

def send_telegram_message(bot_token, chat_id, message):
    """
    Send message to Telegram using bot API
    """
    
    http = urllib3.PoolManager()
    
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    
    payload = {
        'chat_id': chat_id,
        'text': message,
        'parse_mode': 'Markdown'
    }
    
    try:
        response = http.request('POST', url, fields=payload)
        
        if response.status == 200:
            print(f"Message sent successfully to Telegram chat {chat_id}")
        else:
            print(f"Failed to send message. Status: {response.status}, Response: {response.data}")
            
    except Exception as e:
        print(f"Error sending Telegram message: {str(e)}")
        raise e


def get_telegram_credentials():
    """
    Retrieve Telegram bot credentials from Secrets Manager, caching between invocations.
    """
    global _cached_credentials

    if _cached_credentials:
        return _cached_credentials

    secret_arn = os.environ["TELEGRAM_SECRET_ARN"]
    secret_value = _secrets_client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(secret_value["SecretString"])

    _cached_credentials = (secret["TELEGRAM_TOKEN"], secret["TELEGRAM_CHAT_ID"])
    return _cached_credentials
