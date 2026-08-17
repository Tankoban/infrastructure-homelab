# Lab 10 — Security Hardening & Automation

**Lab Date:** August 2026
**Status:** Complete
**Platform:** AWS EC2 / Ubuntu Server 26.04 LTS
**Provisioning:** Terraform
**Application Platform:** Docker Compose / Nginx

---

## Objective

Harden the Terraform-provisioned AWS infrastructure and Ubuntu application server created in previous labs, validate the resulting security posture, and automate the validated controls so that a replacement EC2 instance can reproduce the hardened configuration without manual intervention.

This lab focused on defense in depth, least privilege, secure remote administration, host firewalling, patch management, container security, secrets hygiene, validation, and infrastructure reproducibility.

---

## Architecture

The application stack uses multiple layers of security controls:

```text
                         Internet
                            |
                            v
                  AWS Security Group
                 /                  \
       SSH 22 from admin /32      HTTP 80
                 \                  /
                  \                /
                         UFW
                  Default Deny Inbound
                    /             \
                  SSH             HTTP
                   |               |
            Key Authentication   Docker
            Root Login Disabled    |
                                   v
                            Nginx Reverse Proxy
                              /           \
                           App1           App2
                      Internal Only   Internal Only
```

The AWS Security Group provides the cloud perimeter control, while UFW provides a second host-level firewall layer.

Only the reverse proxy publishes an application port to the EC2 host. Backend application containers communicate through the internal Docker network.

---

## Security Baseline

Before applying additional controls, the server was audited to establish its existing security posture.

The baseline included:

- Listening TCP/UDP services
- SSH daemon configuration
- Host firewall status
- Available operating system updates
- Automatic update configuration
- Linux users and privileged groups
- Docker socket permissions
- Container privileges and published ports
- Repository and Terraform secrets exposure

Example commands included:

```bash
sudo ss -tulpn
sudo sshd -T
sudo ufw status verbose
apt list --upgradable
systemctl status unattended-upgrades
docker network ls
docker inspect tf-aws-reverse-proxy
```

The audit showed that the Ubuntu AWS image already provided several useful security defaults, including disabled SSH password authentication and enabled unattended upgrades.

Rather than modifying controls unnecessarily, hardening focused on identified gaps.

---

## Before vs. After

| Security Area | Baseline | Hardened State |
|---|---|---|
| SSH password authentication | Disabled | Disabled |
| SSH public-key authentication | Enabled | Enabled |
| Root SSH login | `prohibit-password` | Disabled completely |
| SSH MaxAuthTries | 6 | 3 |
| X11 forwarding | Enabled | Disabled |
| Empty passwords | Disabled | Disabled |
| AWS SSH exposure | Administrator `/32` | Administrator `/32` |
| Host firewall | Inactive | UFW active |
| Default inbound host policy | No UFW policy | Deny |
| HTTP exposure | TCP/80 | TCP/80 only |
| Docker access | User temporarily in Docker group | Requires sudo |
| Container privileged mode | Disabled | Disabled |
| Container privilege escalation | Default | `no-new-privileges` |
| Backend container host ports | None | None |
| Automatic security updates | Enabled | Explicitly enabled |
| Pending system patches | Present | Patched |
| AWS credentials on EC2 | None | None |
| Terraform state in Git | Excluded | Excluded |
| Terraform variable file in Git | Excluded | Excluded |
| SSH private key in Git | Excluded | Excluded |
| Hardening deployment | Manual | Automated |

---

## SSH Hardening

A dedicated OpenSSH configuration snippet was created:

```text
/etc/ssh/sshd_config.d/00-homelab-hardening.conf
```

The hardened configuration applies:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
```

The configuration is validated before SSH is reloaded:

```bash
/usr/sbin/sshd -t
systemctl reload ssh
```

### Security Rationale

Direct root login is unnecessary because administration occurs through the `ubuntu` account using SSH public-key authentication and `sudo`.

Reducing authentication attempts decreases unnecessary SSH exposure, while disabling X11 forwarding removes functionality that is not required on a headless application server.

---

## Least Privilege

The administrative account was reviewed for unnecessary group membership and privileges.

During testing, the `ubuntu` account was temporarily added to the `docker` group to allow Docker commands without `sudo`.

Docker group membership was subsequently removed.

The final administrative model is:

```text
ubuntu
   |
   +-- SSH public-key authentication
   |
   +-- sudo
   |    |
   |    +-- privileged administration
   |    +-- Docker administration
   |
   +-- direct Docker socket access: denied
```

Because access to the Docker daemon can provide effectively root-equivalent capabilities on the host, Docker administration intentionally requires `sudo`.

---

## Host Firewall

UFW was configured as a second firewall layer behind the AWS Security Group.

Default policies:

```bash
ufw default deny incoming
ufw default allow outgoing
```

Explicitly permitted services:

```text
22/tcp — SSH administration
80/tcp — Nginx web application
```

UFW is enabled automatically during bootstrap:

```bash
ufw --force enable
```

### Defense in Depth

The resulting network controls are:

```text
Internet
   |
   v
AWS Security Group
   |
   v
UFW
   |
   v
Approved Services
```

The AWS Security Group restricts SSH to the configured administrator CIDR while allowing public HTTP traffic.

UFW independently limits inbound host traffic to the required services.

---

## Patch Management

Available operating system updates were reviewed and installed.

The patch workflow included:

1. Refresh package metadata.
2. Review available upgrades.
3. Apply operating system updates.
4. Determine whether a reboot is required.
5. Reboot when necessary.
6. Revalidate SSH, UFW, Docker, and application functionality.

Automatic security updates were also verified through Ubuntu's `unattended-upgrades` service and APT timers.

The Terraform bootstrap now explicitly installs and enables unattended upgrades.

---

## Docker Security

The Docker deployment was reviewed for:

- Privileged containers
- Published ports
- Linux capabilities
- Host mounts
- Container users
- Docker socket access
- Container security options

No containers operate in privileged mode.

Only the reverse proxy publishes a host port:

```text
tf-aws-reverse-proxy  -> TCP/80
tf-aws-app1           -> Internal only
tf-aws-app2           -> Internal only
```

All containers use:

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents processes inside the containers from gaining additional privileges through mechanisms such as setuid or setgid binaries.

Application content and Nginx configuration are also mounted read-only.

---

## Secrets & Sensitive Data Review

The Git repository, Terraform configuration, EC2 host, and running containers were reviewed for sensitive information.

The review checked for:

- AWS access keys
- AWS secret keys
- Passwords
- API tokens
- Private keys
- Terraform state
- Terraform variable files
- AWS credentials on EC2
- Credentials exposed through container environment variables

Sensitive Terraform artifacts remain excluded through `.gitignore`, including:

```text
*.tfstate
*.tfstate.*
*.tfvars
.terraform/
```

Private SSH keys and other credential material are not stored in the repository.

The EC2 workload also does not contain the AWS administrative credentials used by the Terraform workstation.

---

## Security Validation

Controls were tested after implementation rather than assumed to be working.

### Positive Tests

The following functionality was expected to succeed:

- SSH public-key authentication
- TCP/22 from the administrator network
- HTTP access on TCP/80
- App1 response
- App2 response
- Docker administration through `sudo`
- Container restart after host reboot

### Negative Tests

The following actions were expected to fail:

- Root SSH authentication
- SSH password authentication
- Direct Docker access by the `ubuntu` account
- Direct host access to backend App1/App2 containers
- Unapproved inbound host traffic

A denied action was treated as a successful security test when denial was the intended policy.

---

## Hardening as Code

The initial security controls were applied manually so that each change could be tested independently.

Once validated, the controls were incorporated into the Terraform EC2 bootstrap script:

```text
terraform/aws/homelab/user-data.sh
```

The automated bootstrap now performs:

```text
EC2 Launch
   |
   v
Update package metadata
   |
   v
Install system patches
   |
   v
Install required packages
   |
   v
Apply SSH hardening
   |
   v
Validate SSH configuration
   |
   v
Configure UFW
   |
   v
Enable automatic updates
   |
   v
Enable Docker
   |
   v
Create application files
   |
   v
Generate hardened Compose configuration
   |
   v
Validate Docker Compose
   |
   v
Deploy application stack
```

Terraform was also configured with:

```hcl
user_data_replace_on_change = true
```

Changes to the instance bootstrap configuration therefore trigger EC2 replacement instead of leaving an existing server running with an outdated initialization state.

---

## Reproducibility Test

The final validation replaced the existing EC2 instance using Terraform.

The replacement instance was allowed to bootstrap without manually applying any security configuration.

After cloud-init completed, the replacement server was tested for:

- SSH hardening
- UFW configuration
- Least-privilege Docker access
- Automatic updates
- Docker container security settings
- Reverse proxy operation
- App1 availability
- App2 availability

All controls and application services were successfully reproduced automatically.

This demonstrated that the hardened server configuration is defined by infrastructure code rather than dependent on undocumented manual changes.

---

## Key Lessons

### Security Begins With a Baseline

Existing controls should be measured before additional configuration is applied. Hardening should address identified risk rather than blindly applying settings from a checklist.

### Defense in Depth

The AWS Security Group and UFW provide separate layers of network control. Failure or misconfiguration of one layer does not automatically eliminate the other.

### Least Privilege Applies to Administrative Tools

Membership in the Docker group provides substantial host-level privilege. Convenience should not override the principle of least privilege.

### Security Controls Must Be Tested

Successful application access alone does not prove that security controls work. Negative tests are necessary to verify that prohibited behavior is actually denied.

### Manual Hardening Is Not Reproducible

A manually secured server becomes technical debt if its configuration cannot be recreated.

Encoding validated controls into the bootstrap process ensures replacement infrastructure begins from the same hardened baseline.

### Infrastructure Replacement Is a Security Capability

Because the server can be recreated automatically, recovery no longer depends on preserving one manually configured EC2 instance.

The infrastructure can be treated as replaceable rather than precious.

---

## Skills Demonstrated

- Linux server administration
- Ubuntu security hardening
- OpenSSH configuration
- Public-key authentication
- Linux users and groups
- Least-privilege administration
- UFW firewall management
- AWS Security Groups
- Defense-in-depth architecture
- Linux patch management
- Automatic security updates
- Docker security
- Docker Compose
- Nginx reverse proxying
- Container network isolation
- Secrets management fundamentals
- Terraform
- EC2 bootstrap automation
- Infrastructure as Code
- Cloud-init troubleshooting
- Security validation
- Negative security testing
- Infrastructure reproducibility

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Hardened an AWS-hosted Linux and Docker environment using layered security controls including SSH hardening, UFW firewall policy, least-privilege administration, automated patching, unattended security updates, container `no-new-privileges`, sensitive-data review, and negative security testing. Converted the validated security baseline into cloud-init automation and reproduced the hardened environment automatically through Terraform instance replacement.

---

## Result

Lab 10 produced a hardened and reproducible AWS application server baseline.

The environment can be replaced through Terraform and automatically returns to the validated security state without manual server configuration.

This establishes a foundation for more advanced cloud-security, observability, identity, automation, and infrastructure engineering work.
