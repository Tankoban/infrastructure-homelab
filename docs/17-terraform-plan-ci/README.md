# Lab 17 — Terraform Plan in CI

## Overview

This lab expanded the GitHub Actions CI workflow from basic Terraform formatting and validation into an AWS-aware Terraform planning pipeline.

The workflow now authenticates to AWS using GitHub OpenID Connect (OIDC), assumes a dedicated IAM role with short-lived credentials, accesses the remote Terraform state backend, and runs `terraform plan` automatically in CI.

The pipeline was deliberately designed as a **plan-only workflow**. It can inspect infrastructure and generate proposed changes, but it does not run `terraform apply`.

---

## Objectives

The objectives of this lab were to:

- Understand GitHub Actions OIDC authentication
- Create an AWS OIDC identity provider for GitHub
- Create an IAM role for GitHub Actions
- Configure a repository-specific IAM trust policy
- Use short-lived AWS credentials instead of long-lived access keys
- Grant read-only infrastructure permissions to CI
- Grant narrow Terraform state backend permissions
- Remove local-profile dependencies from Terraform configuration
- Run `terraform init` against the real remote backend
- Run `terraform plan` in GitHub Actions
- Handle required Terraform variables in CI
- Deliberately test that CI detects infrastructure changes
- Confirm that no automatic apply occurs

---

## CI Architecture

The completed Lab 17 workflow is:

```text
Git Push / Pull Request
        |
        v
GitHub Actions
        |
        v
GitHub OIDC Token
        |
        v
AWS STS
        |
        v
Assume IAM Role
        |
        v
Temporary AWS Credentials
        |
        v
Terraform Init
        |
        v
Remote S3 State Backend
        |
        v
Terraform Validate
        |
        v
Terraform Plan
        |
        v
PASS / FAIL
```

No long-lived AWS access keys are stored in GitHub.

---

## OIDC Authentication Model

OIDC allows GitHub Actions to authenticate to AWS without storing permanent AWS credentials.

The authentication flow is:

```text
GitHub Actions
    |
    v
Signed OIDC identity token
    |
    v
AWS IAM trust policy validation
    |
    v
sts:AssumeRoleWithWebIdentity
    |
    v
Temporary AWS credentials
```

The core security principle is:

```text
Trust Policy
= Who is allowed to assume the role?

Permission Policy
= What can the role do after it is assumed?
```

This mirrors the same IAM trust-versus-permission model used previously for the EC2 CloudWatch role.

---

## AWS OIDC Provider

An AWS IAM OIDC identity provider was created for:

```text
https://token.actions.githubusercontent.com
```

with the audience:

```text
sts.amazonaws.com
```

This allows AWS IAM to validate GitHub-issued OIDC tokens.

The provider alone does not grant access to AWS resources.

It only establishes GitHub as a recognized identity provider.

---

## GitHub Actions IAM Role

A dedicated IAM role was created:

```text
github-actions-terraform-plan
```

This role is intended specifically for Terraform planning operations in CI.

It is separate from any future deployment role.

Conceptually:

```text
Plan Role
= inspect infrastructure and generate Terraform plans

Deployment Role
= create, modify, or destroy infrastructure
```

This separation limits the blast radius of the CI workflow.

---

## IAM Trust Policy

The IAM role trust relationship uses:

```text
sts:AssumeRoleWithWebIdentity
```

and restricts access using GitHub OIDC token claims.

The trust policy validates:

```text
Audience
= sts.amazonaws.com

Repository identity
= Tankoban/infrastructure-homelab
```

Because the GitHub repository uses the newer immutable-ID OIDC subject format, the trust condition includes the immutable owner and repository IDs.

Conceptually:

```text
GitHub token received
        |
        v
Audience correct?
        |
        v
Repository identity correct?
        |
        v
Role assumption allowed
```

---

## Trust Policy Failure

The first OIDC authentication attempt failed with:

```text
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The OIDC provider and IAM role both existed, but the trust policy subject condition did not match the subject claim issued by GitHub.

The original condition used a repository-name-only subject pattern.

The repository instead used the newer GitHub OIDC subject format containing immutable owner and repository IDs.

The trust policy was updated to match the actual repository identity.

After the update:

```text
Configure AWS credentials   ✓
Verify AWS identity         ✓
```

This confirmed that the failure occurred at the trust-policy validation layer.

---

## AWS Permissions

The Terraform plan role uses:

```text
AWS ReadOnlyAccess
```

for broad read access to AWS infrastructure.

This allows Terraform to inspect existing resources during state refresh and planning.

The role does not receive broad infrastructure write permissions.

---

## Terraform State Backend Permissions

The Terraform backend uses:

```text
S3 bucket:
sugoi-terraform-state-2026

State key:
homelab/terraform.tfstate
```

Terraform also uses the native S3 lock file:

```text
homelab/terraform.tfstate.tflock
```

The plan role therefore receives narrow S3 permissions for:

```text
List state path
Read state object
Write state object as required by backend operations
Read lock file
Create lock file
Delete lock file
```

This means the role is:

```text
Infrastructure read-only
+
narrow Terraform backend write access
```

It is therefore not technically a completely read-only AWS role.

---

## GitHub Actions OIDC Permissions

The GitHub Actions workflow includes:

```yaml
permissions:
  id-token: write
  contents: read
```

These permissions allow the workflow to:

```text
Request an OIDC token
Read repository contents
```

The OIDC token is exchanged for temporary AWS credentials.

---

## AWS Credential Configuration

The workflow uses the AWS credential action to assume:

```text
github-actions-terraform-plan
```

with a temporary session.

A verification step then runs:

```bash
aws sts get-caller-identity
```

This confirms that the workflow is operating under the expected AWS IAM role.

---

## Removing Local AWS Profile Dependencies

The original Terraform configuration explicitly referenced:

```text
profile = "lab-admin"
```

in both:

```text
S3 backend configuration
AWS provider configuration
```

This worked locally because the Linux workstation had a configured `lab-admin` AWS CLI profile.

The GitHub runner did not.

The profile dependency was therefore removed from both locations.

The Terraform configuration now relies on the standard AWS credential chain.

Conceptually:

```text
Local workstation
    |
    v
AWS CLI/session credentials
    |
    v
Terraform

GitHub Actions
    |
    v
OIDC temporary credentials
    |
    v
Terraform
```

This makes the Terraform configuration portable across environments.

---

## Provider Authentication Failure

After OIDC authentication succeeded, Terraform planning initially failed with:

```text
failed to get shared config profile, lab-admin
```

The AWS provider still explicitly referenced the local profile.

Removing the profile reference allowed Terraform to use the OIDC-provided environment credentials in CI.

---

## Required Terraform Variable

The Terraform root module requires:

```text
admin_cidr
```

Locally, this value is provided through an ignored `.tfvars` file.

Because `.tfvars` files are intentionally excluded from Git, the GitHub runner did not have access to that value.

The initial Terraform plan therefore failed with:

```text
No value for required variable

The root module input variable "admin_cidr" is not set
```

---

## CI Variable Handling

A safe CI-specific value was provided through:

```text
TF_VAR_admin_cidr
```

Terraform automatically maps environment variables using:

```text
TF_VAR_<variable_name>
```

For CI validation, a loopback CIDR was used:

```text
127.0.0.1/32
```

This provides a syntactically valid value without exposing a real administrator network range.

---

## Remote Backend Initialization

Lab 16 used:

```bash
terraform init -backend=false
```

because AWS access was not required.

Lab 17 now uses:

```bash
terraform init
```

with the real S3 backend.

This proves that the GitHub Actions role can:

```text
Authenticate to AWS
Access Terraform state
Manage the Terraform lock file
Initialize the backend
```

---

## Terraform Plan

The workflow runs:

```bash
terraform plan -input=false -no-color
```

The options provide:

```text
-input=false
= prevent interactive prompts in CI

-no-color
= produce clean log output
```

The workflow generates a real Terraform execution plan using:

```text
Current configuration
+
Remote Terraform state
+
Live AWS infrastructure
```

---

## Intentional Plan Change Test

The Terraform planning workflow was deliberately tested by changing the networking module.

The change was committed and pushed to GitHub.

The GitHub Actions workflow detected the infrastructure difference and displayed it in the Terraform plan.

No apply step existed in the pipeline.

This verified:

```text
Infrastructure configuration changed
        |
        v
CI detected the change
        |
        v
Terraform displayed proposed actions
        |
        v
No infrastructure modification occurred
```

---

## Revert Validation

The intentional networking change was reverted with Git.

The reverted commit triggered GitHub Actions again.

The Terraform plan returned to the expected clean state.

The validated lifecycle was:

```text
Clean configuration
        |
        v
Clean Terraform plan

Intentional change
        |
        v
Terraform detects proposed change

No apply
        |
        v
AWS remains unchanged

Git revert
        |
        v
Terraform returns to clean plan
```

---

## Node.js Runtime Warning

During the GitHub Actions run, GitHub reported that some existing action versions targeted Node.js 20 and were being forced to run on Node.js 24.

The affected actions included:

```text
actions/checkout
hashicorp/setup-terraform
```

The workflow was updated to newer action versions compatible with the current GitHub Actions runtime.

This warning was separate from the Terraform planning failures.

---

## Security Model

The final CI security design is:

```text
GitHub repository
        |
        v
OIDC token
        |
        v
AWS trust validation
        |
        v
Temporary IAM role session
        |
        v
Read AWS infrastructure
        |
        v
Access Terraform state
        |
        v
Generate Terraform plan
```

The workflow does not:

```text
Store AWS access keys
Store AWS secret keys
Run terraform apply
Create infrastructure
Destroy infrastructure
```

---

## Problems Encountered

### OIDC Trust Policy Mismatch

Symptom:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Cause:

```text
GitHub OIDC subject claim did not match IAM trust policy
```

Fix:

```text
Updated trust policy to use the repository's immutable owner and repository IDs
```

---

### Missing Terraform Variable

Symptom:

```text
No value for required variable "admin_cidr"
```

Cause:

```text
Local .tfvars file is intentionally not committed
```

Fix:

```text
Provided a CI-specific TF_VAR_admin_cidr value
```

---

### Local AWS Profile Dependency

Symptom:

```text
failed to get shared config profile, lab-admin
```

Cause:

```text
Terraform configuration depended on a workstation-specific AWS profile
```

Fix:

```text
Removed hard-coded profile references from the backend and AWS provider
```

---

### Git Working Directory Mistake

During the lab, repository-root-relative Git paths were initially run while already inside:

```text
terraform/aws/homelab
```

This caused Git pathspec errors.

The commands were rerun from:

```text
~/Projects/infrastructure-homelab
```

This reinforced the distinction between:

```text
Git repository root
Terraform root module
```

---

## Validation

The final Lab 17 pipeline validated:

```text
GitHub OIDC provider                  ✓
OIDC IAM role                         ✓
Repository-restricted trust policy   ✓
Short-lived AWS credentials           ✓
AWS identity verification             ✓
Remote S3 backend initialization      ✓
Native S3 state locking               ✓
Terraform formatting                  ✓
Terraform validation                  ✓
Terraform plan                        ✓
Required CI variable handling         ✓
Intentional plan-change detection     ✓
No automatic terraform apply          ✓
Git revert recovery                   ✓
Environment-portable AWS auth         ✓
```

---

## Key Concepts Learned

```text
OpenID Connect
OIDC federation
AWS STS
AssumeRoleWithWebIdentity
IAM trust policies
IAM permission policies
Temporary credentials
GitHub Actions permissions
Terraform remote state in CI
Terraform state locking
AWS credential chain
Environment portability
TF_VAR environment variables
Plan-only CI
Least privilege
CI infrastructure review
```

---

## Interview-Ready Explanation

> I extended my Terraform GitHub Actions workflow to authenticate to AWS using OIDC rather than long-lived access keys. I created a repository-restricted IAM trust relationship and a dedicated plan role with read-only infrastructure permissions plus narrow S3 permissions for Terraform remote state and locking. The pipeline initializes the real backend and generates Terraform plans automatically. I also validated the workflow by deliberately changing infrastructure configuration, confirming that CI detected the proposed change without applying it, then reverting the change and confirming the plan returned clean.

---

# Portfolio Summary

> Implemented secure Terraform planning in GitHub Actions using AWS OIDC federation and short-lived IAM credentials. Built a repository-restricted trust policy, configured plan-only AWS permissions and remote-state access, removed workstation-specific authentication dependencies, and validated the pipeline through intentional infrastructure changes and clean rollback testing.

---

# Result

The infrastructure repository now supports AWS-aware Terraform planning through CI.

The completed flow is:

```text
Code Change
    |
    v
GitHub Actions
    |
    v
OIDC Authentication
    |
    v
Assume AWS IAM Role
    |
    v
Terraform Init
    |
    v
Remote State
    |
    v
Terraform Validate
    |
    v
Terraform Plan
    |
    v
Infrastructure Change Review
```

Terraform infrastructure changes can now be reviewed automatically before deployment without storing long-lived AWS credentials or allowing the CI planning workflow to apply changes.
