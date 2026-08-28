# Lab 20 — Controlled Terraform Deployment

## Overview

This lab completed the CI/CD portion of Phase VI by adding a controlled Terraform deployment workflow to GitHub Actions.

Previous labs validated Terraform formatting, configuration, security posture, secrets, and execution plans.

This lab introduced the ability to run `terraform apply` from GitHub Actions while preserving explicit security controls around when and how deployment can occur.

The deployment workflow uses:

- Manual workflow dispatch
- A protected GitHub Environment
- Required approval
- GitHub OIDC authentication
- A dedicated AWS deployment IAM role
- Short-lived AWS credentials
- Terraform remote state
- A saved Terraform plan
- Controlled Terraform apply

The final result is a deployment pipeline that can modify AWS infrastructure without storing long-lived AWS credentials in GitHub.

---

## Objectives

The objectives of this lab were to:

- Create a separate Terraform deployment workflow
- Prevent automatic deployment on every push
- Create a dedicated AWS deployment role
- Separate Terraform planning permissions from deployment permissions
- Restrict deployment role trust
- Use GitHub OIDC for temporary deployment credentials
- Configure a protected GitHub deployment environment
- Require explicit deployment approval
- Store deployment-specific configuration outside the repository
- Generate and apply the same Terraform plan
- Validate deployment-role permissions
- Test branch-restricted OIDC trust behavior
- Resolve GitHub Environment OIDC subject differences
- Perform a successful end-to-end Terraform deployment from GitHub Actions

---

## Deployment Architecture

The completed deployment path is:

```text
Manual GitHub Workflow Dispatch
        |
        v
homelab-deploy Environment
        |
        v
Required Approval
        |
        v
GitHub OIDC Token
        |
        v
AWS STS
        |
        v
github-actions-terraform-deploy
        |
        v
Temporary AWS Credentials
        |
        v
Terraform Init
        |
        v
Terraform Validate
        |
        v
Terraform Plan
        |
        v
Saved tfplan
        |
        v
Terraform Apply
```

The workflow does not automatically deploy infrastructure when code is pushed.

---

## CI and CD Separation

Phase VI now has two distinct workflows.

### CI Workflow

The normal Terraform validation workflow performs:

```text
Formatting
Validation
Secret scanning
IaC security scanning
Terraform planning
```

It runs automatically on repository changes.

### Deployment Workflow

The Terraform deployment workflow performs:

```text
Manual trigger
Protected environment approval
OIDC authentication
Terraform initialization
Terraform validation
Terraform plan
Terraform apply
```

This separates:

```text
Continuous Integration
= evaluate code

Continuous Deployment
= intentionally modify infrastructure
```

---

## Plan Role vs Deploy Role

A dedicated Terraform deployment IAM role was created:

```text
github-actions-terraform-deploy
```

This is separate from:

```text
github-actions-terraform-plan
```

The distinction is:

```text
Plan role
= inspect AWS and generate Terraform plans

Deploy role
= create, modify, and destroy homelab infrastructure
```

The plan role was not simply upgraded with deployment permissions.

This reduces blast radius and keeps CI identities aligned with their intended purpose.

---

## Deployment IAM Permissions

The deployment role receives permissions required for the homelab's Terraform-managed services.

These include:

```text
EC2
VPC networking
CloudWatch
CloudWatch Logs
Homelab IAM roles
Homelab instance profiles
Terraform S3 state
Terraform state locking
```

The role is not granted AWS `AdministratorAccess`.

IAM permissions are restricted more tightly where possible, including homelab-specific role and instance-profile naming.

---

## Manual Workflow Dispatch

The deployment workflow uses:

```yaml
on:
  workflow_dispatch:
```

This means deployment requires an explicit manual action in GitHub.

A code push alone does not trigger `terraform apply`.

Conceptually:

```text
Push
!=
Deploy
```

Deployment begins only when the workflow is intentionally started.

---

## Protected Deployment Environment

A GitHub Environment was created:

```text
homelab-deploy
```

The Terraform deployment job references this environment.

The environment requires approval before the deployment job can continue.

The deployment lifecycle therefore includes two intentional actions:

```text
Start workflow
      |
      v
Approve deployment
      |
      v
Apply infrastructure
```

This adds an explicit human control point before AWS infrastructure can be modified.

---

## Environment-Specific Admin CIDR

The Terraform root module requires:

```text
admin_cidr
```

A loopback CIDR was previously used during plan-only CI because no real deployment occurred.

For real deployment, the correct administrator CIDR is required.

The actual CIDR is stored as a protected GitHub Environment secret:

```text
HOMELAB_ADMIN_CIDR
```

The workflow maps this value into Terraform using:

```text
TF_VAR_admin_cidr
```

This keeps deployment-specific configuration out of the Git repository.

---

## Saved Terraform Plan

The deployment workflow generates a saved Terraform plan:

```bash
terraform plan -input=false -no-color -out=tfplan
```

The exact saved plan is then applied:

```bash
terraform apply -input=false -auto-approve tfplan
```

This ensures Terraform applies the same set of actions that were calculated during the plan step.

Conceptually:

```text
Plan
  |
  v
tfplan
  |
  v
Apply that exact plan
```

rather than recalculating a different plan immediately before apply.

---

## OIDC Authentication

The deployment workflow uses GitHub OIDC rather than long-lived AWS access keys.

The authentication model is:

```text
GitHub Actions
      |
      v
OIDC token
      |
      v
AWS trust policy
      |
      v
AssumeRoleWithWebIdentity
      |
      v
Temporary deploy credentials
```

This keeps permanent AWS credentials out of GitHub Secrets.

---

## Initial Branch Restriction Test

The deployment role was initially restricted to the `main` branch.

The workflow was temporarily triggered from:

```text
lab20-controlled-deployment
```

to test authentication.

As expected, AWS rejected the role assumption with:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This confirmed that the trust restriction was working.

---

## Temporary Feature-Branch Trust

The trust policy was temporarily expanded to allow:

```text
main
+
lab20-controlled-deployment
```

This allowed the deployment workflow to validate:

```text
OIDC authentication
AWS identity
Terraform initialization
Terraform validation
Terraform planning
```

from the feature branch.

After successful validation, the temporary branch trust was removed.

This demonstrated:

```text
Temporary exception
      |
      v
Validate intended behavior
      |
      v
Revoke exception
```

rather than permanently weakening the deployment role.

---

## GitHub Environment OIDC Subject

After the workflow was merged to `main` and attached to the protected:

```text
homelab-deploy
```

environment, OIDC authentication failed again.

The error was:

```text
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The cause was that GitHub changes the OIDC subject claim when a job uses an Environment.

Without an environment, the subject was branch-based.

Conceptually:

```text
repo:<repository>:ref:refs/heads/main
```

With the protected environment, the subject became environment-based:

```text
repo:<repository>:environment:homelab-deploy
```

The AWS trust policy still expected the branch-based subject.

---

## Environment-Based Trust Policy

The deployment-role trust policy was updated to trust the protected GitHub Environment subject.

The final trust relationship validates:

```text
GitHub OIDC provider
Correct AWS STS audience
Correct immutable repository identity
homelab-deploy environment
```

Branch restrictions are enforced through the GitHub Environment deployment rules.

This produces layered controls:

```text
GitHub Environment
= controls which branch may deploy

AWS trust policy
= controls which environment may assume the role
```

---

## OIDC Formatting Error

During the trust-policy update, an extra colon was accidentally introduced into the OIDC subject:

```text
...REPO_ID::environment:homelab-deploy
```

instead of:

```text
...REPO_ID:environment:homelab-deploy
```

AWS therefore continued rejecting:

```text
sts:AssumeRoleWithWebIdentity
```

The formatting error was identified, corrected, and the IAM trust policy was updated again.

After correction, OIDC authentication succeeded.

This reinforced the fact that IAM trust conditions require exact claim matching.

---

## Deployment Approval Test

The final deployment workflow was manually triggered from:

```text
main
```

The job paused at the protected:

```text
homelab-deploy
```

environment.

Deployment approval was explicitly granted.

The workflow then continued.

This validated the environment protection control independently of Terraform.

---

## Successful Deployment

After the final OIDC trust-policy correction, the complete deployment workflow passed.

The validated execution path was:

```text
Manual workflow dispatch              ✓
Protected environment                 ✓
Required approval                     ✓
OIDC token request                     ✓
Deploy role assumption                ✓
Temporary AWS credentials             ✓
Terraform remote-state initialization ✓
Terraform validation                  ✓
Terraform plan                        ✓
Saved execution plan                  ✓
Terraform apply                       ✓
```

The homelab infrastructure was successfully deployed through GitHub Actions.

---

## Security Model

The final deployment design uses multiple controls rather than relying on a single security boundary.

```text
Manual workflow dispatch
        |
        v
Protected environment
        |
        v
Required reviewer
        |
        v
Environment branch restrictions
        |
        v
GitHub OIDC
        |
        v
Repository/environment-specific IAM trust
        |
        v
Dedicated deploy IAM role
        |
        v
Scoped AWS permissions
        |
        v
Saved Terraform plan
        |
        v
Terraform apply
```

---

## Why Auto-Apply Was Not Used

The workflow does not automatically run:

```text
terraform apply
```

on every push to `main`.

That design would allow repository changes to modify infrastructure immediately after merge.

For the current homelab, explicit deployment approval provides a safer learning and operational model.

The principle is:

```text
Automation
!=
absence of control
```

Automation should reduce repetitive work while preserving appropriate approval boundaries.

---

## Problems Encountered

### Deployment Role Rejected Feature Branch

Symptom:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Cause:

```text
Deploy-role trust allowed only main
```

Resolution:

```text
Temporarily allowed the Lab 20 branch for testing, then revoked the exception.
```

---

### GitHub Environment Changed OIDC Subject

Symptom:

```text
Environment approved
OIDC role assumption failed
```

Cause:

```text
GitHub environment jobs use an environment-based OIDC subject instead of a branch-based subject.
```

Resolution:

```text
Updated AWS trust policy to trust the homelab-deploy environment subject.
```

---

### OIDC Subject Formatting Error

Symptom:

```text
Trust policy appeared correct
OIDC authentication still failed
```

Cause:

```text
An accidental double colon existed before the environment claim.
```

Resolution:

```text
Corrected the OIDC subject and updated the AWS IAM role.
```

---

### Deployment Admin CIDR

The plan-only workflow used:

```text
127.0.0.1/32
```

as a safe placeholder.

Using that value during a real deployment would prevent normal remote SSH access.

The deployment workflow therefore uses the protected:

```text
HOMELAB_ADMIN_CIDR
```

environment secret.

---

## Validation

The final Lab 20 implementation validated:

```text
Separate deployment workflow                   ✓
Manual workflow dispatch                       ✓
Dedicated deployment IAM role                  ✓
Deployment role not AdministratorAccess        ✓
OIDC short-lived credentials                   ✓
Feature-branch restriction validated           ✓
Temporary test trust revoked                   ✓
Protected GitHub Environment                   ✓
Required deployment approval                   ✓
Environment-specific admin CIDR                ✓
Environment-based OIDC subject                 ✓
Remote Terraform state                         ✓
Saved Terraform execution plan                 ✓
Controlled terraform apply                     ✓
End-to-end AWS deployment                      ✓
```

---

## Key Concepts Learned

```text
Continuous Deployment
Controlled deployment
GitHub workflow_dispatch
GitHub Environments
Deployment protection rules
Required reviewers
OIDC federation
Environment OIDC subjects
AWS STS
Dedicated deployment roles
Least privilege
Temporary credentials
Terraform plan files
Controlled terraform apply
CI/CD separation
Human approval gates
Defense in depth
```

---

## Interview-Ready Explanation

> I built a controlled Terraform deployment workflow in GitHub Actions that is separate from my normal CI validation pipeline. The deployment workflow uses manual dispatch, a protected GitHub Environment with explicit approval, GitHub OIDC federation, and a dedicated AWS deployment role rather than long-lived credentials or AdministratorAccess. The workflow generates a saved Terraform plan and applies that exact plan after approval. During testing I validated branch-restricted OIDC trust, temporarily expanded and then revoked feature-branch trust, and resolved an environment-based OIDC subject mismatch before completing a successful end-to-end deployment.

---

# Portfolio Summary

> Built a controlled Terraform deployment pipeline using GitHub Actions, protected deployment environments, AWS OIDC federation, short-lived IAM credentials, scoped deployment permissions, environment-specific configuration, saved Terraform plans, and explicit human approval before infrastructure changes.

---

# Result

The infrastructure homelab now supports a complete CI/CD workflow.

```text
Code Change
    |
    v
CI Validation
    |
    +--> Terraform Format
    +--> Terraform Validate
    +--> Gitleaks
    +--> Checkov
    +--> Terraform Plan
    |
    v
Merge to Main
    |
    v
Manual Deployment
    |
    v
Protected Environment Approval
    |
    v
OIDC Authentication
    |
    v
Terraform Plan
    |
    v
Terraform Apply
```

Phase VI now provides automated quality, security, planning, and controlled deployment capabilities across the Terraform infrastructure lifecycle.
