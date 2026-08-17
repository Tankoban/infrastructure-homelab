# AWS Foundations & Cloud Infrastructure

**Lab Date:** August 2026  
**Status:** Complete

## Objective

Build and operate a foundational AWS environment using secure identity practices, custom networking, EC2 compute, Docker containerization, and infrastructure monitoring.

The lab extends the existing local Linux and Docker homelab into AWS while focusing on understanding the infrastructure components manually before reproducing them through Infrastructure as Code.

The environment was designed to demonstrate:

- AWS account and identity security
- IAM users, groups, and policies
- Least-privilege authorization
- Temporary AWS CLI authentication
- Custom VPC networking
- Public and private subnet design
- Internet routing
- Security groups
- EC2 deployment
- SSH administration
- Docker and Docker Compose
- Nginx reverse proxying
- Public application deployment
- CloudWatch monitoring
- Infrastructure lifecycle management
- Cost awareness

---

## Environment

### Local Administration Workstation

- Linux Mint Cinnamon
- AWS CLI v2
- OpenSSH client
- Git
- Web browser
- Nmap

### AWS Environment

**Region:** `us-east-2` — Ohio

### Network

| Resource | Configuration |
|---|---|
| VPC | `homelab-vpc` |
| VPC CIDR | `10.10.0.0/16` |
| Public Subnet | `homelab-public-1` |
| Public Subnet CIDR | `10.10.10.0/24` |
| Private Subnet | `homelab-private-1` |
| Private Subnet CIDR | `10.10.20.0/24` |
| Internet Gateway | `homelab-igw` |
| Public Route Table | `homelab-public-rt` |
| Web Security Group | `homelab-web-sg` |

### Compute

- Amazon EC2
- Ubuntu Server 26.04 LTS
- `t3.micro`
- EBS `gp3` root storage
- Public and private IPv4 networking

### Application Stack

- Docker Engine
- Docker Compose v2
- Nginx
- Three-container architecture
- Nginx reverse proxy
- Two backend web applications

---

# Architecture

```text
Linux Mint Workstation
        |
        | AWS CLI / SSH
        |
        v
+---------------------------------------------------+
|                    AWS                            |
|                                                   |
| Region: us-east-2                                 |
|                                                   |
|  +---------------------------------------------+  |
|  | VPC: 10.10.0.0/16                          |  |
|  |                                             |  |
|  |  +---------------------------------------+  |  |
|  |  | Public Subnet: 10.10.10.0/24         |  |  |
|  |  |                                       |  |  |
|  |  |        Ubuntu EC2                    |  |  |
|  |  |        10.10.10.x                    |  |  |
|  |  |             |                         |  |  |
|  |  |             v                         |  |  |
|  |  |         Docker Engine                 |  |  |
|  |  |             |                         |  |  |
|  |  |       Docker Compose                  |  |  |
|  |  |             |                         |  |  |
|  |  |      Nginx Reverse Proxy              |  |  |
|  |  |          /       \                    |  |  |
|  |  |         v         v                   |  |  |
|  |  |       App1       App2                 |  |  |
|  |  +---------------------------------------+  |  |
|  |                                             |  |
|  |  +---------------------------------------+  |  |
|  |  | Private Subnet: 10.10.20.0/24        |  |  |
|  |  |                                       |  |  |
|  |  | No direct Internet route              |  |  |
|  |  +---------------------------------------+  |  |
|  |                                             |  |
|  +---------------------------------------------+  |
|                       |                           |
|                Internet Gateway                   |
+-----------------------|---------------------------+
                        |
                        v
                     Internet
```

---

# Part 1 — AWS Account Security

## Root Account

The AWS root account was secured with multi-factor authentication.

No root access keys were created.

The root identity was reserved for account-level and emergency administrative operations rather than normal AWS administration.

### Meaning

The root user has unrestricted authority over the AWS account.

Using root for routine administration increases the impact of credential compromise.

The operating model therefore became:

```text
Root
 |
 +-- Account ownership
 +-- Emergency access
 +-- Root-only operations
 |
 +-- NOT routine administration
```

---

# Part 2 — IAM Administrative Identity

A separate IAM administrator identity was created:

```text
lab-admin
```

An IAM group was created:

```text
Lab-Administrators
```

The AWS-managed `AdministratorAccess` policy was assigned to the group.

The user was then added to the group:

```text
lab-admin
    |
    v
Lab-Administrators
    |
    v
AdministratorAccess
```

MFA was also enabled for `lab-admin`.

### Meaning

Permissions are preferably assigned through groups or roles rather than individually managing permissions on every user.

This creates a scalable authorization model where access follows job function.

---

# Part 3 — IAM Troubleshooting

During configuration, `lab-admin` received:

```text
Access denied to iam:ListUsers
```

AWS reported:

```text
no identity-based policy allows the action
```

Investigation revealed that `lab-admin` had not successfully been added to the `Lab-Administrators` group.

The issue was corrected by adding the user to the intended group.

### Troubleshooting Process

```text
Access Denied
     |
     v
Identify denied API action
     |
     v
Inspect identity permissions
     |
     v
Inspect group membership
     |
     v
Identify missing relationship
     |
     v
Correct configuration
     |
     v
Retest
```

### Lesson Learned

An identity's name does not determine its privileges.

Authorization is based on the policies AWS evaluates for the requesting principal.

---

# Part 4 — Least-Privilege IAM

A second IAM identity was created for permission testing:

```text
lab-readonly
```

The user was assigned to:

```text
Lab-ReadOnly
```

A custom IAM policy was created:

```text
LabEC2ReadOnly
```

Example policy structure:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEC2ReadOnly",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeImages",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*"
        }
    ]
}
```

This replaced the significantly broader AWS-managed `ReadOnlyAccess` policy for the test identity.

### Meaning

IAM authorization can be understood through several core policy elements:

```text
Effect
    Allow or Deny

Action
    Which AWS API operation?

Resource
    Which AWS resource?

Condition
    Under what circumstances?
```

AWS permissions are implicitly denied unless an applicable policy allows the requested operation.

An applicable explicit deny overrides an allow.

---

# Part 5 — AWS CLI Authentication

AWS CLI v2 was configured on the Linux Mint workstation.

Rather than creating long-lived IAM access keys, CLI access was configured using:

```bash
aws login --profile lab-admin
```

The `SignInLocalDevelopmentAccess` policy was assigned through the administrator group to support this authentication workflow.

The CLI session was verified with:

```bash
aws sts get-caller-identity --profile lab-admin
```

### Meaning

`sts get-caller-identity` provides a reliable way to determine which AWS identity is currently making API requests.

This becomes particularly important when multiple CLI profiles or AWS identities exist.

### Temporary Credential Lifecycle

```text
aws login
    |
    v
Browser Authentication
    |
    v
IAM User + MFA
    |
    v
Temporary Credentials
    |
    v
AWS CLI
    |
    v
AWS APIs
```

Logout behavior was tested using:

```bash
aws logout --profile lab-admin
```

The session was then authenticated again.

No long-lived IAM access keys were created.

---

# Part 6 — VPC Networking

A custom VPC was created:

```text
10.10.0.0/16
```

This provides a private IPv4 address space containing 65,536 addresses before AWS-specific subnet reservations are considered.

The larger VPC range allows the environment to be divided into smaller subnet ranges.

---

## Public Subnet

```text
homelab-public-1
10.10.10.0/24
```

Public IPv4 auto-assignment was enabled.

A `/24` subnet contains 256 IPv4 addresses, with AWS reserving five addresses in each subnet.

---

## Private Subnet

```text
homelab-private-1
10.10.20.0/24
```

Automatic public IPv4 assignment was disabled.

The private subnet did not receive a default route to an Internet Gateway.

---

# Part 7 — Internet Gateway & Routing

An Internet Gateway was created:

```text
homelab-igw
```

and attached to:

```text
homelab-vpc
```

A dedicated public route table was created:

```text
homelab-public-rt
```

with routes conceptually equivalent to:

```text
10.10.0.0/16    local
0.0.0.0/0       homelab-igw
```

The public subnet was explicitly associated with this route table.

### Meaning

A public IPv4 address alone does not make a subnet public.

Internet connectivity requires the combination of:

```text
Public IPv4
      +
Internet Gateway
      +
Route to Internet Gateway
      +
Security policy permitting traffic
```

The private subnet remained associated with routing that did not provide a direct Internet Gateway route.

---

# Part 8 — Security Groups

A security group was created:

```text
homelab-web-sg
```

The web server was configured to permit:

```text
HTTP    TCP/80     0.0.0.0/0
SSH     TCP/22     Administrator public IP /32
```

HTTPS `443` was initially permitted during infrastructure setup but later removed because no HTTPS service was currently listening on the EC2 instance.

### Meaning

A security group permission does not create a listening service.

```text
Firewall allows port
        !=
Application listens on port
```

SSH was deliberately restricted to a single administrative public IPv4 address rather than:

```text
0.0.0.0/0
```

This reduces the network attack surface of the server.

---

# Part 9 — EC2 Deployment

An Ubuntu Server EC2 instance was launched:

```text
homelab-ubuntu-web-01
```

The instance was deployed into:

```text
homelab-vpc
        |
        v
homelab-public-1
```

The instance received:

- A private VPC IPv4 address
- An automatically assigned public IPv4 address
- The `homelab-web-sg` security group

An ED25519 SSH key pair was created:

```text
homelab-ec2-key
```

The private key was stored locally with restrictive permissions:

```bash
chmod 600 ~/.ssh/aws/homelab-ec2-key.pem
```

SSH access was performed with:

```bash
ssh -i ~/.ssh/aws/homelab-ec2-key.pem ubuntu@PUBLIC-IP
```

---

# Part 10 — Linux Administration on EC2

Once connected to EC2, the server was inspected using standard Linux tools:

```bash
hostname
hostname -I
ip addr
ip route
lsb_release -a
uname -r
```

Package management was performed with:

```bash
sudo apt update
sudo apt upgrade
```

The SSH service was inspected using:

```bash
systemctl status ssh
```

and:

```bash
systemctl status ssh --no-pager
```

### Meaning

EC2 does not replace Linux administration.

AWS provides the infrastructure surrounding the operating system.

The same Linux skills used in the local Ubuntu Server environment remained applicable in EC2.

---

# Part 11 — Docker on EC2

Docker was installed from the Ubuntu repositories:

```bash
sudo apt install docker.io -y
```

The service was enabled and started:

```bash
sudo systemctl enable --now docker
```

Docker functionality was validated with:

```bash
sudo docker run hello-world
```

The Ubuntu user was added to the Docker group:

```bash
sudo usermod -aG docker ubuntu
```

A new login session was established before testing Docker without `sudo`.

### Security Consideration

Membership in the Docker group provides highly privileged access to the Docker daemon and is effectively root-equivalent in many standard Docker configurations.

---

# Part 12 — Docker Compose Troubleshooting

The initial environment did not include Docker Compose.

Both:

```bash
docker compose
```

and:

```bash
docker-compose
```

returned command-not-found errors.

Package availability was investigated using:

```bash
apt-cache policy docker.io docker-compose-v2 docker-compose-plugin
```

The server was identified as:

```text
Ubuntu 26.04 LTS
Resolute Raccoon
```

The Ubuntu repositories provided:

```text
docker-compose-v2
```

rather than:

```text
docker-compose-plugin
```

The matching distribution package was installed:

```bash
sudo apt install docker-compose-v2 -y
```

and verified with:

```bash
docker compose version
```

### Lesson Learned

Docker Engine and Docker Compose are separate components.

Package names and installation methods can differ between Linux distributions and software vendor repositories.

Rather than mixing package sources, the existing Ubuntu Docker installation was kept consistent with Ubuntu's matching Compose package.

---

# Part 13 — AWS Application Deployment

A Docker application environment was created:

```text
~/aws-web-lab/
|
+-- app1/
|   +-- index.html
|
+-- app2/
|   +-- index.html
|
+-- nginx/
|   +-- default.conf
|
+-- docker-compose.yml
```

The architecture consisted of three containers:

```text
                  EC2
                   |
             Docker Engine
                   |
             Docker Network
                   |
          +--------+--------+
          |                 |
          v                 |
    Reverse Proxy           |
       Nginx                |
       /   \                |
      v     v               |
    App1   App2             |
```

Only the reverse proxy published a host port.

The backend application containers remained accessible only through Docker's internal network.

---

# Part 14 — Nginx Reverse Proxy

Because public DNS had not yet been configured, the AWS deployment initially used path-based routing.

```text
http://PUBLIC-IP/app1/
http://PUBLIC-IP/app2/
```

Nginx configuration:

```nginx
server {
    listen 80;
    server_name _;

    location /app1/ {
        proxy_pass http://app1/;
    }

    location /app2/ {
        proxy_pass http://app2/;
    }
}
```

This allowed the reverse proxy to route incoming requests to the correct backend container using Docker service discovery.

---

# Part 15 — Docker Compose Application Stack

The application stack was defined declaratively using Docker Compose.

```yaml
services:
  reverse-proxy:
    image: nginx
    container_name: aws-reverse-proxy
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app1
      - app2

  app1:
    image: nginx
    container_name: aws-app1
    restart: unless-stopped
    volumes:
      - ./app1:/usr/share/nginx/html:ro

  app2:
    image: nginx
    container_name: aws-app2
    restart: unless-stopped
    volumes:
      - ./app2:/usr/share/nginx/html:ro
```

Configuration was validated before deployment:

```bash
docker compose config
```

The stack was launched:

```bash
docker compose up -d
```

Nginx configuration was validated:

```bash
docker exec aws-reverse-proxy nginx -t
```

---

# Part 16 — Layered Application Testing

The application was tested from inside EC2 first:

```bash
curl http://localhost/app1/
curl http://localhost/app2/
```

It was then tested remotely from Linux Mint:

```bash
curl http://PUBLIC-IP/app1/
curl http://PUBLIC-IP/app2/
```

Finally, both routes were tested through a web browser.

### Troubleshooting Model

Testing proceeded from the inside outward:

```text
Application
     |
Docker
     |
Nginx
     |
EC2
     |
Security Group
     |
Subnet
     |
Route Table
     |
Internet Gateway
     |
Internet
     |
Client
```

If local requests succeeded but external requests failed, investigation could focus on AWS networking rather than the application itself.

---

# Part 17 — Multiple Networking Layers

Docker container addresses were inspected using:

```bash
docker inspect aws-app1 \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

The environment therefore contained several distinct network scopes:

```text
Internet
   |
Public AWS IPv4
   |
-------------------------
AWS VPC
   |
10.10.10.x
   |
-------------------------
Docker Network
   |
172.x.x.x
   |
+------+------+
|             |
App1         App2
```

### Meaning

The public IP, VPC private IP, and Docker container IPs belong to different networking layers.

Understanding these boundaries is essential when troubleshooting cloud-hosted container applications.

---

# Part 18 — Observability

Infrastructure and application health were inspected at multiple layers.

## AWS Layer

Amazon CloudWatch metrics were reviewed for:

- CPU utilization
- Network traffic
- EC2 status checks
- EBS activity

Test HTTP traffic was generated to observe network activity.

## Linux Layer

```bash
free -h
df -h
uptime
```

were used to inspect host resources.

## Docker Layer

```bash
docker stats
```

provided live container resource usage.

Application logs were inspected using:

```bash
docker logs aws-reverse-proxy --tail 30
```

and monitored live using:

```bash
docker logs -f aws-reverse-proxy
```

### Meaning

Observability exists at multiple infrastructure layers:

```text
CloudWatch
    |
Cloud infrastructure

Linux tools
    |
Operating system

Docker tools
    |
Containers/application
```

No single monitoring layer provides complete visibility into the entire stack.

---

# Part 19 — Security Validation

The public EC2 address was scanned from the administrator workstation using Nmap.

This was used to compare:

```text
AWS Security Group Rules
        |
        v
Actual externally reachable services
```

The exercise reinforced that:

```text
Allowed firewall port
        !=
Listening application
```

Unused HTTPS access was removed until a TLS-enabled service is deployed.

---

# Part 20 — Cost Awareness

The AWS Billing and Cost Management dashboard was reviewed to monitor:

- Remaining AWS credits
- Current usage
- EC2 consumption
- EBS storage
- Public IPv4 usage

The environment intentionally avoided unnecessary infrastructure such as a NAT Gateway during the foundational networking exercise.

### Meaning

Cloud infrastructure introduces consumption-based resource management.

Technical design decisions can therefore affect both:

```text
Security
Performance
Availability
Cost
```

Cost awareness is part of cloud engineering rather than a separate administrative concern.

---

# Part 21 — EC2 Stop/Start Lifecycle

The EC2 instance was deliberately stopped.

Public application access became unavailable as expected.

The instance was then restarted.

The automatically assigned public IPv4 address was checked after restart before reconnecting.

Docker had been configured to start automatically:

```bash
sudo systemctl enable docker
```

and the application containers used:

```yaml
restart: unless-stopped
```

After EC2 restarted, Docker and the application stack recovered automatically.

### Meaning

A stopped EC2 instance preserves its persistent storage while compute execution stops.

Stopping is different from terminating:

```text
STOP
 |
 +-- Instance preserved
 +-- EBS retained
 +-- Can restart

TERMINATE
 |
 +-- Instance destroyed
 +-- Root storage may be deleted
 +-- Rebuild required
```

This lifecycle behavior becomes particularly important when Infrastructure as Code is introduced.

---

# Key Concepts Learned

## AWS Identity

- Root account security
- Multi-factor authentication
- IAM users
- IAM groups
- AWS-managed policies
- Custom IAM policies
- Least privilege
- Implicit deny
- Explicit deny
- Temporary CLI authentication
- AWS CLI profiles
- STS caller identity

## Networking

- VPCs
- CIDR notation
- Public subnets
- Private subnets
- Route tables
- Local VPC routes
- Default routes
- Internet Gateways
- Public IPv4 addresses
- Private IPv4 addresses
- Security groups
- `/32` host addressing
- Network segmentation

## Compute

- EC2
- AMIs
- Instance types
- EBS
- SSH key pairs
- Linux cloud administration
- Instance lifecycle management

## Containers

- Docker Engine
- Docker Compose
- Docker networking
- Nginx
- Reverse proxying
- Bind mounts
- Restart policies
- Container logging
- Container resource monitoring

## Operations

- CloudWatch
- Layered troubleshooting
- Service recovery
- Attack-surface review
- Cost monitoring
- Infrastructure lifecycle management

---

# Problems Encountered

## IAM Group Membership

`lab-admin` initially lacked expected IAM permissions.

### Cause

The user had not successfully been added to the `Lab-Administrators` group.

### Resolution

Group membership was corrected and permissions were retested.

---

## Docker Compose Missing

Docker Engine was installed successfully, but Docker Compose was unavailable.

### Cause

Docker Engine and Compose were packaged separately in Ubuntu 26.04.

The environment used Ubuntu's `docker.io` package rather than Docker's vendor repository.

### Resolution

Package availability was inspected and the matching Ubuntu package was installed:

```bash
sudo apt install docker-compose-v2
```

---

## systemctl Pager Confusion

After checking:

```bash
systemctl status ssh
```

the command prompt had already returned.

Entering:

```text
q
```

therefore caused Bash to attempt to execute a command named `q`.

### Lesson

`q` exits the pager only while the pager is active.

The command:

```bash
systemctl status ssh --no-pager
```

can be used when pager behavior is unnecessary.

---

# Security Considerations

The lab incorporated several security controls:

- MFA on the AWS root identity
- MFA on the administrative IAM identity
- No root access keys
- No long-lived IAM access keys for CLI administration
- Group-based administrative permissions
- Custom least-privilege IAM policy testing
- SSH restricted to an administrator `/32`
- Private SSH key permissions restricted with `chmod 600`
- Backend containers not directly exposed publicly
- Read-only Docker configuration mounts
- Unused inbound ports removed
- Public exposure validated through network scanning
- Root AWS identity excluded from routine administration

---

# Lessons Learned

1. Cloud infrastructure depends heavily on foundational Linux and networking knowledge.

2. AWS authorization is determined by effective policies, not identity names or intended roles.

3. Group-based permission management provides a cleaner model than individually assigning user permissions.

4. Least privilege requires defining the specific operations an identity actually needs.

5. Temporary credentials reduce dependence on persistent access keys.

6. A public IP alone does not make a workload Internet-accessible.

7. Public connectivity requires coordinated addressing, routing, gateway, firewall, and application configuration.

8. Cloud networking and Docker networking create separate layers that must be understood independently.

9. Testing from the application outward helps isolate failures efficiently.

10. Security group permissions and application listeners represent separate controls.

11. Cloud observability requires visibility across infrastructure, operating-system, and application layers.

12. Package availability should be investigated before mixing software repositories or installation methods.

13. Restart policies and service startup configuration improve recovery after infrastructure restarts.

14. Cloud cost is influenced by architecture and resource lifecycle decisions.

15. Manually understanding infrastructure is valuable before automating it.

---

# Local Infrastructure vs AWS

| Local Homelab | AWS |
|---|---|
| Ubuntu Server VM | EC2 |
| KVM/QEMU | AWS virtualization platform |
| Virtual disk | EBS |
| Virtual NIC | ENI |
| Home network | VPC |
| LAN subnet | VPC subnet |
| Router/gateway | Route table + Internet Gateway |
| Host/network firewall | Security Group |
| Private LAN IP | VPC private IPv4 |
| SSH | SSH |
| Docker Engine | Docker Engine |
| Docker Compose | Docker Compose |
| Nginx reverse proxy | Nginx reverse proxy |
| Local application | Public cloud application |

The transition demonstrated that AWS does not replace foundational infrastructure concepts.

It provides programmable cloud implementations of many of the same concepts.

---

# Real-World Application

The skills demonstrated in this lab map directly to responsibilities found across:

- Cloud Engineering
- Cloud Security
- Systems Administration
- DevOps
- Platform Engineering
- Infrastructure Engineering
- Security Engineering

The environment demonstrates the ability to:

- Secure an AWS account
- Manage IAM authorization
- Apply least-privilege concepts
- Authenticate to AWS programmatically
- Design IPv4 cloud networks
- Segment public and private resources
- Configure Internet routing
- Control network access
- Deploy Linux cloud compute
- Secure SSH administration
- Deploy containerized applications
- Configure reverse proxy routing
- Troubleshoot across infrastructure layers
- Monitor cloud resources
- Evaluate external exposure
- Manage cloud resource lifecycle and cost

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Designed and manually deployed an AWS cloud application environment using IAM, VPC networking, public and private subnets, Internet Gateway routing, Security Groups, EC2, Docker, and CloudWatch. Implemented MFA-protected administrative access, temporary AWS CLI authentication, least-privilege read-only IAM testing, containerized application hosting, and cloud infrastructure lifecycle validation.

---

# Next Steps

The next phase will introduce Infrastructure as Code using Terraform.

The manually constructed AWS environment will serve as the reference architecture for reproducing resources including:

```text
VPC
Subnets
Internet Gateway
Route Tables
Security Groups
EC2
```

The objective will shift from:

```text
I can build the infrastructure manually.
```

to:

```text
I can define, version, reproduce, modify, and destroy the infrastructure as code.
```
