# Lab 11 — Reusable Terraform Modules

## Overview

In this lab, the existing AWS Terraform configuration was refactored from a mostly monolithic root module into a modular architecture composed of reusable networking, security, and compute child modules.

The goal was not simply to reorganize files.

The goal was to preserve the behavior of the existing infrastructure while introducing clear module boundaries, reusable inputs and outputs, and cleaner separation of responsibilities.

The refactored environment successfully deployed the same AWS infrastructure, preserved application availability, and maintained the security controls implemented during Lab 10.

---

## Objectives

The objectives of this lab were to:

- Understand the difference between a Terraform root module and child modules
- Refactor existing infrastructure without changing its intended behavior
- Separate networking, security, and compute responsibilities
- Define reusable module input variables
- Define module outputs
- Compose multiple modules from a root module
- Pass data between modules through explicit interfaces
- Preserve the existing Terraform root outputs
- Validate and deploy the modularized infrastructure
- Verify the existing security-hardening baseline after refactoring
- Observe how Terraform state addresses change when resources are moved into modules

---

# Starting Architecture

Before this lab, the Terraform AWS homelab was primarily managed through the root module:

```text
terraform/aws/homelab/
├── main.tf
├── outputs.tf
├── variables.tf
├── versions.tf
└── user-data.sh
```

The root configuration directly defined infrastructure resources such as:

- VPC
- Public subnet
- Private subnet
- Internet Gateway
- Public route table
- Route table association
- Security group
- EC2 instance
- Ubuntu AMI data source

This worked correctly, but the root module was responsible for nearly every layer of the infrastructure.

Conceptually:

```text
Root Module
│
├── Networking
│   ├── VPC
│   ├── Subnets
│   ├── Internet Gateway
│   └── Routing
│
├── Security
│   └── Security Group
│
└── Compute
    ├── Ubuntu AMI Lookup
    └── EC2 Instance
```

As the environment grows, keeping all infrastructure definitions inside one root module becomes harder to reuse, maintain, and reason about.

---

# Final Architecture

The Terraform implementation was reorganized into:

```text
terraform/aws/
├── homelab/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── user-data.sh
│
└── modules/
    ├── networking/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── security/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── compute/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The root module now primarily acts as the orchestration layer.

Its `main.tf` is:

```hcl
module "networking" {
  source = "../modules/networking"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "security" {
  source = "../modules/security"

  vpc_id     = module.networking.vpc_id
  admin_cidr = var.admin_cidr
}

module "compute" {
  source = "../modules/compute"

  subnet_id         = module.networking.public_subnet_id
  security_group_id = module.security.security_group_id
  user_data         = file("${path.module}/user-data.sh")
}
```

This makes the root module responsible for connecting infrastructure components rather than implementing every individual resource.

---

# Root Module vs Child Modules

One of the primary concepts practiced in this lab was the difference between a root module and a child module.

## Root Module

The root module is the Terraform configuration directly executed with commands such as:

```bash
terraform plan
terraform apply
terraform destroy
```

In this repository, the root module is:

```text
terraform/aws/homelab/
```

Its responsibility is now primarily infrastructure composition.

---

## Child Modules

Child modules are reusable Terraform configurations called by another module.

The child modules created in this lab are:

```text
terraform/aws/modules/networking/
terraform/aws/modules/security/
terraform/aws/modules/compute/
```

Each module owns a specific responsibility and exposes only the information required by other parts of the infrastructure.

---

# Module Design Principle

A major design principle used throughout this lab was:

> A child module should receive the values it needs through variables and expose useful values through outputs.

Modules should not tightly depend on the internal implementation of other modules.

For example, the compute module does not directly reference:

```hcl
module.networking.public_subnet_id
```

Instead, it accepts:

```hcl
variable "subnet_id" {
  type = string
}
```

The root module then supplies:

```hcl
subnet_id = module.networking.public_subnet_id
```

This keeps the compute module reusable.

The compute module only needs to know that it receives a subnet ID.

It does not need to know how that subnet was created.

---

# Networking Module

The networking module manages the foundational AWS network infrastructure.

## Resources

The module contains:

- VPC
- Public subnet
- Private subnet
- Internet Gateway
- Public route table
- Public route table association

Conceptually:

```text
Networking Module
│
├── VPC
│
├── Public Subnet
│
├── Private Subnet
│
├── Internet Gateway
│
└── Public Route Table
    └── Public Subnet Association
```

---

## Networking Inputs

The module accepts:

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the homelab VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone used by the homelab subnets"
  type        = string
}
```

These inputs replaced hardcoded network values inside the child module.

The root module currently supplies the lab defaults:

```text
VPC:               10.20.0.0/16
Public Subnet:     10.20.10.0/24
Private Subnet:    10.20.20.0/24
Availability Zone: us-east-2a
```

---

## Networking Outputs

The networking module exposes:

```hcl
output "vpc_id" {
  value = aws_vpc.homelab.id
}

output "public_subnet_id" {
  value = aws_subnet.public_1.id
}

output "private_subnet_id" {
  value = aws_subnet.private_1.id
}
```

These outputs allow other modules to use the resources without directly reaching into the networking module.

---

# Security Module

The security module manages the EC2 security group.

## Inputs

The module accepts:

```hcl
variable "vpc_id" {
  description = "ID of the VPC where the security group will be created"
  type        = string
}

variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH into the lab EC2 instance"
  type        = string
}
```

The root module connects the networking output to the security input:

```hcl
vpc_id = module.networking.vpc_id
```

The administrative CIDR remains an environment-specific value supplied through the root module.

---

## Security Rules

The security group currently allows:

```text
Inbound:
TCP 22  → Administrator CIDR only
TCP 80  → Internet

Outbound:
All traffic
```

The security group continues to serve as the AWS network-security layer while UFW provides an additional host-level firewall layer.

---

## Security Output

The module exposes:

```hcl
output "security_group_id" {
  value = aws_security_group.web.id
}
```

This value is later consumed by the compute module.

---

# Compute Module

The compute module manages:

- Ubuntu AMI lookup
- EC2 instance

The module receives the infrastructure dependencies it requires rather than directly referencing the networking or security modules.

---

## Compute Inputs

Inputs include:

```hcl
variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type    = string
  default = "homelab-ec2-key"
}

variable "user_data" {
  type = string
}
```

---

## Dependency Injection

The root module supplies:

```hcl
subnet_id         = module.networking.public_subnet_id
security_group_id = module.security.security_group_id
```

This creates the dependency chain:

```text
Networking
   │
   ├── vpc_id
   │     ↓
   │  Security
   │     │
   │     └── security_group_id
   │
   └── public_subnet_id
           │
           ↓
        Compute
```

The root module acts as the composition layer between independent child modules.

---

# Passing User Data Into the Compute Module

The EC2 bootstrap script remains in:

```text
terraform/aws/homelab/user-data.sh
```

Originally, the compute module attempted to use:

```hcl
file("${path.module}/user-data.sh")
```

However, inside the compute module:

```text
path.module
```

points to:

```text
terraform/aws/modules/compute/
```

There is no `user-data.sh` file in that directory.

The better design was to read the file from the root module:

```hcl
user_data = file("${path.module}/user-data.sh")
```

and pass its contents into the compute module.

The compute module then uses:

```hcl
user_data = var.user_data
```

The resulting flow is:

```text
homelab/user-data.sh
        │
        ↓
root file()
        │
        ↓
module.compute.user_data
        │
        ↓
var.user_data
        │
        ↓
aws_instance.web
```

This keeps the compute module independent from the filesystem layout of the calling configuration.

---

# Root Outputs

The root module continues to expose useful infrastructure information.

Examples include:

```text
vpc_id
public_subnet_id
private_subnet_id
security_group_id
instance_id
instance_public_ip
instance_private_ip
app1_url
app2_url
```

Previously these outputs referenced raw resources directly.

For example:

```hcl
value = aws_instance.web.public_ip
```

After modularization they reference child-module outputs:

```hcl
value = module.compute.public_ip
```

This demonstrates an important architectural pattern:

```text
AWS Resource
    ↓
Child Module Output
    ↓
Root Module Output
    ↓
User / Automation
```

The implementation changed while the useful external interface remained largely the same.

---

# Terraform State After Modularization

After deployment, the Terraform state contained:

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

This clearly shows the new resource hierarchy.

Previously, resources existed directly under the root module with addresses similar to:

```text
aws_vpc.homelab
aws_subnet.public_1
aws_security_group.web
aws_instance.web
```

After the refactor, their module ownership is visible directly in state:

```text
module.networking.aws_vpc.homelab
module.security.aws_security_group.web
module.compute.aws_instance.web
```

This reinforces that module structure is not merely a directory layout.

Terraform incorporates the module hierarchy into its resource addressing model.

---

# Why No State Migration Was Required

Before beginning this refactor, the Terraform-managed AWS environment had already been destroyed.

The local Terraform state contained no managed resources.

Because no live Terraform-managed infrastructure existed during the refactor, there was no need to perform state migration operations such as:

```text
terraform state mv
```

or Terraform `moved` blocks.

The modular configuration was able to create the environment from scratch.

If the resources had still existed in state, changing addresses from:

```text
aws_vpc.homelab
```

to:

```text
module.networking.aws_vpc.homelab
```

would require deliberate state migration to prevent Terraform from interpreting the change as destroying one resource and creating another.

This will be important knowledge for future production-style refactors.

---

# Deployment Validation

The modular configuration successfully passed:

```bash
terraform validate
```

with:

```text
Success! The configuration is valid.
```

A Terraform plan produced:

```text
Plan: 8 to add, 0 to change, 0 to destroy.
```

The planned managed resources consisted of:

```text
Networking:
- VPC
- Public subnet
- Private subnet
- Internet Gateway
- Public route table
- Route table association

Security:
- Security group

Compute:
- EC2 instance
```

The Ubuntu AMI is retrieved through a data source and therefore is not counted as a managed resource to create.

Terraform successfully applied the modular infrastructure.

---

# Application Validation

After deployment, both applications were successfully reachable through the EC2 public address:

```text
http://<PUBLIC-IP>/app1/
http://<PUBLIC-IP>/app2/
```

The application stack remained operational after the Terraform refactor.

This confirmed that:

- Public subnet configuration remained functional
- Internet Gateway routing remained functional
- Security group rules remained functional
- EC2 placement remained correct
- Cloud-init executed
- Docker installed correctly
- Docker Compose successfully launched the application stack
- Nginx routing remained functional

---

# Security Regression Testing

Refactoring infrastructure should not weaken existing security controls.

After deploying the modular version, the Lab 10 security baseline was revalidated.

---

## Cloud-Init

Verified:

```bash
cloud-init status
```

Result:

```text
status: done
```

---

## Container Status

Verified:

```bash
sudo docker ps
```

The expected containers were running:

```text
reverse-proxy
app1
app2
```

---

## SSH Hardening

Effective SSH configuration was reviewed using:

```bash
sudo sshd -T
```

The following controls remained active:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
```

---

## Host Firewall

UFW remained enabled with:

```text
Default incoming: deny
Default outgoing: allow
```

Required access remained available for:

```text
TCP 22
TCP 80
```

AWS Security Groups continued to restrict SSH access to the administrator CIDR.

---

## Automatic Updates

The unattended-upgrades service remained active after deployment.

This confirmed that the patch-management controls added during Lab 10 continued to be reproduced automatically.

---

## Docker Hardening

Container security configuration remained active.

The containers continued to use:

```text
no-new-privileges:true
```

This confirmed that moving infrastructure into Terraform modules did not alter the existing container security baseline.

---

# Problems Encountered

Several useful Terraform errors occurred during the refactor.

These provided practical experience diagnosing module boundaries.

---

## 1. Literal Strings vs Terraform Expressions

An input was initially written as:

```hcl
cidr_block = "var.vpc_cidr"
```

Terraform interpreted this as the literal string:

```text
var.vpc_cidr
```

rather than evaluating the variable.

This resulted in an invalid CIDR error.

The correct expression was:

```hcl
cidr_block = var.vpc_cidr
```

### Lesson

Quoted values are strings.

Terraform expressions such as:

```hcl
var.example
module.example.output
aws_resource.example.id
```

must not be wrapped in quotes unless interpolation into a larger string is intended.

---

## 2. Root Module Referencing Resources That Had Moved

After moving resources into child modules, the root outputs still referenced:

```hcl
aws_vpc.homelab.id
aws_subnet.public_1.id
aws_instance.web.id
```

Terraform returned errors because those resources no longer existed in the root module.

They were replaced with child-module outputs:

```hcl
module.networking.vpc_id
module.networking.public_subnet_id
module.compute.instance_id
```

### Lesson

Once a resource moves into a child module, the root module cannot reference it as though it were still local.

The child module must explicitly expose required values.

---

## 3. Child Module Attempting to Reference Other Root Modules

The compute module initially contained references similar to:

```hcl
module.networking.public_subnet_id
module.security.security_group_id
```

Terraform returned:

```text
No module call named "networking" is declared in module.compute.
```

and:

```text
No module call named "security" is declared in module.compute.
```

The compute module was changed to accept:

```hcl
var.subnet_id
var.security_group_id
```

The root module now supplies those values.

### Lesson

Sibling modules should generally be composed by the parent module rather than reaching directly into one another.

This reduces coupling and improves reusability.

---

## 4. Compute Module Was Accidentally Calling Itself

During the refactor, a:

```hcl
module "compute"
```

block was accidentally placed inside:

```text
modules/compute/main.tf
```

Terraform attempted to resolve a nested module path and returned an unreadable module-directory error.

The compute module call was removed from the child module and retained only inside the root module.

### Lesson

Creating a module directory defines reusable configuration.

A module is instantiated only when another configuration declares:

```hcl
module "name" {
  source = "..."
}
```

For this architecture, the root module is responsible for calling all three child modules.

---

## 5. Incorrect Compute Outputs

The compute child module initially attempted to expose values using references such as:

```hcl
module.compute.public_ip
```

There was also a typo:

```text
moddule.compute.instance_id
```

Inside the compute module, the outputs must reference the resources that the module itself owns:

```hcl
aws_instance.web.id
aws_instance.web.public_ip
aws_instance.web.private_ip
```

The root module then references those outputs as:

```hcl
module.compute.instance_id
module.compute.public_ip
module.compute.private_ip
```

### Lesson

Inside a module:

```text
resource → output
```

Outside the module:

```text
module.output
```

---

## 6. Incorrect `path.module` Location

The compute module initially attempted:

```hcl
file("${path.module}/user-data.sh")
```

Terraform correctly searched:

```text
terraform/aws/modules/compute/user-data.sh
```

but the bootstrap script actually exists at:

```text
terraform/aws/homelab/user-data.sh
```

The root module now loads the file and passes its contents into the compute module.

### Lesson

`path.module` refers to the directory of the module in which the expression is evaluated.

Modules should preferably receive external data through input variables instead of making assumptions about the calling directory structure.

---

## 7. Expired AWS Authentication Session

Terraform validation succeeded, but the first plan attempt failed with:

```text
No valid credential sources found
```

The AWS CLI login session had expired.

Authentication was refreshed using the existing `lab-admin` AWS CLI profile.

After reauthentication:

```bash
aws sts get-caller-identity --profile lab-admin
```

successfully verified access.

Terraform planning then succeeded.

### Lesson

`terraform validate` checks the configuration without necessarily requiring live cloud-provider authentication.

`terraform plan` requires the AWS provider to authenticate and query live AWS APIs.

---

# Key Concepts Learned

## Terraform Modules

Modules allow related infrastructure resources to be packaged together behind clear interfaces.

---

## Module Inputs

Input variables allow configuration values and dependencies to be passed into a module.

Example:

```hcl
variable "subnet_id" {
  type = string
}
```

---

## Module Outputs

Outputs expose useful values from a child module.

Example:

```hcl
output "public_subnet_id" {
  value = aws_subnet.public_1.id
}
```

---

## Module Composition

The root module connects child modules together.

Example:

```text
Networking Output
      ↓
Security Input

Networking Output
      ↓
Compute Input

Security Output
      ↓
Compute Input
```

---

## Separation of Concerns

Each module now has a clearly defined responsibility:

```text
Networking Module
→ Network architecture

Security Module
→ Network access controls

Compute Module
→ EC2 workload
```

---

## Loose Coupling

The compute module does not care whether the subnet was created by:

- Terraform
- another module
- an existing AWS environment
- another infrastructure system

It only requires:

```text
subnet_id
```

This improves module reuse.

---

## Infrastructure Interfaces

The modules behave similarly to software components.

They have:

```text
Inputs
↓
Implementation
↓
Outputs
```

This makes infrastructure easier to compose and reason about.

---

## Resource Addressing

Terraform resource addresses reflect module hierarchy.

Example:

```text
module.networking.aws_vpc.homelab
```

This communicates both the resource and the module responsible for it.

---

## Refactoring vs Rebuilding

Because the infrastructure was already destroyed before the module refactor, the environment could be recreated without state migration.

A similar refactor against live infrastructure would require careful state-management techniques.

---

# Skills Practiced

This lab provided hands-on practice with:

## Terraform

- Root modules
- Child modules
- Local module sources
- Input variables
- Outputs
- Module composition
- Terraform resource addressing
- `terraform init`
- `terraform fmt`
- `terraform validate`
- `terraform plan`
- `terraform apply`
- `terraform state list`

## AWS

- VPC architecture
- Subnets
- Internet Gateway
- Route tables
- Security Groups
- EC2
- AMI data sources

## Infrastructure Architecture

- Separation of concerns
- Dependency injection
- Infrastructure interfaces
- Reusable component design
- Loose coupling

## Linux / Automation

- Cloud-init
- Bootstrap scripting
- SSH administration
- Service validation

## Security

- Security regression testing
- SSH hardening
- Host firewall validation
- Automated patch controls
- Container privilege hardening
- Defense in depth

## Troubleshooting

- Terraform reference errors
- Module scope errors
- Path resolution errors
- Invalid variable expressions
- Authentication-session failures
- Dependency debugging

---

# Real-World Relevance

Terraform modules are widely used to standardize cloud infrastructure across:

- Cloud engineering teams
- DevOps teams
- Platform engineering teams
- Security engineering teams
- Enterprise cloud environments

Instead of repeatedly defining raw resources, teams can create reusable building blocks.

For example:

```text
modules/
├── vpc/
├── security-group/
├── ec2/
├── database/
└── load-balancer/
```

Applications or environments can then compose those modules according to their requirements.

The concepts practiced in this lab directly relate to:

- Infrastructure as Code engineering
- Cloud platform design
- DevOps
- Cloud security engineering
- Platform engineering
- Terraform module development

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Refactored an AWS Terraform deployment from a monolithic configuration into reusable networking, security, and compute child modules using explicit input/output interfaces. Validated the modular environment through a full Terraform deployment, application testing, Terraform state inspection, and regression testing of an existing automated Linux and container security baseline.

---

# Result

The AWS homelab is now managed through a modular Terraform architecture.

The root module acts as the system-composition layer while dedicated child modules manage networking, security, and compute infrastructure.

The refactored configuration successfully:

- Validated
- Planned
- Deployed
- Created all expected AWS resources
- Exposed expected Terraform outputs
- Served both containerized applications
- Completed automated cloud-init provisioning
- Preserved SSH hardening
- Preserved UFW firewall rules
- Preserved automatic update configuration
- Preserved Docker `no-new-privileges`
- Produced module-qualified Terraform state addresses

The modularization was completed without sacrificing the behavior or security posture established in earlier labs.

---

# Next Lab

## Lab 12 — Terraform Remote State & Locking

The next phase will move Terraform state away from purely local workstation storage and introduce remote-state protection.

Planned topics include:

- Why Terraform state is sensitive
- Risks of local-only state
- Remote state architecture
- State encryption
- State versioning
- State locking
- Backend initialization and migration
- State recovery concepts
- Protecting Terraform state from accidental modification or disclosure
