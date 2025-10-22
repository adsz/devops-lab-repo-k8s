import json
import urllib3
import os

def lambda_handler(event, context):
    """
    AWS Lambda function to send SNS notifications to Telegram
    """
    
    # Get environment variables
    bot_token = os.environ['TELEGRAM_BOT_TOKEN']
    chat_id = os.environ['TELEGRAM_CHAT_ID']
    
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