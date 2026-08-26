resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "homelab-ec2-high-cpu"
  alarm_description = "Triggers when average EC2 CPU utilization exceeds 80 percent"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = 300

  evaluation_periods = 2
  threshold          = 80

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = var.instance_id
  }

  treat_missing_data = "missing"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name        = "homelab-ec2-high-memory"
  alarm_description = "Triggers when average memory utilization exceeds 80 percent"

  namespace   = "Homelab/EC2"
  metric_name = "mem_used_percent"

  statistic = "Average"
  period    = 300

  evaluation_periods = 2
  threshold          = 80

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = var.instance_id
  }

  treat_missing_data = "missing"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_disk" {
  alarm_name        = "homelab-ec2-high-disk"
  alarm_description = "Triggers when root filesystem utilization exceeds 80 percent"

  namespace   = "Homelab/EC2"
  metric_name = "disk_used_percent"

  statistic = "Average"
  period    = 300

  evaluation_periods = 2
  threshold          = 80

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = var.instance_id
    path       = "/"
    device     = "nvme0n1p1"
    fstype     = "ext4"
  }

  treat_missing_data = "missing"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name        = "homelab-ec2-status-check-failed"
  alarm_description = "Triggers when the EC2 instance fails an AWS status check"

  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed"

  statistic = "Maximum"
  period    = 60

  evaluation_periods = 2
  threshold          = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    InstanceId = var.instance_id
  }

  treat_missing_data = "missing"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_dashboard" "homelab" {
  dashboard_name = "homelab-ec2-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "EC2 CPU Utilization"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              var.instance_id
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Memory Utilization"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300

          metrics = [
            [
              "Homelab/EC2",
              "mem_used_percent",
              "InstanceId",
              var.instance_id
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Disk Utilization"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300

          metrics = [
            [
              "Homelab/EC2",
              "disk_used_percent",
              "InstanceId",
              var.instance_id
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Network Traffic"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300

          metrics = [
            [
              "AWS/EC2",
              "NetworkIn",
              "InstanceId",
              var.instance_id
            ],
            [
              ".",
              "NetworkOut",
              ".",
              "."
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          title  = "EC2 Status Checks"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60

          metrics = [
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId",
              var.instance_id
            ]
          ]
        }
      }
    ]
  })
}
