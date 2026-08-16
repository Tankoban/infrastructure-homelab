# Terraform Foundations & Infrastructure as Code

**Lab Date:** August 2026
**Status:** Complete

## Objective

Recreate and automate the AWS infrastructure previously built manually by defining the environment with Terraform.

The lab focused on translating existing AWS networking, security, compute, and application deployment knowledge into Infrastructure as Code while learning Terraform's resource lifecycle, state management, dependency handling, variables, outputs, data sources, change planning, automated EC2 bootstrapping, and infrastructure reproducibility.

The final environment demonstrated that the complete Terraform-managed AWS stack could be destroyed and recreated from code while automatically restoring the containerized web application.

---

# Environment

## Local Administration Workstation

- Linux Mint Cinnamon
- Terraform
- AWS CLI v2
- OpenSSH
- Git
- curl

## AWS

**Region:** `us-east-2` — Ohio

## Terraform Project

```text
terraform/aws/homelab/
├── main.tf
├── outputs.tf
├── variables.tf
├── versions.tf
├── user-data.sh
└── terraform.tfvars
```

Local Terraform state and environment-specific variable files were excluded from Git where appropriate.

## Terraform-Managed Infrastructure

| Resource | Configuration |
|---|---|
| VPC | `tf-homelab-vpc` |
| VPC CIDR | `10.20.0.0/16` |
| Public Subnet | `10.20.10.0/24` |
| Private Subnet | `10.20.20.0/24` |
| Internet Gateway | Terraform managed |
| Public Route Table | Terraform managed |
| Security Group | `tf-homelab-web-sg` |
| EC2 | Ubuntu Server |
| Instance Type | `t3.micro` |
| Root Storage | 8 GB `gp3` |
| Application Runtime | Docker |
| Application Orchestration | Docker Compose |
| Reverse Proxy | Nginx |

---

# Architecture

```text
                     Terraform
                         |
            +------------+------------+
            |                         |
            v                         v
      AWS Provider                AMI Data Source
            |                         |
            +------------+------------+
                         |
                         v
                  tf-homelab-vpc
                    10.20.0.0/16
                         |
              +----------+----------+
              |                     |
              v                     v
       Public Subnet          Private Subnet
       10.20.10.0/24          10.20.20.0/24
              |
              v
       Public Route Table
              |
              v
       Internet Gateway
              |
              v
           Internet

              |
              v
       Security Group
       HTTP: Internet
       SSH: Admin /32
              |
              v
          Ubuntu EC2
              |
              v
           cloud-init
              |
              v
       user-data.sh
              |
              v
        Docker Engine
              |
              v
       Docker Compose
              |
       +------+------+
       |             |
       v             |
 Nginx Reverse       |
     Proxy           |
    /     \          |
   v       v         |
 App1     App2       |
```

---

# Part 1 — Terraform Project Structure

A dedicated Terraform project was created under:

```text
terraform/aws/homelab/
```

The configuration was separated into several files.

```text
versions.tf
```

defines Terraform and provider requirements.

```text
main.tf
```

defines infrastructure resources and data sources.

```text
variables.tf
```

defines configurable input values.

```text
outputs.tf
```

defines useful infrastructure information returned by Terraform.

```text
user-data.sh
```

contains EC2 bootstrap automation.

```text
terraform.tfvars
```

contains local environment-specific variable values and is not intended for source control.

### Meaning

Terraform automatically evaluates `.tf` files in the working directory as a single configuration.

Separating configuration by purpose improves readability and maintainability without changing how Terraform evaluates the configuration.

---

# Part 2 — Terraform & AWS Provider

Terraform was configured to use the HashiCorp AWS provider.

Example:

```hcl
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "lab-admin"
}
```

The provider reused the existing authenticated AWS CLI profile rather than embedding AWS credentials in Terraform configuration.

### Meaning

The provider acts as the interface between Terraform and AWS APIs.

```text
Terraform Configuration
        |
        v
AWS Provider
        |
        v
AWS APIs
        |
        v
AWS Resources
```

Authentication information was kept outside the Terraform source code.

---

# Part 3 — Terraform Initialization

The project was initialized with:

```bash
terraform init
```

This prepared the working directory and downloaded the required AWS provider.

Configuration formatting and validation were performed with:

```bash
terraform fmt
terraform validate
```

### Meaning

The basic Terraform workflow became:

```text
Write
  |
  v
Format
  |
  v
Validate
  |
  v
Plan
  |
  v
Apply
  |
  v
Verify
```

Validation occurs before infrastructure deployment whenever possible.

---

# Part 4 — Terraform-Managed VPC

The first AWS resource created through Terraform was a custom VPC.

```hcl
resource "aws_vpc" "homelab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "tf-homelab-vpc"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
```

The Terraform VPC intentionally used:

```text
10.20.0.0/16
```

rather than the manually created Lab 08 network:

```text
10.10.0.0/16
```

### Meaning

Keeping the Terraform environment in a separate address range allowed both environments to coexist while clearly distinguishing:

```text
10.10.0.0/16
Manual AWS environment

10.20.0.0/16
Terraform-managed environment
```

This prevented ambiguity over which infrastructure Terraform owned.

---

# Part 5 — Terraform Plan

Before deployment, the proposed infrastructure change was inspected with:

```bash
terraform plan
```

The initial VPC plan reported one resource to be created.

Terraform plan allowed the desired configuration to be compared against Terraform's current understanding of the infrastructure before making changes.

### Meaning

Terraform separates infrastructure review from infrastructure modification.

```text
Configuration
      |
      v
terraform plan
      |
      v
Proposed Changes
      |
      v
Human Review
      |
      v
terraform apply
```

This provides an opportunity to detect unexpected resource creation, modification, replacement, or destruction before AWS is changed.

---

# Part 6 — Terraform Apply

The VPC was deployed using:

```bash
terraform apply
```

After reviewing the proposed changes, the operation was approved.

The resulting AWS resource was verified both through Terraform and AWS tooling.

### Meaning

`terraform apply` reconciles the desired Terraform configuration with the infrastructure Terraform manages.

The configuration becomes an executable definition of the intended environment rather than documentation describing how to manually build it.

---

# Part 7 — Public & Private Subnets

Two subnets were added.

## Public Subnet

```text
10.20.10.0/24
```

The public subnet was configured to assign public IPv4 addresses to launched instances.

## Private Subnet

```text
10.20.20.0/24
```

The private subnet did not automatically assign public IPv4 addresses.

Terraform references were used rather than hardcoded AWS VPC IDs.

Example:

```hcl
vpc_id = aws_vpc.homelab.id
```

### Meaning

Terraform resource references create relationships between resources.

Instead of:

```text
Use VPC ID vpc-xxxxxxxx
```

the configuration expresses:

```text
Use the ID belonging to aws_vpc.homelab
```

This allows Terraform to construct a dependency graph and determine the correct resource creation order.

---

# Part 8 — Internet Gateway & Routing

An Internet Gateway was attached to the Terraform-managed VPC.

A public route table was created with a default route:

```text
0.0.0.0/0
    |
    v
Internet Gateway
```

The public subnet was explicitly associated with the public route table.

The resulting network path became:

```text
Public Subnet
     |
     v
Public Route Table
     |
     v
Internet Gateway
     |
     v
Internet
```

The private subnet did not receive the same Internet Gateway route.

### Meaning

The Terraform configuration reproduced the same networking concepts previously implemented manually.

Infrastructure as Code changed the method of deployment, not the underlying networking principles.

---

# Part 9 — Security Group as Code

A Terraform-managed security group was created for the web server.

HTTP access was allowed from:

```text
0.0.0.0/0
```

SSH access was restricted to the administrator's current public IPv4 address using a `/32` CIDR.

Instead of hardcoding that address in `main.tf`, a Terraform variable was created:

```hcl
variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH into the lab EC2 instance"
  type        = string
}
```

The security group referenced:

```hcl
cidr_blocks = [var.admin_cidr]
```

The actual value was stored locally in:

```text
terraform.tfvars
```

### Meaning

Variables separate reusable infrastructure logic from environment-specific configuration.

```text
Reusable Terraform
        |
        v
var.admin_cidr
        |
        v
Local Variable Value
        |
        v
Environment-Specific Security Rule
```

This avoids embedding personal network information directly into reusable source code.

---

# Part 10 — Terraform Outputs

Terraform outputs were created for useful resource attributes, including:

- VPC ID
- Public subnet ID
- Private subnet ID
- Security group ID
- EC2 instance ID
- EC2 public IPv4
- EC2 private IPv4
- App1 URL
- App2 URL

Outputs could be inspected with:

```bash
terraform output
```

Individual values could be retrieved programmatically:

```bash
terraform output -raw instance_public_ip
```

### Meaning

Outputs expose useful information generated by infrastructure creation.

They can be consumed by:

- Administrators
- Shell commands
- Automation scripts
- Other Terraform configurations
- CI/CD workflows

This avoids manually locating generated AWS resource identifiers.

---

# Part 11 — Dynamic AMI Lookup

Rather than hardcoding a specific Ubuntu AMI ID, Terraform used an AWS AMI data source.

Conceptually:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  ...
}
```

The EC2 resource then referenced:

```hcl
ami = data.aws_ami.ubuntu.id
```

### Meaning

A Terraform resource manages infrastructure.

```hcl
resource
```

means:

```text
Create or manage this.
```

A Terraform data source retrieves information.

```hcl
data
```

means:

```text
Look this up.
```

Using a data source reduced dependence on a manually copied AMI identifier.

---

# Part 12 — Terraform-Managed EC2

Terraform created an Ubuntu EC2 instance in the public subnet.

The instance referenced other Terraform-managed infrastructure:

```hcl
subnet_id              = aws_subnet.public_1.id
vpc_security_group_ids = [aws_security_group.web.id]
```

The existing AWS SSH key pair was referenced by name.

The private SSH key remained stored only on the local administration workstation.

The root EBS volume used:

```text
gp3
8 GB
```

### Meaning

Terraform connected multiple resources through references rather than manually copying generated AWS IDs between configuration steps.

The resulting dependency relationship resembled:

```text
VPC
 |
 +--> Subnet
 |
 +--> Security Group
       |
       v
      EC2
```

---

# Part 13 — EC2 Bootstrapping with User Data

The EC2 instance used:

```hcl
user_data = file("${path.module}/user-data.sh")
```

The startup script automatically:

1. Updated package information.
2. Installed Docker Engine.
3. Installed Docker Compose v2.
4. Enabled Docker at boot.
5. Created the application directories.
6. Created App1.
7. Created App2.
8. Created the Nginx configuration.
9. Created the Docker Compose configuration.
10. Started the application stack.

### Meaning

The previous manual workflow:

```text
Create EC2
   |
SSH
   |
Install Docker
   |
Create files
   |
Configure Nginx
   |
Run Compose
```

became:

```text
terraform apply
      |
      v
Create EC2
      |
      v
cloud-init
      |
      v
user-data.sh
      |
      v
Application Running
```

This represented the first automated configuration/bootstrap stage of the homelab.

---

# Part 14 — Automated Docker Application Stack

The bootstrap process deployed three containers:

```text
tf-aws-reverse-proxy
tf-aws-app1
tf-aws-app2
```

Only the reverse proxy exposed TCP port 80 on the EC2 host.

The application containers communicated over the internal Docker network.

Nginx provided path-based routing:

```text
/app1/
   |
   v
App1

/app2/
   |
   v
App2
```

The deployment reused the Docker and Nginx concepts developed during earlier local homelab labs.

---

# Part 15 — Automated Deployment Validation

After Terraform created the EC2 instance, the application was tested using Terraform-generated outputs.

```bash
curl "$(terraform output -raw app1_url)"
```

and:

```bash
curl "$(terraform output -raw app2_url)"
```

Both applications successfully returned their expected HTML.

### Meaning

The validation tested more than EC2 creation.

A successful response demonstrated that the complete chain was functioning:

```text
Terraform
    |
    v
AWS Networking
    |
    v
Security Group
    |
    v
EC2
    |
    v
cloud-init
    |
    v
Docker
    |
    v
Docker Compose
    |
    v
Nginx
    |
    v
Backend Application
```

---

# Part 16 — Cloud-Init Troubleshooting Model

Because application configuration was now automated, troubleshooting also changed.

The following commands were identified for bootstrap troubleshooting:

```bash
sudo cloud-init status
```

```bash
sudo tail -100 /var/log/cloud-init-output.log
```

Docker could then be inspected using:

```bash
docker ps
```

and:

```bash
sudo systemctl status docker --no-pager
```

### Meaning

When automation replaces interactive configuration, logs become essential for understanding what happened during unattended execution.

The troubleshooting model became:

```text
Did Terraform create EC2?
        |
        v
Did EC2 boot?
        |
        v
Did cloud-init complete?
        |
        v
Did user_data execute?
        |
        v
Did Docker install?
        |
        v
Did Compose start?
        |
        v
Is Nginx listening?
        |
        v
Is AWS allowing traffic?
```

---

# Part 17 — EC2 Stop/Start & Terraform State

The Terraform-managed EC2 instance was stopped and later restarted outside Terraform.

AWS assigned the instance a new automatically generated public IPv4 address.

Terraform subsequently detected:

```text
Objects have changed outside of Terraform
```

The public IPv4 changed from the previously recorded value to the new AWS-assigned address.

Terraform also identified dependent output changes for:

- `instance_public_ip`
- `app1_url`
- `app2_url`

### Problem Encountered

Immediately after `terraform plan`, running:

```bash
terraform output -raw instance_public_ip
```

still returned the previous public IPv4 address.

Consequently:

```bash
curl "$(terraform output -raw app1_url)"
```

attempted to contact the old address and failed.

### Resolution

`terraform apply` was executed.

Terraform reported that no AWS infrastructure needed to be created, modified, or destroyed; the operation saved the refreshed output information into Terraform state.

Afterward:

```bash
terraform output
```

returned the current AWS-assigned public IPv4 and application URLs.

### Meaning

This demonstrated an important distinction between:

```text
Terraform Configuration
Terraform State
Actual AWS Infrastructure
```

Terraform detected that a computed AWS attribute had changed outside the normal apply workflow.

The public IP was not a desired fixed value in the Terraform configuration, so Terraform did not attempt to restore the old address.

Instead, Terraform updated its understanding of the AWS-generated attribute and the outputs dependent on it.

---

# Part 18 — Intentional Infrastructure Modification

An additional EC2 tag was added:

```hcl
Purpose = "IaC-Learning"
```

Before applying the change:

```bash
terraform plan
```

showed that the EC2 instance could be modified in place.

Conceptually:

```text
Plan: 0 to add, 1 to change, 0 to destroy
```

Terraform did not require the instance to be recreated.

### Terraform Plan Symbols

Common Terraform plan indicators encountered or discussed included:

```text
+     Create
~     Modify in place
-     Destroy
-/+   Destroy and recreate
+/-   Create replacement, then destroy previous resource
```

### Meaning

Not every configuration modification requires infrastructure replacement.

Reading a Terraform plan allows an engineer to understand the operational impact of a proposed change before approving it.

---

# Part 19 — Desired State Reconciliation

After the tag modification was applied, another:

```bash
terraform plan
```

confirmed that the deployed infrastructure matched the configuration.

The lifecycle demonstrated:

```text
Desired State
     |
     v
terraform plan
     |
     v
Difference Detected
     |
     v
terraform apply
     |
     v
AWS Modified
     |
     v
terraform plan
     |
     v
No Changes
```

### Meaning

Terraform is declarative.

The configuration primarily describes:

```text
what should exist
```

rather than a sequence of manual instructions describing:

```text
how an administrator should click through AWS to create it
```

Terraform determines the operations required to move managed infrastructure toward the declared state.

---

# Part 20 — Terraform Destroy

After validating the environment, the complete Terraform-managed infrastructure stack was deliberately destroyed using:

```bash
terraform destroy
```

The destruction plan was reviewed before approval.

Terraform removed the resources it managed while leaving the separately created manual Lab 08 AWS environment intact.

### Meaning

Terraform manages resource lifecycle as well as resource creation.

Infrastructure as Code therefore supports:

```text
CREATE
READ
CHANGE
DESTROY
RECREATE
```

This is especially useful for temporary lab, development, testing, and ephemeral environments where resources should not continue generating unnecessary cloud usage.

---

# Part 21 — Full Infrastructure Rebuild

After the Terraform environment was destroyed, it was recreated using:

```bash
terraform apply
```

Terraform reconstructed the environment from code.

The rebuilt environment included:

```text
VPC
 |
 +-- Public Subnet
 |
 +-- Private Subnet
 |
 +-- Internet Gateway
 |
 +-- Public Route Table
 |
 +-- Route Table Association
 |
 +-- Security Group
 |
 +-- EC2
       |
       v
   cloud-init
       |
       v
   user-data.sh
       |
       v
   Docker
       |
       v
   Docker Compose
       |
       +-- Nginx
       +-- App1
       +-- App2
```

Both applications successfully returned after the rebuild.

### Meaning

This demonstrated **reproducibility**.

The original server itself was no longer the critical artifact.

The infrastructure definition and bootstrap configuration were sufficient to reconstruct the working environment.

The operational mindset shifted from:

```text
The server is precious.
```

toward:

```text
The configuration is precious.
The server can be recreated.
```

---

# Part 22 — Client-Specific Browser Connectivity

During application validation, the primary workstation's web browser timed out when attempting to access the public application URLs.

However:

```bash
curl "$(terraform output -raw app1_url)"
```

returned:

```text
HTTP/1.1 200 OK
```

and both App1 and App2 loaded successfully from a separate physical device.

### Troubleshooting Evidence

```text
Terraform deployment       PASS
EC2                         PASS
Security Group HTTP        PASS
Docker                     PASS
Nginx                      PASS
App1                       PASS
App2                       PASS
curl from workstation      PASS
Separate client/browser    PASS
Primary workstation browser FAIL
```

### Conclusion

The evidence isolated the remaining problem to the primary client/browser environment rather than the Terraform or AWS infrastructure.

Further browser-specific troubleshooting was intentionally deferred because the infrastructure learning objectives had been successfully validated.

### Lesson Learned

Effective troubleshooting does not always require immediately solving every discovered problem.

Once a failure domain has been sufficiently isolated, an unrelated client-specific issue can be documented and deferred without blocking validated infrastructure work.

---

# Key Concepts Learned

## Terraform

- Infrastructure as Code
- Declarative configuration
- Terraform providers
- Resources
- Data sources
- Variables
- `.tfvars`
- Outputs
- Resource references
- Dependency graphs
- Terraform state
- State refresh
- Desired state
- `terraform init`
- `terraform fmt`
- `terraform validate`
- `terraform plan`
- `terraform apply`
- `terraform output`
- `terraform state`
- `terraform destroy`

## AWS

- Terraform-managed VPCs
- Public and private subnets
- Internet Gateways
- Route tables
- Route table associations
- Security groups
- EC2
- AMI discovery
- EBS
- Public/private IPv4 addressing
- SSH administration

## Automation

- EC2 user data
- cloud-init
- Automated package installation
- Docker bootstrap
- Docker Compose bootstrap
- Automated Nginx configuration
- Application initialization
- Reproducible infrastructure

## Operations

- Infrastructure lifecycle management
- Change planning
- In-place resource modification
- Out-of-band infrastructure changes
- State synchronization
- Automated recovery/recreation
- Layered troubleshooting
- Cost-aware teardown

---

# Problems Encountered

## Docker Compose Availability

The EC2 operating system provided Docker Engine and Docker Compose as separate packages.

The correct Ubuntu package was:

```text
docker-compose-v2
```

This package selection was incorporated into the automated bootstrap script.

---

## Public IPv4 Changed After EC2 Restart

Stopping and starting the EC2 instance resulted in a new automatically assigned public IPv4 address.

Terraform detected the change during its next refresh/plan.

The previously stored Terraform output still referenced the old address until state was updated.

### Resolution

Terraform state/output information was refreshed through the normal apply workflow.

---

## Browser Could Not Load Application

The primary workstation browser timed out when accessing the application.

The infrastructure was validated independently through:

- HTTP 200 response using `curl`
- Successful access from another physical device

### Resolution

The infrastructure was considered operational.

The client-specific browser issue was isolated and deferred for separate troubleshooting.

---

# Security Considerations

The Terraform configuration incorporated several security practices:

- AWS authentication remained outside Terraform source code.
- No AWS access keys were embedded in `.tf` files.
- Existing AWS CLI authentication was reused.
- SSH access was restricted to an administrator `/32`.
- The administrator address was supplied through a variable rather than hardcoded in reusable configuration.
- Environment-specific `.tfvars` data was excluded from Git.
- Terraform state was excluded from Git.
- Backend application containers were not directly exposed to the Internet.
- Only the Nginx reverse proxy published the web service.
- Existing private SSH key material remained outside the Terraform project.
- Infrastructure ownership was clearly identified with Terraform tags.
- The Terraform network used a separate CIDR range from manually managed infrastructure.

---

# Lessons Learned

1. Infrastructure as Code is most useful when the underlying infrastructure concepts are already understood.

2. Terraform resources describe infrastructure that should be created or managed.

3. Terraform data sources retrieve information about existing or externally maintained resources.

4. Resource references eliminate the need to manually copy generated AWS identifiers between configuration steps.

5. Terraform builds dependency relationships from references between resources.

6. Variables separate reusable infrastructure definitions from environment-specific values.

7. Outputs make generated infrastructure attributes easily available to administrators and automation.

8. `terraform plan` should be reviewed before infrastructure changes are applied.

9. Plan symbols communicate whether Terraform intends to create, modify, destroy, or replace resources.

10. Terraform state represents Terraform's recorded understanding of managed infrastructure.

11. Actual cloud infrastructure can change outside Terraform, requiring Terraform to refresh its understanding of resource attributes.

12. Computed AWS properties such as automatically assigned public IP addresses can change without representing a violation of desired configuration.

13. EC2 user data and cloud-init can bootstrap software automatically during instance creation.

14. Automated deployments require log-based troubleshooting rather than relying solely on interactive installation feedback.

15. Infrastructure can be treated as replaceable when its configuration and deployment process are reproducible.

16. `terraform destroy` is an important lifecycle and cloud-cost-management capability, not merely a cleanup command.

17. A successful destroy/rebuild cycle provides stronger evidence of reproducibility than a single successful deployment.

18. Infrastructure troubleshooting should separate cloud, operating-system, container, application, and client layers.

19. Not every isolated problem must block progress on unrelated validated objectives.

20. Source-controlled configuration becomes more valuable than manually maintained individual servers as automation increases.

---

# Manual AWS vs Terraform

| Manual Lab 08 | Terraform Lab 09 |
|---|---|
| Create VPC in console | `aws_vpc` resource |
| Create subnets manually | `aws_subnet` resources |
| Create IGW manually | `aws_internet_gateway` |
| Configure routes manually | `aws_route_table` |
| Associate subnet manually | `aws_route_table_association` |
| Configure SG manually | `aws_security_group` |
| Select AMI manually | `aws_ami` data source |
| Launch EC2 manually | `aws_instance` |
| Enter IP-specific configuration | Terraform variable |
| Find resource IDs manually | Terraform outputs |
| SSH into new server | Automated user data |
| Install Docker manually | Bootstrap script |
| Configure application manually | Bootstrap script |
| Start Compose manually | Bootstrap script |
| Delete resources manually | `terraform destroy` |
| Rebuild manually | `terraform apply` |

---

# Real-World Application

The skills demonstrated in this lab map directly to responsibilities found in:

- Cloud Engineering
- DevOps Engineering
- Platform Engineering
- Infrastructure Engineering
- Site Reliability Engineering
- Cloud Security Engineering
- Systems Engineering

The completed environment demonstrates the ability to:

- Define AWS infrastructure using Terraform
- Configure Terraform providers
- Use variables and outputs
- Query AWS resources using data sources
- Build resource dependency relationships
- Manage Terraform state
- Interpret Terraform plans
- Deploy VPC networking as code
- Define cloud firewall rules as code
- Deploy EC2 using Terraform
- Bootstrap Linux servers automatically
- Deploy Docker workloads automatically
- Detect externally changed infrastructure attributes
- Reconcile Terraform state
- Modify infrastructure safely
- Destroy temporary infrastructure
- Rebuild an environment from source-controlled configuration
- Validate application availability after complete infrastructure recreation

---

# Result

The final test demonstrated:

```text
Working Infrastructure
        |
        v
terraform destroy
        |
        v
Terraform Environment Removed
        |
        v
terraform apply
        |
        v
Network Recreated
        |
        v
EC2 Recreated
        |
        v
cloud-init Executed
        |
        v
Docker Installed
        |
        v
Application Stack Started
        |
        v
App1 PASS
App2 PASS
```

The Terraform configuration therefore demonstrated functional infrastructure reproducibility rather than only initial resource provisioning.

---

# Next Steps

Future infrastructure automation work can build upon this foundation through:

- Terraform configuration modularization
- Remote Terraform state
- State locking
- Additional input validation
- Multiple environments
- CI/CD validation
- Automated security scanning
- Application deployment pipelines
- Cloud monitoring
- Centralized logging
- HTTPS and public DNS
- IAM roles for EC2
- Private workload deployment
- Higher-availability architecture

The progression has moved from:

```text
Manual Local Infrastructure
        |
        v
Manual AWS Infrastructure
        |
        v
Terraform AWS Infrastructure
        |
        v
Automated Application Bootstrap
        |
        v
Reproducible Cloud Environment
```
