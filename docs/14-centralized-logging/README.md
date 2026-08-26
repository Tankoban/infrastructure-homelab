# Lab 14 — Centralized Logging

## Overview

This lab expanded the AWS homelab from metrics collection into centralized logging.

Host system logs and container application logs originate from different layers of the architecture, so two different collection paths were used.

Ubuntu syslog is collected through the Amazon CloudWatch Agent, while the Dockerized Nginx reverse proxy sends its stdout and stderr directly to CloudWatch Logs using Docker's `awslogs` logging driver.

The implementation was managed through Terraform and EC2 bootstrap automation so that centralized logging would return automatically after the disposable homelab infrastructure was destroyed and recreated.

---

## Objectives

The objectives of this lab were to:

- Understand the difference between metrics and logs
- Create Terraform-managed CloudWatch log groups
- Apply explicit log retention policies
- Centralize Ubuntu system logs
- Identify where containerized Nginx actually emits logs
- Understand Docker logging drivers
- Configure Docker to publish container logs directly to CloudWatch
- Troubleshoot generated YAML and JSON configuration
- Validate log streams and events through the AWS CLI
- Confirm centralized logging after a complete infrastructure rebuild

---

## Architecture

```text
Ubuntu Host
    |
    v
/var/log/syslog
    |
    v
CloudWatch Agent
    |
    v
CloudWatch Logs
    |
    v
/homelab/ec2/syslog


Nginx Container
    |
    v
stdout / stderr
    |
    v
Docker awslogs driver
    |
    v
CloudWatch Logs
    |
    v
/homelab/nginx
```

---

## Metrics vs Logs

Metrics and logs provide different kinds of operational visibility.

```text
Metric
= numerical measurement over time

Log
= record of an event that occurred
```

For example:

```text
Memory utilization = metric

HTTP request to App1 = log event
```

Metrics help answer:

```text
How much?
How often?
How high?
How low?
```

Logs help answer:

```text
What happened?
When did it happen?
What requested it?
What response was returned?
```

Together, metrics and logs provide a more complete view of system behavior.

---

## Terraform-Managed Log Groups

CloudWatch log groups were added to the Terraform observability module.

The final log groups are:

```text
/homelab/ec2/syslog
/homelab/nginx
```

Each group uses a seven-day retention policy.

Conceptually:

```text
Terraform
= creates the filing cabinets

Log producers
= place records into those cabinets
```

Managing log groups through Terraform ensures that:

```text
Naming
Retention
Tagging
Lifecycle
```

are explicit infrastructure decisions rather than runtime defaults.

---

## Ubuntu Syslog Collection

The existing CloudWatch Agent configuration was extended to collect:

```text
/var/log/syslog
```

The source file is mapped into:

```text
/homelab/ec2/syslog
```

A log stream identifies the specific EC2 source using the instance ID.

Conceptually:

```text
file_path
= where the log originates on Linux

log_group_name
= CloudWatch destination

log_stream_name
= specific source within the log group
```

The flow is:

```text
Ubuntu
   |
   v
/var/log/syslog
   |
   v
CloudWatch Agent
   |
   v
/homelab/ec2/syslog
```

---

## Container Logging Investigation

The original plan assumed Nginx logs would exist on the Ubuntu host at:

```text
/var/log/nginx/access.log
/var/log/nginx/error.log
```

Inspection showed that:

```text
/var/log/syslog        exists
/var/log/nginx/        does not exist
```

This was not an Nginx failure.

The reverse proxy runs inside Docker rather than directly on the Ubuntu host.

The architecture is therefore:

```text
Ubuntu Host
└── Docker
    └── Nginx Container
```

The host does not naturally receive Nginx log files beneath:

```text
/var/log/nginx/
```

---

## Docker Log Discovery

The Nginx container was inspected to identify its logging behavior.

Docker reported:

```text
Logging driver: json-file
```

and a log path beneath:

```text
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```

This showed that the reverse proxy was writing stdout and stderr through Docker's default `json-file` logging driver.

The initial flow was:

```text
Nginx
   |
   v
stdout / stderr
   |
   v
Docker json-file
   |
   v
Local Docker storage
```

---

## Why the Docker Log File Was Not Collected Directly

The CloudWatch Agent could theoretically have been configured to read Docker's JSON log file directly.

However, Docker stores those files beneath a path containing the container ID:

```text
/var/lib/docker/containers/<container-id>/
```

Container IDs change whenever a container is recreated.

Building centralized logging around this internal path would therefore create unnecessary coupling between the logging configuration and Docker's ephemeral container identifiers.

Instead, Docker itself was configured to send container output directly to CloudWatch Logs.

---

## Docker awslogs Driver

The reverse proxy's Docker Compose configuration was changed to use:

```text
awslogs
```

instead of:

```text
json-file
```

The logging configuration sends Nginx stdout and stderr into:

```text
/homelab/nginx
```

using the stream:

```text
reverse-proxy
```

Conceptually:

```text
Nginx Container
      |
      v
stdout / stderr
      |
      v
Docker awslogs
      |
      v
CloudWatch Logs
      |
      v
/homelab/nginx
```

The EC2 workload identity created in Lab 13 provides the AWS permissions required to publish these logs.

No long-lived AWS credentials are stored in Docker Compose.

---

## Access and Error Logs

The initial Terraform design created separate groups for:

```text
/homelab/nginx/access
/homelab/nginx/error
```

However, the Docker logging driver receives the container's stdout and stderr output as the container's logging stream.

Separating Nginx access and error logs into different CloudWatch groups would require additional Nginx-specific logging configuration.

For this lab, the design was simplified to:

```text
/homelab/nginx
```

This better reflects the actual container logging architecture.

---

## CloudWatch Agent JSON Extension

The CloudWatch Agent JSON configuration was extended with a top-level:

```json
"logs"
```

section alongside:

```json
"agent"
```

and:

```json
"metrics"
```

The intended high-level structure is:

```text
{
  agent,
  metrics,
  logs
}
```

The syslog collection configuration identifies:

```text
file_path
log_group_name
log_stream_name
```

for the Ubuntu system log.

---

## Problem Encountered — YAML Tab Indentation

After adding the Docker `awslogs` configuration, Terraform successfully created a fresh EC2 instance, but the Docker application stack did not start.

Cloud-init showed:

```text
docker compose config
yaml: line 7: found character that cannot start any token
```

The issue was traced to tab characters used for indentation inside the Docker Compose YAML embedded in `user-data.sh`.

YAML requires spaces for indentation.

The source script was checked using:

```bash
grep -nP '\t' user-data.sh
```

This made tab characters easier to identify.

The affected Compose block was rewritten using spaces only.

This reinforced an important configuration-management lesson:

> Configuration files can fail because of invisible whitespace even when their structure appears visually correct.

---

## Problem Encountered — Malformed CloudWatch Agent JSON

After extending the agent configuration for logs, CloudWatch Agent reported repeated errors:

```text
Cannot translate JSON, ERROR is exit status 1
```

The source JSON was validated with:

```bash
python3 -m json.tool
```

The parser identified:

```text
Expecting property name enclosed in double quotes
```

at a specific line and column.

Inspecting the configuration with line numbers showed that a second JSON object had accidentally been inserted after the existing metrics block.

The malformed structure resembled:

```text
{
  agent,
  metrics
},
{
  agent,
  ...
}
```

instead of the intended:

```text
{
  agent,
  metrics,
  logs
}
```

The CloudWatch Agent section in `user-data.sh` was rewritten cleanly and validated before another Terraform apply.

---

## JSON Validation

The generated CloudWatch configuration was validated using:

```bash
python3 -m json.tool \
  /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json
```

This provided a direct syntax check and identified exact error locations.

This became part of the troubleshooting process before assuming that IAM permissions or CloudWatch itself were responsible.

---

## Problem Encountered — Docker Bootstrap Failure

When the fresh EC2 instance came online but the containers were missing, the failure was traced through:

```text
EC2 boot
   |
   v
cloud-init
   |
   v
user-data.sh
   |
   v
docker compose config
   |
   v
YAML parser error
```

The most useful log was:

```text
/var/log/cloud-init-output.log
```

This showed exactly where the bootstrap process stopped.

The troubleshooting sequence was:

```text
EC2 exists
    |
    v
Check Docker service
    |
    v
Check installed packages
    |
    v
Inspect cloud-init output
    |
    v
Identify failing command
    |
    v
Inspect generated YAML
```

This avoided manually repairing the instance before understanding the actual automation failure.

---

## Problem Encountered — Log Stream Placeholder

During AWS CLI validation, the command:

```bash
aws logs get-log-events
```

was initially run using the literal placeholder:

```text
<STREAM_NAME>
```

CloudWatch correctly returned:

```text
The specified log stream does not exist
```

The correct workflow was:

```text
1. Describe the log streams
2. Retrieve the actual stream name
3. Use that stream with get-log-events
```

This reinforced the distinction between:

```text
Log group
= logical collection of related logs

Log stream
= individual source within that group
```

---

## Local vs EC2 AWS CLI

An AWS CLI log query was also initially attempted from inside the EC2 instance.

The instance did not have the AWS CLI installed.

This did not indicate a logging failure.

The architecture does not require the AWS CLI on the server.

The EC2 instance produces telemetry, while the local workstation uses the AWS CLI to inspect CloudWatch.

Conceptually:

```text
EC2
= produces logs

CloudWatch
= stores logs

Local AWS CLI
= queries logs
```

---

## Centralized Logging Validation

The Ubuntu syslog stream was verified using:

```bash
aws logs describe-log-streams \
  --log-group-name "/homelab/ec2/syslog" \
  --profile lab-admin \
  --region us-east-2
```

The actual stream name was then used to retrieve events.

Nginx logging was verified using:

```bash
aws logs describe-log-streams \
  --log-group-name "/homelab/nginx" \
  --profile lab-admin \
  --region us-east-2
```

The expected stream was:

```text
reverse-proxy
```

Fresh HTTP traffic was generated against the application and corresponding log events were retrieved from CloudWatch.

---

## Reproducibility Validation

The disposable homelab was later destroyed and recreated.

After the rebuild, centralized logging returned automatically without manual configuration.

Validated:

```text
CloudWatch log groups recreated        ✓
7-day retention restored               ✓
CloudWatch Agent running               ✓
Syslog configuration restored          ✓
Syslog stream recreated                ✓
Syslog events retrievable              ✓
Docker containers recreated            ✓
Nginx awslogs driver restored           ✓
Nginx log stream recreated             ✓
HTTP request logs retrievable          ✓
No manual log setup required           ✓
```

This demonstrated that centralized logging had become part of the reproducible infrastructure configuration.

---

## Key Concepts Learned

```text
Centralized logging
CloudWatch Logs
Log groups
Log streams
Log retention
Linux syslog
Docker stdout
Docker stderr
Docker logging drivers
json-file
awslogs
Container logging architecture
EC2 workload identity
Cloud-init troubleshooting
Docker Compose validation
YAML indentation
JSON syntax validation
Configuration-generated failures
Infrastructure reproducibility
```

---

## Interview-Ready Explanation

> I implemented centralized logging for both the Linux host and Docker application layer of my AWS homelab. Ubuntu syslog is forwarded through the CloudWatch Agent, while the containerized Nginx reverse proxy uses Docker's awslogs driver to send stdout and stderr directly to CloudWatch Logs. I manage the log groups and retention policies through Terraform and validated the implementation by destroying and recreating the environment. During the lab, I also diagnosed bootstrap failures caused by YAML tab indentation and malformed CloudWatch Agent JSON using cloud-init logs and configuration validation tools.

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Implemented centralized AWS logging for Linux host and Docker container workloads using CloudWatch Logs. Configured the CloudWatch Agent to forward Ubuntu syslog, integrated Docker's native awslogs driver with a containerized Nginx reverse proxy, and managed log groups and retention through Terraform. Diagnosed YAML indentation and malformed JSON bootstrap failures and validated complete logging recovery after infrastructure recreation.

---

# Result

The homelab now centralizes operational events from both the host operating system and the container application layer.

The completed logging architecture is:

```text
Ubuntu syslog
      |
      v
CloudWatch Agent
      |
      v
CloudWatch Logs


Nginx container
      |
      v
Docker awslogs
      |
      v
CloudWatch Logs
```

Operational troubleshooting no longer depends exclusively on SSH access, local log files, or interactive Docker commands.

Centralized logging is now a reproducible part of the AWS infrastructure.
