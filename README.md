# AWS-Serverless
AWS integration to port.io that is event driven and serverless

These terraform scripts will:
1. Create/validate a webhook in port for each AWS type supported
1. Create/validate an SQS queue
1. Create an EventBridge in the AWS account.
    1. For some events (ec2 state change) write directly to the webhook
    1. For all other events, put the event into SQS
1. Create a lambda that reads SQS and put the events into the correct webhook
    1. Create env variables for:
         1. webhook secret
         3. SQS queue name
         4. webhook name for each supported service
3. Create a rule to run the lambda when the SQS queue > 0
