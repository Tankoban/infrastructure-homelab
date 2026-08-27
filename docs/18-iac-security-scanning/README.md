# Lab 18 — Infrastructure as Code Security Scanning

## Overview

This lab introduced automated Infrastructure as Code (IaC) security scanning into the GitHub Actions CI pipeline using Checkov.

The goal was not simply to make the scanner pass. The lab focused on identifying real security weaknesses, validating false positives, documenting accepted risks, and implementing additional security controls where appropriate.

The final pipeline now evaluates Terraform code for:

- Formatting
- Structural validity
- AWS-aware Terraform planning
- Security-policy violations

The workflow was also deliberately tested with an insecure EC2 metadata configuration to verify that Checkov could detect a real security regression.

---

## Objectives

The objectives of this lab were to:

- Integrate Checkov into GitHub Actions
- Scan Terraform code automatically during CI
- Understand static IaC security analysis
- Distinguish true positives from false positives
- Remediate genuine security findings
- Document intentional security exceptions
- Validate cross-module scanner limitations
- Harden EC2 metadata access
- Restrict the default VPC security group
- Enable VPC Flow Logs
- Preserve intentionally simplified homelab architecture where justified
- Test that an insecure Terraform change causes CI to fail

---

## CI Architecture

The updated CI pipeline is:

```text
Git Push / Pull Request
        |
        v
GitHub Actions
        |
        v
Terraform Formatting
        |
        v
AWS OIDC Authentication
        |
        v
Terraform Init
        |
        v
Terraform Validate
        |
        v
Checkov IaC Security Scan
        |
        v
Terraform Plan
        |
        v
PASS / FAIL
```

Checkov runs before the Terraform plan so security-policy violations can fail the workflow before infrastructure changes are reviewed further.

---

## Checkov Mental Model

Checkov performs static analysis of Infrastructure as Code.

It does not inspect live AWS infrastructure directly.

Conceptually:

```text
terraform validate
= Is the configuration structurally valid?

Checkov
= Does the configuration violate known security policies?

terraform plan
= What infrastructure changes would Terraform make?
```

These are separate validation layers.

---

## Initial Checkov Findings

The first Checkov scan identified multiple findings across:

- EC2
- Networking
- CloudWatch
- S3
- Security groups
- VPC configuration

Examples included:

```text
IMDSv1 allowed
EBS optimization disabled
Detailed EC2 monitoring disabled
Public subnet IP assignment
Public HTTP ingress
Unrestricted outbound access
CloudWatch Logs without customer-managed KMS
Short CloudWatch retention
S3 without replication
S3 without access logging
S3 without lifecycle policy
S3 using SSE-S3 instead of customer-managed KMS
Default security group not explicitly restricted
VPC Flow Logs not detected
Security group attachment not detected
```

The findings were not treated equally.

---

## Security Triage Model

Each finding was evaluated as one of:

```text
Real security issue
Accepted architectural risk
False positive / static-analysis limitation
Deferred hardening control
```

This avoided blindly changing infrastructure merely to satisfy the scanner.

The decision process was:

```text
Finding detected
      |
      v
Is the finding real?
      |
      +---- no ----> verify false positive
      |
     yes
      |
      v
Should it be fixed now?
      |
      +---- yes ----> remediate
      |
      +---- no -----> document exception / defer
```

---

## Remediation — Require IMDSv2

Checkov reported:

```text
CKV_AWS_79
Ensure Instance Metadata Service Version 1 is not enabled
```

The EC2 instance was hardened using:

```hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

This requires IMDSv2 and prevents IMDSv1 requests.

Conceptually:

```text
IMDSv1
= metadata requests without session token

IMDSv2
= token-based metadata access
```

Requiring IMDSv2 reduces the risk of credential exposure through certain server-side request forgery and metadata-access attacks.

After remediation, CKV_AWS_79 passed.

---

## Remediation — Restrict Default VPC Security Group

Checkov reported:

```text
CKV2_AWS_12
Ensure the default security group of every VPC restricts all traffic
```

The default VPC security group was explicitly managed through Terraform with no ingress or egress rules.

This results in:

```text
Custom application security group
= explicitly permits required traffic

Default VPC security group
= permits no traffic
```

This provides defense in depth if a resource is accidentally created using the default security group.

After remediation, CKV2_AWS_12 passed.

---

## False Positive — Security Group Attachment

Checkov reported:

```text
CKV2_AWS_5
Ensure that Security Groups are attached to another resource
```

The security group was manually verified as attached to the EC2 instance through the module chain:

```text
security module
    |
    v
security_group_id output
    |
    v
root module
    |
    v
compute module variable
    |
    v
aws_instance.web
    |
    v
vpc_security_group_ids
```

The EC2 resource contains:

```hcl
vpc_security_group_ids = [var.security_group_id]
```

Checkov did not resolve the relationship across module boundaries.

The finding was therefore documented and suppressed as a confirmed static-analysis limitation.

---

## Accepted Risk — Public Subnet IP Assignment

Checkov reported:

```text
CKV_AWS_130
Ensure VPC subnets do not assign public IP by default
```

The public subnet currently assigns public IP addresses intentionally.

This is part of the current learning architecture:

```text
Internet
    |
    v
Public subnet
    |
    v
EC2
```

Private compute is planned for a later architecture phase.

The finding was documented as an accepted temporary architectural risk rather than changing the current lab design prematurely.

---

## Accepted Risk — Public HTTP

Checkov reported:

```text
CKV_AWS_260
Ensure no security groups allow ingress from 0.0.0.0/0 to port 80
```

Public HTTP remains intentional in the current homelab.

Trusted HTTPS and TLS termination are planned for a later phase.

The exception was documented rather than misrepresenting the current architecture as production-ready.

---

## Accepted Risk — Unrestricted Outbound Traffic

Checkov reported:

```text
CKV_AWS_382
Ensure no security groups allow unrestricted egress
```

The EC2 instance currently requires broad outbound connectivity for:

```text
OS package installation
System updates
Docker image pulls
CloudWatch communication
DNS
HTTPS-based service access
```

Restricting outbound traffic correctly would require a more deliberate network-egress architecture.

The finding was documented as a temporary accepted risk and deferred to a later private-network/security phase.

---

## CloudWatch Log Group Exceptions

Checkov reported:

```text
CKV_AWS_158
CloudWatch Log Groups should use KMS encryption

CKV_AWS_338
CloudWatch Log Groups should retain logs for at least one year
```

The homelab currently uses:

```text
AWS-managed encryption at rest
7-day log retention
```

These settings were intentional.

Customer-managed KMS keys and one-year retention were considered disproportionate for a disposable, cost-conscious learning environment.

The findings were documented rather than implementing controls without a supporting requirement.

---

## Terraform State S3 Findings

Checkov reported several findings against the persistent Terraform state bucket:

```text
CKV2_AWS_62
S3 event notifications

CKV_AWS_144
Cross-region replication

CKV_AWS_18
S3 access logging

CKV2_AWS_61
Lifecycle configuration

CKV_AWS_145
KMS encryption
```

The Terraform state bucket already includes:

```text
Versioning
Block Public Access
Server-side encryption
Terraform native lockfile support
prevent_destroy
```

Additional controls such as:

```text
Cross-region replication
Dedicated access logging
Customer-managed KMS
Lifecycle policies
Event notifications
```

were reviewed and intentionally deferred for the current single-region homelab.

Each exception was documented with its reason.

---

## VPC Flow Logs

Checkov reported:

```text
CKV2_AWS_11
Ensure VPC Flow Logging is enabled
```

Unlike several other findings, this control was considered valuable enough to implement.

VPC Flow Logs were added through the observability module.

The resulting architecture is:

```text
VPC
 |
 v
VPC Flow Logs
 |
 v
CloudWatch Logs
 |
 v
/homelab/vpc/flow-logs
```

The Flow Log captures:

```text
ACCEPT traffic
REJECT traffic
```

using:

```hcl
traffic_type = "ALL"
```

---

## Flow Log Data

VPC Flow Logs provide network metadata such as:

```text
Source IP
Destination IP
Source port
Destination port
Protocol
Packets
Bytes
ACCEPT / REJECT decision
```

Flow Logs do not capture packet payloads.

Conceptually:

```text
VPC Flow Logs
= network conversation metadata

Packet capture
= actual packet contents
```

This makes Flow Logs useful for:

```text
Traffic analysis
Rejected-connection investigation
Security monitoring
Network troubleshooting
Detection engineering
```

---

## VPC Flow Log IAM Role

The VPC Flow Logs service requires an IAM role to publish logs to CloudWatch.

The trust relationship allows:

```text
vpc-flow-logs.amazonaws.com
```

to assume the dedicated Flow Logs role.

The role receives only the CloudWatch Logs permissions required to publish the Flow Log data.

Conceptually:

```text
VPC Flow Logs service
        |
        v
IAM trust policy
        |
        v
Flow Logs IAM role
        |
        v
CloudWatch Logs permissions
        |
        v
Log group
```

This reinforces the same IAM trust-versus-permission model used previously for EC2 and GitHub Actions.

---

## False Positive — VPC Flow Logs

After VPC Flow Logs were implemented, Checkov continued reporting:

```text
CKV2_AWS_11
Ensure VPC Flow Logging is enabled
```

The Flow Log lived in the observability module while the VPC lived in the networking module.

The actual relationship was:

```text
module.networking.aws_vpc.homelab
        |
        v
module.networking.vpc_id
        |
        v
module.observability.vpc_id
        |
        v
aws_flow_log.homelab
```

Checkov did not resolve this cross-module relationship.

The finding was manually verified and suppressed as a static-analysis limitation.

The architecture was not changed merely to accommodate the scanner.

---

## Checkov Policy Suppressions

Checkov suppressions were added only after the findings were evaluated.

The general pattern was:

```hcl
# checkov:skip=CHECK_ID:Reason for accepting or suppressing this finding.
```

Suppressions were placed inside the relevant Terraform resource blocks.

The documented reason identifies whether the finding is:

```text
Intentional architecture
Deferred control
Cost-conscious lab decision
Confirmed false positive
```

This creates an auditable record of why the policy was not enforced.

---

## Why Suppression Is Not the Same as Ignoring

The approach used in this lab was:

```text
Find
Assess
Verify
Decide
Document
Suppress
```

rather than:

```text
Find
Suppress
Forget
```

This distinction is important because security scanners are advisory tools.

They provide policy signals, but architecture and risk decisions still require human review.

---

## Intentional Security Regression Test

After the final Checkov configuration passed, the pipeline was deliberately tested with an insecure EC2 metadata configuration.

The secure configuration:

```hcl
http_tokens = "required"
```

was temporarily changed to:

```hcl
http_tokens = "optional"
```

This allowed IMDSv1.

The change was committed and pushed without applying it to AWS.

Checkov correctly failed with:

```text
CKV_AWS_79
Ensure Instance Metadata Service Version 1 is not enabled
```

This confirmed that the security gate could detect a genuine IaC security regression.

---

## Recovery Test

The insecure change was reverted through Git.

The next GitHub Actions run returned Checkov to a passing state.

The validated lifecycle was:

```text
Secure Terraform
      |
      v
PASS

Intentional insecure change
      |
      v
Checkov FAIL

No Terraform apply
      |
      v
AWS unchanged

Git revert
      |
      v
Checkov PASS
```

---

## CI Security Gate

The final CI workflow now evaluates:

```text
Terraform formatting
Terraform structural validity
IaC security posture
AWS authentication
Remote state
Terraform execution plan
```

The pipeline can reject code because it is:

```text
Malformed
Improperly formatted
Security-policy violating
Unable to initialize
Unable to plan
```

before infrastructure is deployed.

---

## Problems Encountered

### Workflow Did Not Run on Lab 18 Branch

The workflow initially only triggered on explicitly named branches from earlier labs.

The trigger configuration was updated so pushes to all branches execute CI.

This made the pipeline reusable across future feature branches.

---

### Checkov Security Group False Positive

Checkov failed to recognize a security-group attachment across Terraform module boundaries.

The attachment was verified manually and documented as a false positive.

---

### Checkov VPC Flow Log False Positive

Checkov failed to recognize VPC Flow Logs defined in a separate observability module.

The relationship was manually verified through Terraform variables and module outputs.

The architecture was preserved and the finding documented.

---

### Suppression Placement

A Checkov suppression was initially placed above a Terraform resource block.

Checkov requires the suppression comment inside the resource scope.

After moving the annotation inside the resource, the finding was correctly reported as skipped instead of failed.

---

## Validation

The final Lab 18 implementation validated:

```text
Checkov integrated into GitHub Actions            ✓
CI runs on Lab 18 feature branch                  ✓
Initial findings detected                         ✓
IMDSv2 enforced                                   ✓
Default VPC SG restricted                         ✓
Security-group false positive verified            ✓
Accepted risks documented                         ✓
VPC Flow Logs implemented                         ✓
Flow Log IAM role created                         ✓
CloudWatch Flow Log destination configured        ✓
Cross-module Flow Log false positive verified     ✓
Checkov suppressions documented                   ✓
Unresolved Checkov failures                       0
Intentional IMDS regression detected              ✓
Insecure change not applied                       ✓
Revert returned CI to green                       ✓
```

---

## Key Concepts Learned

```text
Infrastructure as Code security scanning
Static analysis
Checkov
Security policy as code
True positive
False positive
Accepted risk
Risk treatment
Compensating controls
Security exceptions
IMDSv2
Default security groups
VPC Flow Logs
Network telemetry
Security regression testing
CI security gates
Cross-module analysis limitations
```

---

## Interview-Ready Explanation

> I integrated Checkov into my Terraform GitHub Actions pipeline to perform automated IaC security scanning. Rather than blindly suppressing findings, I triaged them into real issues, accepted risks, deferred controls, and false positives. I remediated issues such as IMDSv1 and the default VPC security group, implemented VPC Flow Logs for additional network telemetry, and documented intentional exceptions for the current homelab architecture. I also deliberately reintroduced an insecure IMDS configuration to confirm the pipeline would fail on a real security regression, then reverted it and verified the workflow returned to green.

---

# Portfolio Summary

> Added automated IaC security scanning to a Terraform CI pipeline using Checkov. Triaged and remediated security findings, documented justified exceptions, validated cross-module false positives, enforced IMDSv2, restricted the default VPC security group, implemented VPC Flow Logs, and verified the security gate through an intentional regression test.

---

# Result

The infrastructure repository now includes an automated security review layer.

The completed flow is:

```text
Code Change
    |
    v
GitHub Actions
    |
    v
Terraform Checks
    |
    v
Checkov Security Scan
    |
    v
Security Triage / Enforcement
    |
    v
Terraform Plan
```

The CI pipeline now evaluates not only whether infrastructure code is valid, but whether it meets defined security expectations before deployment.
