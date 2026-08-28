# Lab 19 — Secret Scanning

## Overview

This lab introduced automated secret scanning into the GitHub Actions CI pipeline using Gitleaks.

The goal was to detect credentials, tokens, private keys, and other sensitive values before they could be merged into the repository.

A key part of this lab was validating the scanner itself. Initial synthetic AWS- and GitHub-style credentials did not reliably trigger the default detection rules, so the workflow was strengthened with an explicit repository-level Gitleaks configuration and a custom sentinel rule.

This provided a known failure condition that could be used to verify that secret scanning actually blocks a commit containing a recognizable test secret.

---

## Objectives

The objectives of this lab were to:

- Integrate Gitleaks into GitHub Actions
- Scan repository contents for secrets automatically
- Understand the difference between secret scanning and IaC security scanning
- Use full Git history during secret analysis
- Configure Gitleaks through a repository-level configuration file
- Preserve default Gitleaks detection rules
- Add a custom synthetic validation rule
- Deliberately introduce a fake secret
- Verify that CI fails when the test secret is detected
- Revert the synthetic secret and confirm CI returns to green
- Avoid using real credentials during testing
- Understand that a passing security tool does not automatically prove the control works

---

## CI Architecture

The Phase VI CI pipeline now includes:

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
Gitleaks Secret Scan
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

Gitleaks provides a separate security layer from Checkov.

---

## Secret Scanning Mental Model

The major validation layers now answer different questions:

```text
terraform validate
= Is the Terraform structurally valid?

Gitleaks
= Did someone commit something that looks like a secret?

Checkov
= Does the infrastructure code violate security policies?

terraform plan
= What infrastructure changes would Terraform make?
```

These controls complement each other rather than performing the same task.

---

## Gitleaks Integration

Gitleaks was added to the GitHub Actions workflow as an automated CI step.

The workflow scans repository contents during pushes and pull requests.

The Git checkout step was configured with:

```yaml
fetch-depth: 0
```

This provides the workflow with full Git history rather than only a shallow copy of the most recent commit.

---

## Initial Validation Attempt

The first intentional secret-scanning test used synthetic AWS-style credentials.

The values were fake and intended only to simulate a credential leak.

However, the Gitleaks workflow remained green.

A second test used a synthetic GitHub-style token.

That test also failed to trigger the expected security gate.

The important result was not that the repository passed.

The result showed that:

```text
Green CI
does not necessarily mean
the detection control has been proven effective
```

---

## Why the Initial Tests Did Not Prove Detection

Secret scanners use:

```text
Patterns
Entropy
Allow lists
Known credential formats
Context
```

Synthetic example credentials may not always satisfy the exact detector logic.

Some example values can also be intentionally excluded to prevent documentation and sample configuration from creating false positives.

Instead of assuming the scanner was functioning correctly, the control itself was tested more directly.

---

## Repository-Level Gitleaks Configuration

A repository-level configuration file was created:

```text
.gitleaks.toml
```

The configuration extends the default Gitleaks rule set:

```toml
[extend]
useDefault = true
```

This means the repository retains Gitleaks' normal detection rules while also supporting project-specific policies.

---

## Custom Sentinel Rule

A custom rule was added specifically for CI validation.

Conceptually:

```text
Known synthetic pattern
        |
        v
Gitleaks custom detector
        |
        v
Known expected failure
```

The rule detects a deliberately artificial pattern beginning with:

```text
TEST_SECRET_DO_NOT_COMMIT=
```

followed by a fixed-length test value.

This value is not a real credential.

The rule exists only to verify that the secret-scanning pipeline is operational.

---

## Intentional Secret Detection Test

A temporary file containing the synthetic sentinel secret was committed to the Lab 19 feature branch.

The GitHub Actions workflow then executed Gitleaks.

This time, Gitleaks correctly:

```text
Detected the test secret
Identified the affected file
Reported the custom rule
Failed the CI workflow
```

The security gate therefore produced the expected failure.

---

## Recovery Test

The synthetic secret commit was reverted.

The following GitHub Actions workflow returned to a passing state.

The validated lifecycle became:

```text
Clean repository
      |
      v
PASS

Synthetic secret committed
      |
      v
Gitleaks FAIL

Secret reverted
      |
      v
PASS
```

No real secret or credential was used during testing.

---

## Security-Control Validation

This lab reinforced an important security-engineering principle:

```text
Installing a security control
is not the same as
validating that the control works.
```

The stronger validation process is:

```text
Implement control
      |
      v
Create known failure condition
      |
      v
Confirm detection
      |
      v
Remove test condition
      |
      v
Confirm recovery
```

This mirrors the failure-testing approach used in previous CI labs.

---

## Default Rules and Custom Rules

The custom sentinel rule does not replace the normal Gitleaks detection library.

The final configuration uses:

```text
Default Gitleaks rules
+
Project-specific validation rule
```

The default rules continue to detect common patterns such as:

```text
API tokens
Cloud credentials
Private keys
Passwords
Service secrets
```

while the sentinel provides a deterministic CI test.

---

## Sensitive Metadata Lesson

During testing, the Gitleaks results exposed Git commit metadata such as the commit author's configured email address.

This highlighted another security and privacy consideration:

```text
Security tools can surface repository metadata
that may itself be sensitive or personally identifying.
```

The Git configuration was updated to use a GitHub-provided `noreply` email address for future commits.

The Lab 19 feature branch history was then rewritten before merge so its commits no longer contained the previous personal email address.

This reinforced the distinction between:

```text
Deleting a workflow artifact
and
removing sensitive metadata from Git history
```

Both may need to be considered depending on what information was exposed.

---

## Problems Encountered

### Workflow Passed Fake AWS Credentials

Symptom:

```text
Synthetic AWS credential test
→ Gitleaks PASS
```

Cause:

```text
The fake values did not reliably match the active default detector behavior.
```

Resolution:

```text
Added a deterministic repository-level sentinel rule.
```

---

### Workflow Passed Fake GitHub Token

A second synthetic test also passed unexpectedly.

This further demonstrated that:

```text
a scanner's green result should not be treated
as proof that a specific detection path works
```

The test methodology was changed rather than blindly trusting the status light.

---

### Custom Sentinel Test

The custom rule successfully produced a CI failure when the known synthetic secret was committed.

This confirmed:

```text
Gitleaks executed
Configuration loaded
Repository scanned
Detection rule evaluated
Non-zero failure produced
CI security gate enforced
```

---

### Commit Email Exposure

The secret-scan output displayed Git commit author metadata.

The repository's Git identity was updated to use a privacy-preserving GitHub `noreply` address.

The unmerged Lab 19 branch was rewritten and force-pushed using the cleaned commit identity before final merge.

---

## Validation

The final Lab 19 implementation validated:

```text
Gitleaks integrated into GitHub Actions        ✓
Full Git history available to scanner          ✓
Default Gitleaks rules retained                ✓
Repository-level config loaded                 ✓
Custom sentinel rule added                     ✓
Initial detector limitations observed          ✓
Known synthetic secret detected                ✓
CI failed on secret detection                  ✓
No real credentials used                       ✓
Synthetic secret reverted                      ✓
CI returned to green                           ✓
Commit email privacy corrected                 ✓
Lab 19 branch history cleaned                  ✓
```

---

## Key Concepts Learned

```text
Secret scanning
Gitleaks
Credential detection
Synthetic security testing
Known failure conditions
Security-control validation
Git history scanning
Custom detection rules
Default rule extension
False negatives
CI security gates
Commit metadata
Git author identity
Privacy-preserving commit email
History rewriting
```

---

## Interview-Ready Explanation

> I integrated Gitleaks into my Terraform GitHub Actions pipeline to detect secrets before merge. I tested the scanner using synthetic credential patterns and discovered that the initial fake AWS and GitHub-style values did not reliably trigger the default detectors. Instead of assuming the scanner worked because the workflow was green, I added a repository-level Gitleaks configuration with a deterministic sentinel rule. I then committed a known synthetic test secret, confirmed the workflow failed, reverted it, and verified the pipeline returned to green. The exercise also exposed commit-author metadata in the scan output, so I updated my Git identity to a GitHub noreply address and cleaned the unmerged branch history before merge.

---

# Portfolio Summary

> Added automated secret scanning to a GitHub Actions infrastructure pipeline using Gitleaks. Extended the default scanner rules with a deterministic CI sentinel, validated detection through an intentional synthetic-secret regression test, corrected commit-email privacy exposure, and verified the pipeline returned to green after remediation.

---

# Result

The CI pipeline now includes automated secret detection before Terraform security scanning and planning.

The completed security-validation flow is:

```text
Code Change
    |
    v
GitHub Actions
    |
    v
Terraform Validation
    |
    v
Gitleaks
    |
    v
Checkov
    |
    v
Terraform Plan
```

The secret-scanning control has been tested against a known failure condition rather than being trusted solely because the workflow reports a passing result.
