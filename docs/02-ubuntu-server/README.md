# Ubuntu Server Administration Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Build and administer an Ubuntu Server virtual machine as the server foundation for a Linux, cloud, and cybersecurity homelab.

The goal of this lab was to move beyond desktop Linux administration and begin working with a headless Linux server through SSH, establishing an environment that could later host containerized applications and infrastructure services.

## Environment

### Host System

* Linux Mint 22.3 Cinnamon
* KVM/QEMU virtualization
* Linux kernel 6.8

### Guest System

* Ubuntu Server
* Hostname: `ubuntu-server-01`
* Headless administration
* OpenSSH Server
* Docker Engine

## Architecture

```text
Linux Mint Workstation
        |
        | KVM/QEMU
        v
Ubuntu Server VM
        |
        | SSH
        v
Remote Terminal Administration
        |
        +--> Docker
        |
        +--> Nginx
        |
        +--> Future Infrastructure Services
```

The Ubuntu Server VM provides an isolated environment where server administration, networking, containerization, security, and cloud-related concepts can be practiced without exposing services directly to the public internet.

---

## Work Completed

### Ubuntu Server Deployment

Created an Ubuntu Server virtual machine using KVM/QEMU on the Linux Mint workstation.

The installation established a dedicated Linux server environment separate from the desktop operating system.

After installation, the installation ISO was detached from the VM so subsequent boots would load directly from the installed operating system.

### Meaning

A virtual machine behaves as an independent computer while sharing the physical resources of the host.

This makes virtualization useful for:

* Server testing
* Development environments
* Security labs
* Infrastructure experimentation
* Operating system testing
* Network simulations

The VM can be modified, broken, rebuilt, or replaced without directly affecting the host workstation.

---

## Remote Administration with SSH

OpenSSH Server was configured on the Ubuntu Server VM.

The server's IP address can be identified with commands such as:

```bash
hostname -I
```

Remote administration was performed from the Linux Mint workstation using:

```bash
ssh tankouban@SERVER-IP
```

Once authenticated, the Ubuntu Server could be managed entirely through the terminal without interacting directly with the VM console.

### Meaning

SSH provides encrypted remote command-line access to another system.

The basic architecture is:

```text
Linux Mint
    |
    | SSH over network
    v
Ubuntu Server
    |
    v
Remote shell
```

This mirrors how Linux servers are commonly administered in production environments.

Cloud virtual machines such as AWS EC2 instances and Azure Virtual Machines are frequently administered using the same general model.

---

## SSH Host Verification

During the initial SSH connection, the client presented the server's host key fingerprint and requested confirmation before establishing trust.

After accepting the fingerprint, the server was added to the local SSH `known_hosts` file.

### Meaning

SSH host keys allow a client to verify the identity of the remote server.

On future connections, SSH compares the presented host key against the previously stored key.

An unexpected change can generate a warning because it may indicate:

* The server was rebuilt
* The server's SSH keys changed
* The IP address now belongs to another system
* A potential man-in-the-middle attack

This is an important part of SSH's trust model.

---

## Linux Service Management

The lab introduced management of background services using `systemd`.

Service status can be checked using:

```bash
systemctl status SERVICE
```

For example:

```bash
systemctl status ssh
```

Common service-management operations include:

```bash
sudo systemctl start SERVICE
sudo systemctl stop SERVICE
sudo systemctl restart SERVICE
sudo systemctl enable SERVICE
```

When viewing `systemctl status`, pressing:

```text
q
```

exits the status viewer.

### Meaning

Many Linux applications run as background services rather than interactive programs.

`systemd` is responsible for managing many of these services, including starting them during boot and monitoring their current state.

This concept later became directly relevant when managing Docker:

```bash
sudo systemctl status docker
```

---

## Package Management and System Updates

Ubuntu's APT package-management system was used to maintain the server.

Package metadata can be refreshed with:

```bash
sudo apt update
```

Installed packages can then be upgraded with:

```bash
sudo apt upgrade
```

### Meaning

`apt update` does **not** normally install software updates.

Instead, it downloads current package metadata from configured repositories so the system knows which package versions are available.

The process can be visualized as:

```text
Ubuntu repositories
        |
        | apt update
        v
Local package index
        |
        | apt upgrade
        v
Installed packages
```

This distinction is important when maintaining Linux systems and troubleshooting package installations.

---

## Docker Installation

Docker Engine was installed on the Ubuntu Server to provide a container runtime for later infrastructure labs.

Docker service availability was verified using:

```bash
systemctl status docker
```

A basic container test was performed using:

```bash
docker run hello-world
```

The successful execution verified that:

* The Docker daemon was running
* The client could communicate with the daemon
* Container images could be retrieved
* Containers could execute successfully

---

## Docker Permissions

Initially, Docker commands required elevated privileges because the user did not have permission to communicate with the Docker daemon.

The user account was added to the Docker group, allowing Docker commands to be executed without repeatedly using `sudo`.

### Meaning

The Docker daemon normally runs with elevated system privileges.

Membership in the Docker group therefore grants significant control over the host.

This is convenient for a development lab but also represents an important security consideration.

Docker group membership should effectively be treated as privileged access.

---

## Server Notes and Documentation

Technical notes were maintained throughout the deployment rather than documenting the environment only after completion.

The notes recorded:

* Commands used
* Configuration decisions
* Problems encountered
* Troubleshooting steps
* Explanations of new concepts
* Successful resolutions

### Meaning

Infrastructure documentation is part of administration, not an afterthought.

Good documentation improves:

* Reproducibility
* Troubleshooting
* Knowledge transfer
* Disaster recovery
* Technical communication

The documentation created during this environment also provides the foundation for the public GitHub homelab portfolio.

---

## Key Concepts Learned

### Virtualization

A hypervisor allows multiple isolated operating systems to share one physical computer.

The Ubuntu Server VM provides a safe environment for infrastructure experimentation.

### Headless Server Administration

Servers do not require a graphical desktop environment to perform their primary functions.

Most administration can be performed efficiently through a terminal.

### SSH

SSH provides encrypted remote access to another system and is a fundamental Linux administration technology.

### Host Keys

SSH host keys establish trust between clients and remote servers and help detect unexpected identity changes.

### `systemd`

`systemd` manages Linux services and their behavior during system startup and operation.

### Package Management

APT provides centralized software installation and update management using trusted repositories.

### Privileged Access

Administrative convenience must always be considered alongside security implications.

Tools such as `sudo` and Docker can provide extensive control over a Linux system.

---

## Problems Encountered

### Docker Permission Denied

**Problem**

Running:

```bash
docker run hello-world
```

initially returned a permission error when attempting to access the Docker socket.

**Cause**

The current user did not have permission to communicate with the Docker daemon through:

```text
/var/run/docker.sock
```

**Resolution**

The user account was added to the Docker group and the new group membership was applied.

**Lesson Learned**

Linux permissions apply not only to ordinary files but also to Unix sockets used for communication between applications and services.

---

### Understanding Service Status Output

**Problem**

The `systemctl status` command opened an interactive status viewer and it was initially unclear how to return to the shell.

**Resolution**

Pressing:

```text
q
```

exits the viewer.

**Lesson Learned**

Many Linux commands use pager programs to display long output. Understanding navigation and exit controls is part of becoming comfortable with terminal-based administration.

---

## Security Considerations

The server currently exists inside a controlled homelab environment.

Future security improvements can include:

* SSH key-based authentication
* Disabling password-based SSH authentication
* Restricting SSH access
* Host firewall configuration
* Service hardening
* Log monitoring
* Automated security updates
* Principle-of-least-privilege access
* Network segmentation

These controls will be introduced as the lab progresses rather than applying configurations without first understanding their purpose.

---

## Lessons Learned

* Linux servers can be administered effectively without a graphical interface.
* SSH is foundational to remote Linux and cloud administration.
* Virtualization provides a safe environment for experimentation and infrastructure development.
* `systemctl` provides a consistent interface for managing many Linux services.
* `apt update` refreshes repository metadata while package upgrades are separate operations.
* Docker relies on a privileged background daemon.
* Docker group membership has security implications and should be treated as privileged access.
* Troubleshooting should begin by determining which layer of the system is failing.
* Documenting commands and problems while performing the work produces better technical records than reconstructing the process afterward.

---

## Real-World Translation

The local environment:

```text
Linux Mint
    |
    v
KVM/QEMU
    |
    v
Ubuntu Server VM
    |
    v
SSH
```

maps conceptually to cloud infrastructure such as:

```text
Administrator Workstation
    |
    v
Cloud Provider
    |
    v
Linux Virtual Machine
    |
    v
Remote Administration
```

The underlying administrative skills remain similar even when the infrastructure moves from a local hypervisor to AWS, Azure, or another cloud platform.

---

## Next Steps

The Ubuntu Server VM serves as the foundation for the remaining homelab work:

1. Docker fundamentals
2. Nginx web hosting
3. Persistent container storage
4. Docker Compose
5. Reverse proxying
6. Local hostname resolution
7. HTTPS/TLS
8. AWS infrastructure
9. Terraform Infrastructure as Code
10. Linux and cloud security hardening
