# Lab 16 — GitHub Actions Fundamentals

## Overview

This lab introduced continuous integration to the infrastructure homelab using GitHub Actions.

Previously, Terraform quality checks were run manually from the local workstation before commits and deployments.

This lab automated those checks so that Terraform formatting and configuration validation run automatically when code is pushed to GitHub or when a pull request targets the main branch.

The workflow was also deliberately tested with an intentional formatting failure to confirm that the CI quality gate could correctly reject improperly formatted Terraform code.

---

## Objectives

The objectives of this lab were to:

- Understand the basic GitHub Actions execution model
- Create a GitHub Actions workflow
- Configure workflow triggers
- Understand jobs, steps, runners, and reusable actions
- Automatically check Terraform formatting
- Automatically initialize Terraform without using the production backend
- Automatically validate Terraform configuration
- Avoid exposing AWS credentials during basic CI validation
- Deliberately trigger a failed CI run
- Confirm the pipeline recovers after correcting the issue

---

## CI Workflow Architecture

The completed workflow is:

```text
Git push / Pull Request
        |
        v
GitHub Actions
        |
        v
Temporary Ubuntu Runner
        |
        v
Checkout Repository
        |
        v
Install Terraform
        |
        v
terraform fmt -check
        |
        v
terraform init -backend=false
        |
        v
terraform validate
        |
        v
PASS / FAIL
```

This moves basic Terraform quality validation away from a manual-only process.

---

## GitHub Actions Mental Model

The core GitHub Actions components can be understood as:

```text
Workflow
= automation recipe

Trigger
= event that starts the workflow

Runner
= temporary machine that performs the work

Job
= group of related work

Step
= individual action or command
```

When the workflow is triggered, GitHub creates a temporary runner, executes the configured job, and removes the runner after completion.

---

## Workflow Location

GitHub Actions workflows are stored beneath:

```text
.github/workflows/
```

The Terraform validation workflow was created as:

```text
.github/workflows/terraform-checks.yml
```

---

## Workflow Triggers

The workflow was configured to run on:

```text
Pushes to main
Pushes to the Lab 16 feature branch
Pull requests targeting main
```

This allowed the workflow to be tested before merging it into the primary branch.

Conceptually:

```text
Code change
    |
    v
Push or Pull Request
    |
    v
GitHub Actions workflow triggered
```

---

## GitHub Runner

The workflow uses:

```yaml
runs-on: ubuntu-latest
```

This instructs GitHub to create a temporary Ubuntu-based runner.

The runner is separate from:

```text
The local Linux Mint workstation
The AWS EC2 homelab instance
```

The runner exists only long enough to perform the CI checks.

---

## Repository Checkout

The workflow uses:

```yaml
uses: actions/checkout@v4
```

This copies the repository onto the temporary runner.

Without this step, the runner would exist but would not contain the project files needed for validation.

---

## Terraform Setup

Terraform is installed on the GitHub runner using:

```yaml
uses: hashicorp/setup-terraform@v3
```

This prepares the temporary runner to execute Terraform commands against the repository.

---

## Working Directory

The repository root does not contain the Terraform root configuration.

The Terraform root module is located at:

```text
terraform/aws/homelab
```

The workflow therefore defines:

```yaml
defaults:
  run:
    working-directory: terraform/aws/homelab
```

This ensures that Terraform commands execute from the correct directory.

This prevents errors such as:

```text
No configuration files
```

that occur when Terraform commands are executed from the Git repository root.

---

## Terraform Formatting Check

Locally, formatting can be corrected using:

```bash
terraform fmt
```

However, CI should generally validate code rather than silently modify it.

The workflow therefore uses:

```bash
terraform fmt -check -recursive ..
```

The distinction is:

```text
terraform fmt
= modify files to correct formatting

terraform fmt -check
= verify formatting and fail if incorrect
```

This makes formatting a CI quality gate.

---

## Terraform Initialization

The workflow uses:

```bash
terraform init -backend=false
```

The production Terraform configuration normally uses a remote S3 backend.

For this lab, CI only needs to validate configuration.

Using:

```text
-backend=false
```

allows Terraform to initialize the working directory without attempting to connect to the production remote-state backend.

This avoids requiring AWS credentials during the basic validation workflow.

---

## Terraform Validation

After initialization, the workflow runs:

```bash
terraform validate
```

This checks the Terraform configuration for structural and internal consistency.

The CI pipeline therefore validates both:

```text
Formatting quality
Configuration validity
```

before changes are merged.

---

## Initial Workflow Validation

After the workflow was committed and pushed to the Lab 16 feature branch, GitHub Actions automatically triggered the CI run.

The following steps completed successfully:

```text
Checkout repository        ✓
Setup Terraform            ✓
Terraform formatting       ✓
Terraform initialization   ✓
Terraform validation       ✓
```

This confirmed that the CI workflow could successfully validate the existing Terraform configuration.

---

## Intentional Failure Test

The pipeline was deliberately tested by introducing a harmless Terraform formatting defect.

For example:

```hcl
threshold=80
```

was used instead of:

```hcl
threshold = 80
```

The improperly formatted Terraform file was committed and pushed without running:

```bash
terraform fmt
```

The GitHub Actions workflow then failed during:

```text
Check Terraform formatting
```

This proved that the formatting gate was actively validating the repository rather than merely executing without meaningful enforcement.

---

## Fix and Recovery Test

After confirming the expected failure, Terraform formatting was corrected locally using:

```bash
terraform fmt -recursive ..
```

The corrected file was committed and pushed again.

The next GitHub Actions run completed successfully.

The validated lifecycle was:

```text
Correct code
    |
    v
PASS

Intentional formatting defect
    |
    v
FAIL

Formatting corrected
    |
    v
PASS
```

This demonstrated that the CI workflow could both detect and recover from a quality failure.

---

## Why Intentional Failure Testing Matters

A pipeline that only produces successful runs has not necessarily proven that its quality gates actually work.

The deliberate failure test confirmed that:

```text
The workflow runs automatically
The formatting check is meaningful
The pipeline stops on failure
A corrected commit returns the workflow to green
```

This provides stronger validation than simply observing a successful initial run.

---

## Security Considerations

No AWS credentials were added to GitHub for this lab.

The workflow performs:

```text
Formatting checks
Terraform initialization without backend access
Terraform validation
```

It does not:

```text
Read remote Terraform state
Generate an AWS-aware Terraform plan
Modify AWS resources
Run terraform apply
```

This intentionally limits the CI workflow's permissions and scope.

AWS authentication will be introduced later when the pipeline requires access to live infrastructure.

---

## Problems Encountered

### Terraform Working Directory

Terraform commands must run from the root Terraform module.

The workflow avoids previous working-directory mistakes by explicitly defining:

```text
terraform/aws/homelab
```

as the default working directory.

---

### CI vs Local Formatting

A key distinction was reinforced between:

```text
terraform fmt
```

and:

```text
terraform fmt -check
```

The first changes code.

The second verifies code.

For CI, verification is preferable because automation should report the defect rather than silently rewrite repository files.

---

## Validation

The final Lab 16 workflow was validated through:

```text
Initial workflow execution          ✓
Repository checkout                 ✓
Terraform installation              ✓
Formatting validation               ✓
Terraform initialization            ✓
Terraform configuration validation  ✓
Intentional formatting failure      ✓
Expected CI failure observed         ✓
Formatting corrected                ✓
CI returned to passing state         ✓
No AWS credentials required          ✓
```

---

## Key Concepts Learned

```text
Continuous Integration
GitHub Actions
Workflow YAML
Workflow triggers
GitHub runners
Jobs
Steps
Reusable actions
Repository checkout
Terraform CI
terraform fmt -check
terraform init -backend=false
terraform validate
Quality gates
Fail-fast automation
CI failure testing
Least-privilege CI design
```

---

## Interview-Ready Explanation

> I implemented a GitHub Actions CI workflow for my Terraform infrastructure project. The workflow automatically checks Terraform formatting, initializes the configuration without connecting to the production backend, and runs Terraform validation on pushes and pull requests. I also deliberately introduced a formatting defect to verify that the quality gate failed as expected, then corrected the code and confirmed the pipeline returned to a passing state.

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Implemented a GitHub Actions continuous-integration workflow for Terraform infrastructure code. Automated formatting checks, backend-independent initialization, and configuration validation on repository changes, then deliberately introduced and corrected a formatting defect to verify the CI quality gate could detect and recover from invalid code.

---

# Result

The infrastructure repository now has an automated Terraform quality gate.

The progression is:

```text
Code change
    |
    v
Git push / Pull Request
    |
    v
GitHub Actions
    |
    v
Terraform formatting check
    |
    v
Terraform initialization
    |
    v
Terraform validation
    |
    v
PASS / FAIL
```

Terraform quality validation is no longer dependent exclusively on manual local checks.

This establishes the foundation for more advanced CI/CD work in the next labs.
