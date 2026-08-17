# Lab 12 — Terraform Remote State & Locking

## Overview

In this lab, the Terraform AWS homelab was migrated from local-only state storage to a protected remote S3 backend.

The goal was to improve the reliability, recoverability, and safety of Terraform state management while preserving the existing live infrastructure.

This lab introduced a dedicated remote-state bootstrap configuration, S3-based state storage, bucket versioning, server-side encryption, public-access blocking, native S3 lockfiles, and state migration using `terraform init -migrate-state`.

The migration was completed successfully with:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that Terraform moved its state-management backend without recreating, destroying, or modifying the existing AWS infrastructure.

---

## Objectives

The objectives of this lab were to:

- Understand why Terraform state is important
- Understand why Terraform state must be protected
- Identify the limitations of local-only state
- Build a separate remote-state bootstrap configuration
- Create a dedicated S3 bucket for Terraform state
- Enable S3 bucket versioning
- Enable server-side encryption
- Block public access to the state bucket
- Prevent accidental Terraform destruction of the state bucket
- Configure the homelab to use an S3 backend
- Migrate existing live state from local storage to S3
- Validate that infrastructure remained unchanged after migration
- Enable native S3 state locking
- Test concurrent Terraform-operation protection
- Observe the `.tflock` object during an active Terraform lock
- Verify remote state version history
- Preserve the state backend independently from disposable homelab infrastructure

---

# Starting State Architecture

Before this lab, the homelab Terraform configuration stored its state locally.

Conceptually:

```text
Terraform CLI
    │
    ▼
terraform/aws/homelab/
    │
    └── terraform.tfstate
```

The state file existed only on the workstation running Terraform.

This worked for a learning environment, but it introduced several limitations.

---

# Why Terraform State Matters

Terraform state is the record Terraform uses to associate configuration with real infrastructure.

For example, the configuration may contain:

```hcl
resource "aws_instance" "web" {
  ...
}
```

Terraform state records which actual EC2 instance corresponds to:

```text
aws_instance.web
```

or, after the Lab 11 modular refactor:

```text
module.compute.aws_instance.web
```

Terraform uses state to determine:

- What infrastructure already exists
- Which resources belong to the configuration
- Current resource attributes
- Dependency relationships
- What must be created
- What must be changed
- What must be destroyed

Without accurate state, Terraform cannot reliably manage existing infrastructure.

---

# Why Terraform State Is Sensitive

Terraform state can contain infrastructure information that should not be exposed casually.

Depending on the resources being managed, state may contain:

- Public IP addresses
- Private IP addresses
- Resource IDs
- ARNs
- Network topology
- User data
- Configuration values
- Generated credentials
- Secrets or sensitive resource attributes
- Database connection details
- Infrastructure relationships

Even when a current project does not intentionally store credentials in state, state should still be treated as sensitive infrastructure data.

This is one reason Terraform state files are excluded from Git.

The repository `.gitignore` protects:

```text
*.tfstate
*.tfstate.*
*.tfvars
.terraform/
```

---

# Problems With Local-Only State

Before this lab:

```text
terraform.tfstate
```

existed only on the local workstation.

This creates several risks.

## Workstation Failure

If the workstation or disk were lost or damaged, the state file could be lost.

The AWS infrastructure might continue running, but Terraform would no longer have its original resource mapping.

---

## Limited Recovery

A local state file does not automatically provide historical state versions.

If the state file is accidentally overwritten or corrupted, recovery options may be limited.

---

## Poor Team Collaboration

If multiple administrators or engineers need to manage the same Terraform environment, local state becomes difficult to coordinate.

Each person having their own copy of the state creates a risk of conflicting or stale infrastructure knowledge.

---

## Concurrent Operations

Without appropriate locking, multiple Terraform operations could potentially attempt to modify the same infrastructure state at the same time.

This can create race conditions or state corruption.

---

# Target Architecture

The new architecture stores the homelab state in Amazon S3.

```text
Terraform CLI
      │
      │ AWS authenticated request
      ▼
Amazon S3
sugoi-terraform-state-2026
      │
      └── homelab/
          └── terraform.tfstate
```

The backend includes:

```text
Versioning
Encryption
Block Public Access
S3-native state locking
```

During an active lock, Terraform temporarily creates:

```text
homelab/terraform.tfstate.tflock
```

---

# Backend Bootstrap Problem

A Terraform backend creates a dependency problem.

Terraform cannot store its state in an S3 bucket that does not yet exist.

In other words:

```text
Terraform needs S3 bucket
        ↑
        │
Terraform is supposed to create S3 bucket
```

This is a bootstrap problem.

To solve it, a separate Terraform configuration was created specifically for the remote-state foundation.

---

# Bootstrap Architecture

The Terraform repository now contains:

```text
terraform/aws/
├── bootstrap/
│   └── remote-state/
│       ├── main.tf
│       ├── outputs.tf
│       ├── variables.tf
│       └── versions.tf
│
├── homelab/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── user-data.sh
│
└── modules/
    ├── compute/
    ├── networking/
    └── security/
```

The bootstrap configuration manages the remote-state storage foundation.

The homelab configuration then consumes that remote backend.

---

# Bootstrap Provider Configuration

The bootstrap configuration uses the AWS provider in:

```text
us-east-2
```

and authenticates using the existing:

```text
lab-admin
```

AWS CLI profile.

Conceptually:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = "lab-admin"
}
```

This preserves the existing temporary AWS CLI authentication workflow rather than introducing long-lived IAM access keys.

---

# Remote-State Bucket

The state bucket created in this lab is:

```text
sugoi-terraform-state-2026
```

Because S3 bucket names must be globally unique, the bucket name is supplied through an ignored:

```text
terraform.tfvars
```

file.

The file is excluded from Git by the repository's existing:

```text
*.tfvars
```

ignore rule.

---

# Remote-State Bootstrap Resources

The bootstrap configuration created four Terraform-managed resources.

The plan showed:

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

The resources were:

```text
S3 bucket
S3 bucket versioning configuration
S3 server-side encryption configuration
S3 public-access block
```

---

# S3 Bucket Configuration

The primary bucket resource uses:

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-remote-state"
    Environment = "Lab"
    ManagedBy   = "Terraform"
    Purpose     = "Terraform-State"
  }
}
```

---

# Prevent Destroy

The bucket includes:

```hcl
lifecycle {
  prevent_destroy = true
}
```

This provides a Terraform-level safeguard against accidentally destroying the state bucket.

If a Terraform operation attempts to destroy this resource, Terraform should refuse unless the lifecycle protection is deliberately removed.

This is important because deleting the state bucket could remove Terraform's ability to safely manage the homelab.

It is important to understand that this is a Terraform safeguard.

It is not an AWS-level immutable lock.

A sufficiently privileged AWS administrator could still alter or delete resources outside Terraform.

---

# S3 Versioning

Bucket versioning was enabled.

Conceptually:

```hcl
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

Versioning provides historical copies of the Terraform state object.

Instead of having only:

```text
terraform.tfstate
```

S3 can retain previous versions of that object.

This improves recovery options if state is:

- Accidentally overwritten
- Incorrectly modified
- Corrupted
- Replaced during a problematic operation

Version history was verified using the AWS CLI.

---

# Server-Side Encryption

The state bucket uses server-side encryption.

The bootstrap configuration specifies:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

This uses:

```text
SSE-S3
AES-256
```

for encryption at rest.

The encryption configuration was verified using the AWS CLI.

---

# Block Public Access

Terraform state should never be intentionally public.

The state bucket uses:

```hcl
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

The AWS CLI verification confirmed all four protections were enabled.

Conceptually:

```text
BlockPublicAcls        = true
IgnorePublicAcls       = true
BlockPublicPolicy      = true
RestrictPublicBuckets  = true
```

---

# Bootstrap Outputs

The bootstrap configuration exposes:

```text
state_bucket_name
state_bucket_arn
```

The resulting bucket was:

```text
state_bucket_name = "sugoi-terraform-state-2026"
```

with an ARN similar to:

```text
arn:aws:s3:::sugoi-terraform-state-2026
```

---

# Bootstrap State

The bootstrap configuration initially retains its own local Terraform state.

Conceptually:

```text
bootstrap/remote-state/
└── terraform.tfstate
```

This is intentional.

The bootstrap configuration must exist before the remote backend can be used by the main homelab.

The resulting architecture is:

```text
Local Bootstrap State
        │
        ▼
Creates S3 State Foundation
        │
        ▼
Homelab Uses Remote S3 State
```

This solves the backend chicken-and-egg problem.

---

# Homelab Backend Configuration

A new file was added to the homelab root module:

```text
terraform/aws/homelab/backend.tf
```

The backend configuration uses:

```hcl
terraform {
  backend "s3" {
    bucket       = "sugoi-terraform-state-2026"
    key          = "homelab/terraform.tfstate"
    region       = "us-east-2"
    profile      = "lab-admin"
    encrypt      = true
    use_lockfile = true
  }
}
```

---

# Backend Configuration Meaning

## Bucket

```hcl
bucket = "sugoi-terraform-state-2026"
```

Specifies which S3 bucket stores the Terraform state.

---

## Key

```hcl
key = "homelab/terraform.tfstate"
```

Defines the object path inside the S3 bucket.

Conceptually:

```text
sugoi-terraform-state-2026/
└── homelab/
    └── terraform.tfstate
```

---

## Region

```hcl
region = "us-east-2"
```

Specifies the AWS region containing the state bucket.

---

## AWS Profile

```hcl
profile = "lab-admin"
```

Uses the existing AWS CLI profile for authentication.

---

## Encryption

```hcl
encrypt = true
```

Configures Terraform to use encrypted S3 state storage.

---

## Native S3 Locking

```hcl
use_lockfile = true
```

Enables S3-native Terraform state locking.

This avoids relying on the older DynamoDB state-locking architecture for this lab.

---

# Local State Backup Before Migration

Before migrating the live homelab state, an additional local backup was created.

Conceptually:

```text
terraform.tfstate.pre-remote-backup
```

This provided another recovery point before changing the backend configuration.

The backup remained excluded from Git.

---

# Backend Reinitialization

After `backend.tf` was added, attempting to use Terraform state immediately returned:

```text
Backend initialization required
```

Terraform correctly detected that the configured backend had changed.

The error explained that Terraform needed to be reinitialized using:

```text
-reconfigure
```

or:

```text
-migrate-state
```

No infrastructure or state changes had been made at this point.

---

# Migrating Local State to S3

The existing live homelab state was migrated using:

```bash
terraform init -migrate-state
```

Terraform detected:

```text
Local Backend
      ↓
S3 Backend
```

and prompted to copy the existing state into the configured S3 backend.

The existing state was copied rather than recreated.

This distinction is critical.

The operation moved:

```text
Terraform's record of the infrastructure
```

not:

```text
the AWS infrastructure itself
```

---

# Migration Validation

After migration, Terraform was able to read the existing modular resource addresses through the remote backend.

The state contained:

```text
module.compute.data.aws_ami.ubuntu
module.compute.aws_instance.web
module.networking.aws_internet_gateway.homelab
module.networking.aws_route_table.public
module.networking.aws_route_table_association.public_1
module.networking.aws_subnet.private_1
module.networking.aws_subnet.public_1
module.networking.aws_vpc.homelab
module.security.aws_security_group.web
```

This confirmed that the same logical resource state remained intact after the backend migration.

---

# No-Change Validation

The most important migration validation was:

```bash
terraform plan
```

Terraform returned:

```text
No changes. Your infrastructure matches the configuration.
```

This proved that:

```text
Existing AWS Infrastructure
        =
Terraform Configuration
        =
Migrated Remote State
```

No AWS resources were:

- Recreated
- Replaced
- Modified
- Destroyed

as a result of moving the state backend.

---

# Verifying the Remote State Object

The AWS CLI was used to inspect the S3 bucket contents.

The remote state object appeared at:

```text
homelab/terraform.tfstate
```

This verified that the migrated Terraform state was physically stored in the configured S3 backend.

---

# Verifying Versioning

S3 bucket versioning was checked through the AWS CLI.

The configuration returned:

```text
Status = Enabled
```

Object-version history was also inspected for:

```text
homelab/terraform.tfstate
```

This demonstrated that state history can be preserved across future Terraform writes.

---

# Verifying Encryption

The bucket encryption configuration was inspected.

The configured algorithm was:

```text
AES256
```

This confirmed that the remote Terraform state is encrypted at rest using SSE-S3.

---

# Verifying Block Public Access

The state bucket public-access configuration was checked and confirmed:

```text
BlockPublicAcls        true
IgnorePublicAcls       true
BlockPublicPolicy      true
RestrictPublicBuckets  true
```

This reduces the risk of accidental public exposure of Terraform state.

---

# Terraform State Locking

State locking prevents multiple Terraform operations from attempting to modify the same state simultaneously.

Without locking, two administrators or automation jobs could theoretically attempt conflicting operations.

Conceptually:

```text
Terraform Process A
        │
        ▼
    State Write

Terraform Process B
        │
        ▼
    State Write
```

If both operations occurred concurrently, they could potentially create unsafe state behavior.

With locking:

```text
Terraform Process A
        │
        ▼
    Acquire Lock
        │
        ├─────────────┐
        │             │
        ▼             ▼
   State Work    Process B Blocked
        │
        ▼
   Release Lock
```

---

# Native S3 Lockfile

The backend configuration uses:

```hcl
use_lockfile = true
```

During a locked Terraform operation, S3 temporarily contains a lock object similar to:

```text
homelab/terraform.tfstate.tflock
```

The lock object exists only while the operation holds the state lock.

---

# State-Locking Test

The first attempt to test state locking used:

```bash
terraform apply
```

However, the infrastructure already matched the configuration.

Terraform returned no changes and completed without waiting for approval.

Because there was no proposed infrastructure change, the lock existed too briefly to perform a useful concurrency test.

---

# Creating a Safe Lock-Test Condition

A temporary Terraform-only configuration change was introduced.

The EC2 tag:

```hcl
Purpose = "IaC-Learning"
```

was temporarily changed to:

```hcl
Purpose = "IaC-Learning-Lock-Test"
```

This produced a plan with an in-place change.

Terraform then stopped at the apply confirmation prompt.

The first terminal was deliberately left waiting without entering:

```text
yes
```

No AWS change was applied.

---

# Concurrent Terraform Test

While Terminal 1 was holding the state lock, a second terminal attempted another Terraform operation.

Conceptually:

```text
Terminal 1
terraform apply
     │
     ├── acquires S3 lock
     │
     └── waits for approval

Terminal 2
terraform plan
     │
     └── blocked by existing state lock
```

The second Terraform process was prevented from proceeding while the first process held the lock.

This proved that remote-state locking was operating correctly.

---

# Lock Object Verification

While Terminal 1 held the lock, the S3 bucket was inspected.

The bucket contained:

```text
homelab/terraform.tfstate
homelab/terraform.tfstate.tflock
```

The `.tflock` object provided visible evidence that Terraform had acquired the S3 state lock.

---

# Lock Release

The first Terraform operation was canceled before approval.

Because:

```text
yes
```

was never entered, the temporary EC2 tag change was not applied to AWS.

After cancellation:

```text
terraform.tfstate.tflock
```

was removed.

The temporary Terraform configuration change was then reverted back to:

```hcl
Purpose = "IaC-Learning"
```

A final Terraform plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that:

- No lock-test infrastructure change remained
- The state lock was released correctly
- The infrastructure still matched the configuration
- The remote backend remained healthy

---

# Final Architecture

The Terraform environment now uses two infrastructure layers.

```text
AWS Account
│
├── Persistent Terraform State Foundation
│   │
│   └── S3 Bucket
│       └── sugoi-terraform-state-2026
│           └── homelab/
│               └── terraform.tfstate
│
└── Disposable Homelab Infrastructure
    │
    ├── VPC
    ├── Public Subnet
    ├── Private Subnet
    ├── Internet Gateway
    ├── Route Table
    ├── Security Group
    └── EC2 Instance
```

The state foundation persists even when the homelab infrastructure is destroyed.

---

# Persistent vs Disposable Infrastructure

A major architecture distinction introduced in this lab is:

```text
Persistent Foundation
vs
Disposable Workload Infrastructure
```

The remote-state bucket should remain available between lab sessions.

The homelab resources can continue to be destroyed when not needed.

For example:

```bash
terraform destroy
```

from:

```text
terraform/aws/homelab/
```

can destroy the disposable AWS environment.

The S3 backend remains.

The resulting remote state simply records that the homelab resources no longer exist.

---

# Problems Encountered

Several useful issues occurred during this lab.

---

## 1. Backend Initialization Required

After adding:

```text
backend.tf
```

Terraform refused to perform normal state operations.

The error stated:

```text
Backend initialization required
```

### Cause

Terraform detected that the backend configuration had changed from local state to S3.

### Resolution

The configuration was reinitialized using:

```bash
terraform init -migrate-state
```

### Lesson

Backend configuration changes require explicit Terraform reinitialization.

Terraform does not silently move state between backends.

---

## 2. State Inspection Before Backend Initialization

After `backend.tf` was added, a:

```bash
terraform state list
```

command was attempted before reinitialization.

Terraform correctly refused.

### Lesson

Once a backend configuration changes, Terraform requires backend initialization before it can safely perform state operations.

---

## 3. No-Change Apply Did Not Hold the Lock Long Enough

The first locking test used:

```bash
terraform apply
```

while there were no planned infrastructure changes.

Terraform completed immediately.

### Cause

There was no apply confirmation step because there was nothing to change.

### Resolution

A temporary EC2 tag change was introduced to create a safe in-place plan.

The apply was left waiting at the confirmation prompt.

### Lesson

Testing concurrency controls may require deliberately creating a safe condition in which the lock remains active long enough to observe.

---

## 4. Temporary Lock-Test Configuration

The temporary configuration changed:

```hcl
Purpose = "IaC-Learning"
```

to:

```hcl
Purpose = "IaC-Learning-Lock-Test"
```

The change was never approved.

It was reverted after the locking test.

A final Terraform plan showed no infrastructure drift.

### Lesson

A controlled temporary configuration change can be useful for safely validating behavior without applying unnecessary infrastructure changes.

---

## 5. Working Directory Mismatch

Several Terraform commands were initially executed from:

```text
terraform/aws/homelab/
```

using paths intended for execution from the repository root.

This produced errors such as:

```text
No file or directory at terraform/aws
```

and:

```text
chdir terraform/aws/homelab: no such file or directory
```

### Cause

The commands assumed the shell was located at:

```text
~/Projects/infrastructure-homelab
```

while the terminal was already inside:

```text
~/Projects/infrastructure-homelab/terraform/aws/homelab
```

### Lesson

Relative paths depend on the current working directory.

Before executing path-heavy commands, verify location using:

```bash
pwd
```

This is especially important when using Terraform's:

```text
-chdir
```

option.

---

# Key Concepts Learned

## Terraform State

Terraform state maps configuration to real infrastructure.

It is a critical part of Terraform's operating model.

---

## Local State

Local state is simple but creates limitations for:

- Collaboration
- Recovery
- Centralization
- Concurrent operations

---

## Remote State

Remote state stores Terraform state in shared infrastructure rather than only on the local workstation.

---

## Terraform Backends

A backend controls where Terraform stores and manages state.

The homelab now uses:

```text
S3 backend
```

---

## Bootstrap Infrastructure

Some infrastructure must exist before other infrastructure-management systems can depend on it.

The S3 state bucket is an example of bootstrap infrastructure.

---

## State Migration

Terraform can migrate existing state between backends.

The command used was:

```bash
terraform init -migrate-state
```

---

## State Locking

Locking prevents concurrent Terraform operations from modifying the same state simultaneously.

---

## Native S3 Lockfiles

Terraform can use an S3 lock object:

```text
terraform.tfstate.tflock
```

to coordinate state access.

---

## S3 Versioning

Versioning provides historical state-object versions and improves recovery options.

---

## Encryption at Rest

Terraform state is protected using S3 server-side encryption.

---

## Block Public Access

Public-access protections reduce the risk that sensitive infrastructure state could be accidentally exposed.

---

## Persistent Infrastructure Foundations

Not all infrastructure should share the same lifecycle.

The state backend remains persistent while the homelab workload remains disposable.

---

# Security Concepts Practiced

This lab reinforced several security concepts.

## Confidentiality

Terraform state is protected from public access and encrypted at rest.

---

## Integrity

State locking helps prevent concurrent operations from creating conflicting state modifications.

---

## Availability

S3 provides a durable remote location for state, reducing dependence on a single workstation.

---

## Recovery

S3 versioning provides previous versions of the state object.

---

## Defense in Depth

Multiple controls protect the state backend:

```text
S3 authentication
+
Block Public Access
+
Encryption
+
Versioning
+
Terraform prevent_destroy
+
State locking
```

---

# Skills Practiced

## Terraform

- Terraform state
- Local state
- Remote state
- S3 backend
- Backend configuration
- Backend initialization
- `terraform init -migrate-state`
- State migration
- State locking
- S3 native lockfiles
- State inspection
- Terraform plans
- Terraform validation
- Backend troubleshooting

---

## AWS

- Amazon S3
- S3 bucket management
- S3 object paths
- Bucket versioning
- Server-side encryption
- Block Public Access
- AWS CLI S3 inspection
- AWS CLI object-version inspection
- IAM-authenticated S3 access

---

## Infrastructure Architecture

- Bootstrap infrastructure
- Persistent vs disposable infrastructure
- Infrastructure lifecycle separation
- Centralized state management
- Shared infrastructure foundations

---

## Security

- Sensitive infrastructure-data protection
- Encryption at rest
- Access control
- Public-exposure prevention
- Integrity protection
- Concurrent-operation protection
- Recovery planning

---

## Troubleshooting

- Backend initialization errors
- State migration
- State-lock testing
- S3 object inspection
- Working-directory mistakes
- Terraform CLI path handling
- AWS CLI verification

---

# Real-World Relevance

Remote Terraform state is a foundational practice in professional Infrastructure as Code environments.

A team-managed Terraform environment typically should not rely on:

```text
one engineer's local terraform.tfstate
```

Instead, teams commonly use centralized state backends.

Remote state enables:

- Shared infrastructure management
- Better recovery
- Controlled concurrent access
- Centralized security controls
- Automation workflows
- CI/CD integration
- Infrastructure governance

The concepts practiced in this lab directly relate to roles such as:

- Cloud Engineer
- Cloud Security Engineer
- DevOps Engineer
- Platform Engineer
- Infrastructure Engineer
- Site Reliability Engineer
- Terraform / Infrastructure as Code Engineer

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Migrated a live modular AWS Terraform environment from local state to a protected Amazon S3 remote backend without changing existing infrastructure. Implemented S3 versioning, server-side encryption, public-access blocking, Terraform destroy protection, and native S3 state locking. Validated migration integrity through state inspection, no-change Terraform planning, S3 object/version verification, and a controlled concurrent-operation locking test.

---

# Result

The Terraform AWS homelab now uses a protected remote-state architecture.

The implementation successfully:

- Created a dedicated Terraform state bootstrap configuration
- Provisioned a dedicated S3 state bucket
- Enabled S3 versioning
- Enabled AES-256 server-side encryption
- Enabled Block Public Access
- Added Terraform `prevent_destroy` protection
- Configured the homelab S3 backend
- Enabled native S3 lockfiles
- Migrated existing live Terraform state
- Preserved all modular resource addresses
- Produced no infrastructure changes after migration
- Verified the remote S3 state object
- Verified state version history
- Verified encryption
- Verified public-access protections
- Demonstrated state-lock behavior
- Demonstrated concurrent-operation blocking
- Verified lock-object cleanup
- Preserved the existing AWS infrastructure without recreation or replacement

Terraform state is no longer dependent solely on the local workstation.

---

# Phase III Completion

With the completion of this lab, the Terraform / Infrastructure as Code phase now includes:

```text
Terraform fundamentals                     ✓
AWS provider configuration                 ✓
VPC deployment with Terraform              ✓
EC2 deployment with Terraform              ✓
Terraform state fundamentals               ✓
Variables and outputs                      ✓
Reusable modules                           ✓
Remote state and locking                   ✓
```

This completes the originally planned Phase III Terraform foundation.

---

# Next Phase

## Observability & Logging

The next phase will focus on gaining deeper visibility into the infrastructure and workloads.

Planned topics include:

- CloudWatch Agent
- Linux host metrics
- Memory monitoring
- Disk monitoring
- Centralized application logs
- Docker logs
- Nginx logs
- CloudWatch Logs
- CloudWatch alarms
- Operational dashboards
- Alerting concepts
- Infrastructure health validation

This will move the homelab from:

```text
Infrastructure is running
```

toward:

```text
Infrastructure is observable, measurable, and diagnosable
```
