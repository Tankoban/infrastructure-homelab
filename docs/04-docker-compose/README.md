# Docker Compose Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Transition from manually managing containers with individual `docker run` commands to defining and managing containerized services declaratively with Docker Compose.

The goal was to make the Nginx deployment easier to reproduce, modify, start, stop, and document while introducing concepts that lead naturally into Infrastructure as Code.

---

## Architecture

```text
docker-compose.yml
        |
        v
Docker Compose
        |
        v
Docker Engine
        |
        v
Nginx Container
        |
        +---- Port Mapping
        |
        +---- Bind Mount
        |
        +---- Restart Policy
```

Instead of expressing each configuration option through a long command, the desired container configuration is stored in a YAML file.

---

## From `docker run` to Docker Compose

The original Nginx deployment required options to be supplied through the command line.

Conceptually:

```bash
docker run \
  --name nginx-server \
  --restart unless-stopped \
  -p 8080:80 \
  -v /path/to/html:/usr/share/nginx/html:ro \
  nginx
```

This works, but the desired configuration exists primarily in the command used to create the container.

Docker Compose moves that configuration into a file.

Example:

```yaml
services:
  nginx:
    image: nginx
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped
```

### Meaning

Both approaches can produce similar infrastructure.

The major difference is how that infrastructure is described.

```text
docker run
    |
    v
Tell Docker HOW to create the container

Docker Compose
    |
    v
Describe WHAT the environment should look like
```

This is an introduction to **declarative configuration**.

---

## YAML Configuration

Docker Compose uses YAML to describe services and their configuration.

The lab introduced YAML concepts including:

* Key/value pairs
* Lists
* Indentation
* Nested configuration
* Service definitions

### Meaning

YAML is commonly used throughout modern infrastructure tooling.

Examples include:

* Docker Compose
* Kubernetes
* GitHub Actions
* Ansible
* CI/CD pipelines
* Cloud configuration systems

Because whitespace is structurally significant in YAML, indentation must be consistent.

---

## Service Definitions

A Compose file defines one or more services under:

```yaml
services:
```

Each service represents a containerized application or infrastructure component.

For example:

```yaml
services:
  web:
    image: nginx
```

describes a service named `web` that uses the Nginx image.

### Meaning

The service name becomes a logical identifier within the Compose project.

This becomes especially useful when multiple containers need to communicate with each other.

---

## Port Configuration

Port mappings were moved into the Compose configuration:

```yaml
ports:
  - "8080:80"
```

This retains the same networking behavior previously configured with:

```bash
-p 8080:80
```

The mapping remains:

```text
Ubuntu Server :8080
        |
        v
Nginx Container :80
```

The difference is that the configuration is now stored and reproducible.

---

## Persistent Content

The custom Nginx content was mounted through Compose using a bind mount similar to:

```yaml
volumes:
  - ./html:/usr/share/nginx/html:ro
```

The `:ro` option preserves read-only access.

### Meaning

The Compose file now documents:

* Which host data the application needs
* Where that data appears inside the container
* What level of access the container receives

The storage configuration is no longer dependent on remembering a previous command.

---

## Restart Policy

The restart behavior was also moved into the Compose file:

```yaml
restart: unless-stopped
```

This means the desired resiliency behavior travels with the rest of the application's configuration.

---

## Starting the Environment

The Compose project can be started using:

```bash
docker compose up -d
```

### Command Breakdown

`docker compose`

Invokes Docker Compose.

`up`

Creates or starts the services necessary to reach the configuration described by the Compose file.

`-d`

Runs the services in detached mode so the terminal remains available.

### Meaning

Instead of manually recreating every container option, Docker reads the configuration and determines what needs to exist.

---

## Viewing Service State

Compose-managed containers can be inspected using:

```bash
docker compose ps
```

This provides the state of services belonging specifically to the current Compose project.

Standard Docker commands remain available:

```bash
docker ps
```

### Meaning

Docker Compose does not replace Docker.

It provides a higher-level way of defining and managing groups of Docker resources.

---

## Stopping the Environment

The services can be stopped without removing them using:

```bash
docker compose stop
```

They can later be restarted using:

```bash
docker compose start
```

The entire Compose deployment can be stopped and its containers/network removed using:

```bash
docker compose down
```

The environment can then be recreated using:

```bash
docker compose up -d
```

### Meaning

This demonstrates one of the major benefits of declarative configuration:

```text
Environment exists
       |
       v
docker compose down
       |
       v
Containers removed
       |
       v
docker compose up -d
       |
       v
Environment recreated from configuration
```

The configuration file becomes the reusable definition of the environment.

---

## Reproducibility

One of the main improvements introduced by Compose was reproducibility.

A manually configured container depends heavily on:

* Shell history
* Administrator memory
* Documentation
* Previous commands

A Compose project instead stores the desired configuration in a portable file.

Conceptually:

```text
Compose Configuration
        |
        +------> Server A
        |
        +------> Server B
        |
        +------> Rebuilt Server A
```

Provided the required dependencies and application data exist, the same configuration can be used to reproduce the deployment.

---

## Key Concepts Learned

### Imperative Configuration

Imperative administration describes the individual actions necessary to reach a desired result.

Example:

```text
Create this container.
Expose this port.
Mount this directory.
Set this restart policy.
```

### Declarative Configuration

Declarative administration describes the desired final state.

Example:

```text
This service should exist with:
- this image
- these ports
- these mounts
- this restart behavior
```

The tooling determines the operations necessary to reach that state.

### Configuration as Code

Infrastructure configuration stored in text files can be:

* Version controlled
* Reviewed
* Reused
* Compared
* Documented
* Automated

Docker Compose is therefore an early introduction to configuration-as-code practices.

### Idempotent Thinking

Repeatedly applying a declarative configuration should move the environment toward the same intended state rather than requiring the administrator to manually reproduce every previous action.

This concept becomes increasingly important with infrastructure automation tools.

---

## Problems Encountered

No major failure was required to understand the primary lesson of this lab.

The main challenge was shifting the mental model from:

```text
"What Docker command do I need to run?"
```

to:

```text
"What should this application's configuration look like?"
```

### Lesson Learned

Infrastructure becomes easier to reproduce and maintain when configuration is stored explicitly rather than existing only as a sequence of administrator actions.

---

## Security Considerations

Moving configuration into source-controlled files creates both advantages and responsibilities.

### Advantages

Configuration can be reviewed for:

* Exposed ports
* Excessive permissions
* Unsafe volume mounts
* Privileged containers
* Insecure settings

### Responsibilities

Configuration files must not contain sensitive material such as:

* Passwords
* API tokens
* Private keys
* Cloud credentials

Secrets should be handled separately from ordinary version-controlled configuration.

This principle will become especially important when working with Terraform and cloud infrastructure.

---

## Troubleshooting Methodology

Compose introduces additional commands useful for diagnosing an environment.

### Check Service State

```bash
docker compose ps
```

### View Logs

```bash
docker compose logs
```

### Follow Logs

```bash
docker compose logs -f
```

### Reconcile Configuration

After changing the Compose configuration:

```bash
docker compose up -d
```

can apply the updated desired state.

A useful troubleshooting sequence is:

```text
Read Compose configuration
        |
        v
docker compose ps
        |
        v
docker compose logs
        |
        v
Inspect individual container
        |
        v
Check networking / mounts / ports
```

---

## Lessons Learned

* Docker Compose provides a declarative way to manage containerized services.
* YAML is widely used throughout cloud and DevOps tooling.
* Container configuration should be reproducible rather than dependent on shell history.
* `docker compose up -d` creates or reconciles services with their declared configuration.
* `docker compose down` can remove the running deployment while preserving its reusable definition.
* Configuration stored as text can be version controlled and reviewed.
* Source-controlled configuration must be kept separate from secrets.
* Declarative infrastructure provides a conceptual bridge between Docker Compose and tools such as Terraform.

---

## Real-World Translation

The progression so far is:

```text
Manual Linux Administration
        |
        v
Manual Docker Commands
        |
        v
Docker Compose
        |
        v
Declarative Configuration
        |
        v
Infrastructure as Code
```

This same mental model will later be applied to AWS.

Instead of manually creating:

```text
VPC
Subnet
Security Group
EC2 Instance
```

Terraform will allow the desired cloud infrastructure to be described in configuration files and reproduced programmatically.

---

## Next Steps

The next lab expands from a single containerized service into a multi-container architecture using an **Nginx reverse proxy**.

That introduces:

* Multi-container networking
* Service discovery
* Reverse proxying
* Request routing
* Port conflicts
* HTTP troubleshooting
* Application architecture
