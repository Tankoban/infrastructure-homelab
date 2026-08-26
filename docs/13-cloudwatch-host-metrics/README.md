# Lab 13 — CloudWatch Host Metrics

## Overview

This lab introduced host-level observability to the Terraform-managed AWS homelab using the Amazon CloudWatch Agent.

AWS provides several EC2 metrics automatically, including CPU utilization, network traffic, disk I/O, and instance status checks. However, metrics such as memory utilization and filesystem usage require visibility from inside the guest operating system.

The CloudWatch Agent was installed and configured on the Ubuntu EC2 instance to collect this additional telemetry.

The implementation was first validated manually and then incorporated into the EC2 bootstrap process so that host-level monitoring would be automatically restored whenever the disposable homelab infrastructure was recreated.

---

## Objectives

The objectives of this lab were to:

- Understand the difference between AWS-native EC2 metrics and guest operating system metrics
- Configure workload identity for an EC2 instance
- Avoid storing long-lived AWS access keys on the server
- Understand IAM roles, trust policies, and EC2 instance profiles
- Install and configure the Amazon CloudWatch Agent
- Publish Linux host metrics to a custom CloudWatch namespace
- Automate CloudWatch Agent deployment through EC2 user data
- Validate the observability configuration after a fresh Terraform rebuild

---

## Architecture

```text
EC2 Instance
     |
     v
IAM Instance Profile
     |
     v
IAM Role
     |
     v
CloudWatchAgentServerPolicy
     |
     v
Temporary AWS Credentials


Linux Host
     |
     v
CloudWatch Agent
     |
     v
CloudWatch
     |
     v
Homelab/EC2
```

---

## AWS-Native Metrics vs Host Metrics

Amazon EC2 provides several metrics to CloudWatch automatically.

Examples include:

```text
CPUUtilization
NetworkIn
NetworkOut
DiskReadOps
DiskWriteOps
StatusCheckFailed
```

These metrics are visible to AWS from outside the guest operating system.

However, AWS does not automatically know information such as:

```text
Memory utilization
Filesystem utilization
Swap utilization
Filesystem inode availability
```

Those measurements require an agent running inside the operating system.

The Amazon CloudWatch Agent provides that visibility.

---

## Workload Identity

The CloudWatch Agent needs permission to publish telemetry to AWS.

Rather than placing AWS access keys on the EC2 instance, an IAM role was attached through an EC2 instance profile.

The architecture is:

```text
Trust Policy
    |
    | allows EC2 to assume
    v
IAM Role
    |
    | receives permissions from
    v
CloudWatchAgentServerPolicy
    |
    v
Instance Profile
    |
    | attached to
    v
EC2 Instance
```

### IAM Role

The IAM role defines the AWS identity and permissions available to the workload.

A useful mental model is:

```text
IAM Role
= job description
```

The role defines what the workload may do once it assumes that identity.

---

### Trust Policy

The trust policy defines who or what may assume the IAM role.

For this lab, the trusted service is:

```text
ec2.amazonaws.com
```

A useful mental model is:

```text
Trust Policy
= who is eligible to take the job
```

The trust policy does not define what CloudWatch actions the role may perform.

---

### Instance Profile

The instance profile is the AWS mechanism used to attach an IAM role to an EC2 instance.

A useful mental model is:

```text
Instance Profile
= the badge or assignment that attaches the job to the EC2 worker
```

The instance profile does not define or build the EC2 instance itself.

---

## Terraform Observability Module

A new Terraform child module was created:

```text
terraform/aws/modules/observability/
├── main.tf
├── variables.tf
└── outputs.tf
```

The module initially managed:

```text
IAM role
CloudWatch Agent policy attachment
IAM instance profile
```

The module outputs the instance profile name.

That output is passed into the compute module:

```text
module.observability
        |
        v
instance_profile_name
        |
        v
module.compute
        |
        v
aws_instance.web
```

This allowed the existing EC2 instance to receive an AWS workload identity without embedding credentials in the server configuration.

---

## IAM Role Validation

After applying the Terraform changes, the role assignment was verified from inside the EC2 instance using the EC2 Instance Metadata Service.

The metadata service returned:

```text
homelab-cloudwatch-agent-role
```

This confirmed that:

```text
EC2
  |
  v
Instance Profile
  |
  v
IAM Role
  |
  v
Temporary AWS credentials
```

was functioning correctly.

No long-lived AWS access keys were stored on the instance.

---

## CloudWatch Agent Installation

The Amazon CloudWatch Agent was first installed manually so the installation and configuration process could be understood and validated before automation.

The package was downloaded using `wget` and installed using `dpkg`.

Conceptually:

```text
Download package
      |
      v
Install package
      |
      v
Create configuration
      |
      v
Start agent
```

The manual proof of concept was validated before the process was added to the EC2 bootstrap script.

---

## CloudWatch Agent Configuration

The agent was configured to collect:

```text
Memory utilization
Disk utilization
Filesystem inode availability
Swap utilization
```

The configuration uses a collection interval of:

```text
60 seconds
```

The source configuration file is:

```text
/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json
```

The configuration includes:

```text
mem_used_percent
disk_used_percent
disk_inodes_free
swap_used_percent
```

---

## Custom CloudWatch Namespace

The host-level metrics are published into the custom namespace:

```text
Homelab/EC2
```

This distinguishes them from AWS-native EC2 telemetry stored beneath:

```text
AWS/EC2
```

Conceptually:

```text
AWS/EC2
= metrics AWS provides automatically

Homelab/EC2
= guest metrics collected by our CloudWatch Agent
```

The EC2 instance ID is appended as a metric dimension so telemetry can be associated with the correct instance.

---

## CloudWatch Agent Control Command

The CloudWatch Agent configuration is loaded using:

```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:"$CW_CONFIG" \
  -s
```

The options mean:

```text
fetch-config
= load the specified configuration

-m ec2
= run in EC2 mode

-c file:...
= use the specified local configuration file

-s
= start the agent
```

This command executes locally on the EC2 instance.

It does not remotely target the instance from CloudWatch.

---

## Automated CloudWatch Deployment

After the manual proof of concept succeeded, the CloudWatch Agent installation and configuration were added to:

```text
terraform/aws/homelab/user-data.sh
```

The bootstrap process now performs:

```text
EC2 launches
    |
    v
user-data.sh executes
    |
    v
CloudWatch Agent downloaded
    |
    v
Package installed
    |
    v
Configuration directory created
    |
    v
JSON configuration written
    |
    v
Configuration loaded
    |
    v
Agent started
    |
    v
Host metrics published
```

Two shell variables are used:

```bash
CW_AGENT_DEB="/tmp/amazon-cloudwatch-agent.deb"
CW_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json"
```

The first defines the temporary package location.

The second defines the persistent source configuration location.

The downloaded `.deb` file is removed after installation.

---

## Heredoc Configuration

The JSON configuration is written from the bootstrap script using a shell heredoc.

The configuration begins with:

```bash
cat > "$CW_CONFIG" <<'EOF'
```

Using the quoted heredoc delimiter prevents the shell from expanding values such as:

```text
${aws:InstanceId}
```

before the CloudWatch Agent processes the configuration.

The closing:

```text
EOF
```

must appear on its own line.

---

## CloudWatch Agent Working Configuration

During validation, the source JSON configuration initially appeared to be missing.

Inspection of:

```text
/opt/aws/amazon-cloudwatch-agent/etc/
```

showed files including:

```text
cloudwatch-agent.json
amazon-cloudwatch-agent.d/file_cloudwatch-agent.json
amazon-cloudwatch-agent.toml
amazon-cloudwatch-agent.yaml
```

The CloudWatch Agent creates a working copy of a local configuration beneath:

```text
amazon-cloudwatch-agent.d/
```

and generates internal configuration formats used by the agent.

This reinforced the importance of inspecting the active agent configuration rather than assuming the original source file is the only relevant configuration artifact.

---

## Terraform Replacement Behavior

The EC2 resource uses:

```hcl
user_data_replace_on_change = true
```

This means changes to the EC2 user-data script cause Terraform to replace the instance.

The process is:

```text
user-data.sh changes
        |
        v
Terraform detects changed user_data
        |
        v
EC2 marked for replacement
        |
        v
Old EC2 destroyed
        |
        v
Fresh EC2 created
        |
        v
Updated bootstrap executes
```

This is useful because user data is primarily bootstrap-time configuration.

Replacing the instance ensures the updated automation is validated against a fresh system instead of assuming that changing the stored user-data value somehow reruns the complete bootstrap process on an existing machine.

---

## Problems Encountered

### New Terraform Module Required Initialization

After adding the observability module, Terraform reported that the module had not been installed.

The solution was:

```bash
terraform init
```

This reinforced that `terraform init` is not only used when first creating a Terraform project.

It should also be rerun when adding or changing:

```text
Modules
Providers
Backend configuration
```

---

### Terraform Module Variable Scope

During the later monitoring work, an undeclared root variable error reinforced an important Terraform concept first introduced during this phase.

Variables are scoped to the module where they are declared.

A variable declared inside a child module does not automatically become available as:

```text
var.<variable>
```

inside the root module.

Values must be explicitly passed across module boundaries.

---

### SSH Authentication Failure After EC2 Recreation

After recreating the EC2 instance, SSH returned:

```text
Permission denied (publickey)
```

The instance was reachable, which indicated that networking and the SSH service were functioning.

The failure was isolated to authentication.

Inspection showed that the locally stored private key did not correspond to the public key registered in AWS under:

```text
homelab-ec2-key
```

The public key was regenerated from the existing private key and imported into AWS.

The EC2 instance was then replaced so the correct public key could be injected during launch.

The troubleshooting process reinforced the distinction between:

```text
Private SSH key
= proves the client's identity

SSH host fingerprint
= proves the server's identity
```

---

### CloudWatch Configuration Path Variable

The original script defined:

```bash
CW_AGENT_DEB
```

for the package path but did not initially define a reusable variable for the CloudWatch configuration path.

The automation was improved by adding:

```bash
CW_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json"
```

This made the source configuration path explicit and reusable.

---

### Configuration Validation

As the CloudWatch configuration evolved, configuration correctness was validated using tools such as:

```bash
bash -n user-data.sh
```

and:

```bash
python3 -m json.tool
```

These checks became useful safeguards before triggering another Terraform-managed EC2 replacement.

---

## Reproducibility Validation

The disposable Terraform homelab was completely destroyed and later recreated.

No CloudWatch Agent configuration was performed manually after the rebuild.

The rebuilt environment automatically restored:

```text
IAM role                             ✓
IAM instance profile                 ✓
CloudWatch Agent installation        ✓
CloudWatch Agent configuration       ✓
CloudWatch Agent service             ✓
Memory telemetry                     ✓
Disk telemetry                       ✓
Inode telemetry                      ✓
Swap telemetry                       ✓
Custom Homelab/EC2 namespace         ✓
```

Terraform also returned:

```text
No changes. Your infrastructure matches the configuration.
```

after final validation.

This demonstrated that observability had become part of the reproducible infrastructure rather than a manually configured property of one EC2 instance.

---

## Key Concepts Learned

```text
Amazon CloudWatch
CloudWatch Agent
AWS-native metrics
Guest operating system metrics
Custom metric namespaces
Metric dimensions
IAM roles
IAM trust policies
EC2 instance profiles
Temporary workload credentials
EC2 Instance Metadata Service
Cloud-init
Terraform module interfaces
Terraform dependency relationships
Bootstrap automation
Heredocs
JSON validation
Infrastructure reproducibility
```

---

## Interview-Ready Explanation

> I extended my Terraform-managed AWS homelab with host-level observability using the Amazon CloudWatch Agent. I created an IAM role and EC2 instance profile so the workload could publish telemetry using temporary AWS credentials instead of stored access keys. I configured memory, disk, inode, and swap metrics under a custom CloudWatch namespace and automated the entire agent installation and configuration through EC2 user data. I then destroyed and recreated the environment and verified that host monitoring returned automatically without manual configuration.

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Implemented automated host-level observability for a Terraform-managed AWS EC2 environment using the Amazon CloudWatch Agent. Created IAM workload identity through an EC2 instance profile, collected memory, disk, inode, and swap telemetry under a custom CloudWatch namespace, and automated agent deployment through cloud-init. Validated complete observability recovery after a fresh infrastructure rebuild without storing long-lived AWS credentials on the server.

---

# Result

The AWS homelab now automatically provisions host-level monitoring alongside the EC2 workload.

The progression is:

```text
Infrastructure provisioned
        |
        v
Workload identity attached
        |
        v
CloudWatch Agent installed
        |
        v
Host telemetry collected
        |
        v
Metrics centralized in CloudWatch
```

Host-level observability is now part of the Infrastructure as Code deployment rather than a manual post-deployment task.
