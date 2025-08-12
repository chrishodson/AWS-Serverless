# AWS-Serverless
AWS integration to port.io that is event driven and serverless

## These terraform scripts will:
1. Create/validate a webhook in port for each AWS type supported
1. Set up blueprints and mapps for each support AWS type
1. Create/validate an SQS queue
1. Create an EventBridge rule in the AWS account.
    1. Filter on the supported AWS types
    1. For all events, put the event into SQS
1. Create a lambda that reads SQS and put the events into the correct webhook
    1. Create env variables for:
         1. webhook secret
         1. SQS queue name
         1. webhook name for each supported service
1. Create a rule to run the lambda when the SQS queue > 0

## Supported AWS types:
* EC2 instances
* Current running state of EC2 instances
* S3 buckets
* RDS instances
* SQS queues

## Shortfalls compared to current Ocean integration:
* K8s inspection
* Multi-account support

## Improvements/TODO/Open Questions
* Should it use one webhook vs one per type?
* Should it use webhooks vs API?
* What additional AWS types should we support out of the box?
