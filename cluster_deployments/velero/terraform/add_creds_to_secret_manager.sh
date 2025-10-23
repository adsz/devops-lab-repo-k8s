aws secretsmanager create-secret --name k8s-production-telegram-notifier --secret-string '{"TELEGRAM_TOKEN":"","TELEGRAM_CHAT_ID":""}'

### Inne
# aws lambda invoke --function-name k8s-production-telegram-notifier --payload '{}' /tmp/telegram-test.json

# aws logs tail /aws/lambda/k8s-production-telegram-notifier --since 1h --follow false

# aws logs filter-log-events --log-group-name /aws/lambda/k8s-production-telegram-notifier --start-time $(( ( $(date +%s) - 3600 ) * 1000 )) --end-time $(( $(date +%s) * 1000 ))

# aws lambda invoke \
#     --function-name k8s-production-telegram-notifier \
#     --payload fileb:///tmp/sns-event.json \
#     /tmp/telegram-invoke-output.json

#   Gdzie /tmp/sns-event.json powinien zawierać np.:

#   {"Records":[{"Sns":{"Subject":"Test","Message":"{\"status\":\"success\"}"}}]}

#   Po wywołaniu możesz sprawdzić logi:

#   aws logs filter-log-events \
#     --log-group-name /aws/lambda/k8s-production-telegram-notifier \
#     --start-time $(( ( $(date +%s) - 300 ) * 1000 )) \
#     --end-time $(( $(date +%s) * 1000 ))
