# Lab 15 — CloudWatch Alarms & Dashboard

## Overview

This lab completed the first observability phase of the AWS homelab by turning collected telemetry into proactive monitoring.

CloudWatch alarms were created for CPU utilization, memory utilization, disk utilization, and EC2 status-check failures. A centralized CloudWatch dashboard was also created to visualize the most important operational metrics in one place.

The monitoring configuration was managed through Terraform and tested using a controlled memory workload so that alarm behavior could be validated in practice rather than assumed from configuration alone.

---

## Objectives

The objectives of this lab were to:

- Understand the relationship between metrics, logs, and alarms
- Build CloudWatch alarms using Terraform
- Monitor both AWS-native and CloudWatch Agent metrics
- Understand metric namespaces and dimensions
- Avoid circular Terraform module dependencies
- Create a dedicated monitoring module
- Build a centralized CloudWatch dashboard
- Generate controlled system load for monitoring validation
- Verify alarm state transitions
- Restore intended thresholds after testing
- Confirm the final monitoring configuration is clean and reproducible

---

## Metrics, Logs, and Alarms

Metrics, logs, and alarms provide different layers of observability.

```text
Metric
= numerical measurement over time

Log
= detailed record of an event

Alarm
= rule that evaluates metric data and changes state when a condition is met
```

For example:

```text
Memory utilization
      |
      v
CloudWatch metric
      |
      v
Threshold evaluation
      |
      v
CloudWatch alarm
```

Metrics answer questions such as:

```text
How high is CPU usage?
How much memory is being used?
How much disk space remains?
How much traffic is entering or leaving?
```

Logs answer questions such as:

```text
What happened?
When did it happen?
What resource was accessed?
What response was returned?
```

Alarms provide proactive detection when metric conditions become unhealthy.

Logs can also later be transformed into metrics using metric filters, allowing alarms to be created from event patterns.

---

## Monitoring Module Design

A new Terraform child module was created:

```text
terraform/aws/modules/monitoring/
├── main.tf
├── variables.tf
└── outputs.tf
```

This module was intentionally separated from the existing observability module.

The observability module provides the IAM instance profile required by the compute module:

```text
observability
     |
     v
compute
```

The monitoring module requires the EC2 instance ID produced by the compute module:

```text
compute
   |
   v
monitoring
```

If the monitoring resources had been added back into the observability module, the dependency relationship could become circular:

```text
observability
     |
     v
compute
     |
     v
observability
```

The final dependency flow is:

```text
observability
     |
     v
compute
     |
     v
monitoring
```

This keeps Terraform dependencies explicit and one-directional.

---

## Terraform Module Inputs

The monitoring module accepts:

```hcl
variable "instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
}
```

The root module passes the compute module output into monitoring:

```text
aws_instance.web.id
        |
        v
module.compute.instance_id
        |
        v
module.monitoring.instance_id
        |
        v
var.instance_id
```

This allows monitoring resources to automatically follow the EC2 instance created by Terraform.

---

## Terraform Variable Scope

During module integration, Terraform reported:

```text
Reference to undeclared input variable
```

when the root module attempted to use:

```text
var.aws_region
```

without defining that variable in the root module.

A variable declared inside a child module is only available inside that module.

Conceptually:

```text
Root module variable
= available to root configuration

Child module variable
= input available only inside that child module
```

Child-module variables do not automatically become root-module variables.

The immediate solution was to rely on the monitoring module's default region value instead of passing an undeclared root variable.

---

## CPU Utilization Alarm

The CPU alarm monitors the AWS-native metric:

```text
Namespace:
AWS/EC2

Metric:
CPUUtilization
```

The intended configuration is:

```text
Statistic: Average
Period: 300 seconds
Evaluation periods: 2
Threshold: 80%
Comparison: GreaterThanThreshold
```

Conceptually:

```text
5-minute CPU average > 80%
          |
          v
next 5-minute CPU average > 80%
          |
          v
ALARM
```

This avoids triggering from a short CPU spike.

The alarm is associated with the current EC2 instance using:

```text
InstanceId = var.instance_id
```

---

## Memory Utilization Alarm

Memory utilization is collected by the CloudWatch Agent rather than provided automatically by EC2.

The alarm monitors:

```text
Namespace:
Homelab/EC2

Metric:
mem_used_percent
```

The intended configuration is:

```text
Statistic: Average
Period: 300 seconds
Evaluation periods: 2
Threshold: 80%
Comparison: GreaterThanThreshold
```

The EC2 instance ID is used as a metric dimension.

---

## Disk Utilization Alarm

Disk utilization is also collected through the CloudWatch Agent.

The alarm monitors:

```text
Namespace:
Homelab/EC2

Metric:
disk_used_percent
```

CloudWatch metric identity consists of more than the metric name.

A specific time series is identified by:

```text
Namespace
+
Metric name
+
Dimensions
```

The disk metric includes dimensions such as:

```text
InstanceId
device
filesystem type
path
```

The actual dimensions published by the CloudWatch Agent were inspected before configuring the alarm.

This prevents the alarm from accidentally targeting a nonexistent time series.

---

## EC2 Status Check Alarm

The status-check alarm monitors:

```text
Namespace:
AWS/EC2

Metric:
StatusCheckFailed
```

Unlike CPU, memory, and disk alarms, this metric represents AWS's assessment of EC2 instance health.

The intended configuration uses:

```text
Statistic: Maximum
Period: 60 seconds
Evaluation periods: 2
Threshold: 1
Comparison: GreaterThanOrEqualToThreshold
```

Conceptually:

```text
Resource utilization alarms
= workload or operating-system stress

Status-check alarm
= AWS believes the EC2 instance is unhealthy
```

This provides a separate infrastructure-health signal.

---

## Missing Data Handling

The alarms use:

```hcl
treat_missing_data = "missing"
```

This avoids automatically treating missing datapoints as either healthy or unhealthy.

Missing telemetry is handled distinctly from a confirmed threshold breach.

---

## CloudWatch Dashboard

A Terraform-managed CloudWatch dashboard was created:

```text
homelab-ec2-dashboard
```

The dashboard provides a single operational view containing:

```text
CPU utilization
Memory utilization
Disk utilization
Network traffic
EC2 status checks
```

The layout is conceptually:

```text
+----------------------+----------------------+
| CPU Utilization      | Memory Utilization   |
+----------------------+----------------------+
| Disk Utilization     | Network In / Out     |
+---------------------------------------------+
| EC2 Status Checks                           |
+---------------------------------------------+
```

This provides a centralized view of system health without requiring separate CLI queries for every metric.

---

## AWS-Native and Custom Metrics

The dashboard combines metrics from two namespaces.

AWS-native telemetry:

```text
AWS/EC2
├── CPUUtilization
├── NetworkIn
├── NetworkOut
└── StatusCheckFailed
```

CloudWatch Agent telemetry:

```text
Homelab/EC2
├── mem_used_percent
└── disk_used_percent
```

This demonstrates how a single operational dashboard can combine infrastructure-level and guest operating-system telemetry.

---

## Dashboard Validation

The dashboard was verified through the AWS CLI using:

```bash
aws cloudwatch get-dashboard \
  --dashboard-name "homelab-ec2-dashboard" \
  --profile lab-admin \
  --region us-east-2
```

The dashboard body was successfully returned.

The dashboard was also visually inspected in the CloudWatch console to confirm that the configured widgets rendered correctly.

---

## Alarm Validation with stress-ng

The memory alarm was deliberately tested using:

```text
stress-ng
```

### What stress-ng Does

`stress-ng` is a Linux workload-generation utility used to deliberately place controlled stress on system resources.

It can generate load against resources including:

```text
CPU
Memory
Disk
I/O
Processes
```

In this lab, `stress-ng` was used specifically to increase memory utilization so that the CloudWatch memory alarm could be tested under a known condition.

This allowed the monitoring pipeline to be validated without waiting for a real system problem.

---

## Initial Memory Test

The first controlled memory test used:

```bash
stress-ng --vm 1 --vm-bytes 60% --timeout 4m
```

The memory alarm was temporarily configured with:

```text
Threshold: 70%
Period: 60 seconds
Evaluation periods: 2
```

However, the alarm remained in the:

```text
OK
```

state.

Rather than assuming CloudWatch was failing, both the alarm configuration and actual metric data were inspected.

---

## Inspecting Actual Metric Data

CloudWatch metric statistics showed memory values approximately like:

```text
37.3%
41.9%
46.8%
36.2%
34.9%
```

The observed peak was approximately:

```text
46.8%
```

This was well below the temporary alarm threshold of:

```text
70%
```

The alarm was therefore behaving correctly.

The test workload had simply not generated enough memory utilization to satisfy the alarm condition.

---

## Monitoring Troubleshooting Process

The troubleshooting sequence was:

```text
Alarm did not trigger
       |
       v
Verify alarm configuration
       |
       v
Inspect real metric datapoints
       |
       v
Compare telemetry with threshold
       |
       v
Determine whether alarm or test condition is incorrect
```

This demonstrated an important monitoring principle:

> Before changing an alarm, verify the telemetry that the alarm is actually evaluating.

---

## Controlled Threshold Validation

Rather than generating excessive memory pressure on the small EC2 instance, the alarm threshold was temporarily lowered to:

```text
35%
```

The shorter test configuration used:

```text
Period: 60 seconds
Evaluation periods: 2
Threshold: 35%
```

The memory workload was then generated again.

This successfully caused the alarm to transition:

```text
OK
 |
 v
ALARM
```

After the workload ended and memory utilization returned to normal levels, the alarm returned toward its normal healthy state.

This validated the complete monitoring path:

```text
Controlled workload
        |
        v
CloudWatch Agent measures memory
        |
        v
Homelab/EC2 metric published
        |
        v
CloudWatch alarm evaluates datapoints
        |
        v
Threshold crossed
        |
        v
ALARM
```

---

## Restoring the Intended Alarm

After successful testing, the memory alarm was restored to:

```text
Threshold: 80%
Period: 300 seconds
Evaluation periods: 2
```

Terraform was then applied again so the source configuration once again represented the intended long-term monitoring policy rather than the temporary test settings.

This is important because the final Infrastructure as Code should describe the desired operating configuration, not temporary validation conditions.

---

## Alarm State Reason

During testing, CloudWatch briefly displayed a state reason referencing an older threshold while the current alarm configuration already reflected a newer value.

This demonstrated that the alarm's:

```text
StateReason
```

describes the evaluation that produced the current state and may not immediately mirror a newly changed configuration if no new state transition has occurred.

The current alarm settings were verified separately through the alarm configuration fields.

---

## Final Alarm Configuration

The final monitoring configuration includes:

```text
High CPU
├── 80%
├── 5-minute period
└── 2 evaluation periods

High Memory
├── 80%
├── 5-minute period
└── 2 evaluation periods

High Disk
└── CloudWatch Agent disk utilization threshold

EC2 Status Check Failed
├── threshold 1
├── 1-minute period
└── 2 evaluation periods
```

---

## Final Validation

A full end-of-phase validation confirmed:

```text
Terraform formatting clean             ✓
Terraform configuration valid          ✓
Terraform plan clean                    ✓
CPU alarm present                       ✓
Memory alarm present                    ✓
Disk alarm present                      ✓
Status-check alarm present              ✓
Memory threshold restored to 80%        ✓
Memory period restored to 300 seconds   ✓
Dashboard present                       ✓
Dashboard body retrievable              ✓
Dashboard visually rendered             ✓
Custom host metrics publishing          ✓
Syslog centralized                      ✓
Nginx logs centralized                  ✓
Controlled alarm trigger validated      ✓
Alarm recovery behavior validated       ✓
```

---

## Key Concepts Learned

```text
CloudWatch alarms
Metrics vs logs vs alarms
Metric thresholds
Metric namespaces
Metric dimensions
AWS-native EC2 metrics
CloudWatch Agent metrics
Evaluation periods
Monitoring periods
Alarm state transitions
Missing-data handling
EC2 status checks
CloudWatch dashboards
Terraform module dependencies
Terraform module variable scope
Controlled workload testing
stress-ng
Monitoring validation
Telemetry-driven troubleshooting
```

---

## Interview-Ready Explanation

> I created Terraform-managed CloudWatch alarms for CPU, memory, disk utilization, and EC2 status checks, then built a centralized dashboard combining AWS-native and CloudWatch Agent metrics. I deliberately validated the memory alarm using stress-ng. When the first test did not trigger the alarm, I inspected the actual CloudWatch datapoints and confirmed that memory utilization had never crossed the threshold. I then safely lowered the test threshold, verified the alarm transitioned into ALARM, and restored the intended 80% threshold through Terraform afterward.

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Built and validated a Terraform-managed AWS monitoring layer using CloudWatch alarms and dashboards. Implemented alarms across native EC2 and custom CloudWatch Agent metrics for CPU, memory, disk, and instance health, designed a dedicated monitoring module to preserve clean Terraform dependencies, and validated alarm state transitions through controlled Linux workload generation with stress-ng.

---

# Result

The AWS homelab now provides proactive monitoring in addition to metrics collection and centralized logging.

The completed observability workflow is:

```text
Infrastructure
      |
      v
Telemetry collected
      |
      v
Metrics centralized
      |
      v
Dashboard visualization
      |
      v
Alarm evaluation
      |
      v
Unhealthy conditions detected
```

The environment can now:

```text
Measure
Record
Visualize
Detect
```

This completes the alarms and dashboard portion of Phase V.
