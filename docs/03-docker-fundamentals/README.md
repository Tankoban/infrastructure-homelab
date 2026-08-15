# Docker Fundamentals Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Learn the fundamentals of containerization by installing Docker on Ubuntu Server, deploying an Nginx web server, managing container lifecycle operations, monitoring logs, configuring persistent content, and implementing automatic container restart behavior.

This lab builds on the Ubuntu Server environment established previously.

---

## Architecture

```text
Linux Mint Workstation
        |
        | SSH
        v
Ubuntu Server VM
        |
        v
Docker Engine
        |
        v
Nginx Container
        |
        | Port 8080 → 80
        v
Web Browser
```

The Ubuntu Server acts as the Docker host while Nginx runs inside an isolated container.

---

## Work Completed

### Verified Docker Engine

Docker availability was verified with:

```bash
systemctl status docker
```

The Docker installation was then tested using:

```bash
docker run hello-world
```

A successful execution confirmed that the Docker client could communicate with the Docker daemon, retrieve an image, create a container, and execute it.

### Meaning

Docker uses a client/server architecture.

```text
Docker CLI
    |
    v
Docker daemon
    |
    +--> Images
    |
    +--> Containers
    |
    +--> Networks
    |
    +--> Volumes
```

Commands entered through the Docker CLI are sent to the Docker daemon, which performs the actual container operations.

---

## Deploying Nginx

An Nginx container was deployed to provide the first persistent network service in the lab.

Nginx initially displayed its default welcome page, confirming that:

* The container was running
* Nginx started successfully
* Docker networking was functioning
* Port mapping was working
* The Ubuntu Server was reachable from the Linux Mint workstation

---

## Port Mapping

The Nginx container used a host-to-container port mapping equivalent to:

```text
8080:80
```

### Meaning

The two ports represent different network boundaries:

```text
Ubuntu Server        Nginx Container

Port 8080  -------->  Port 80
```

Nginx listens on port `80` inside its container.

Docker exposes that service through port `8080` on the Ubuntu Server.

This allows a client to request:

```text
http://SERVER-IP:8080
```

while Nginx itself continues operating normally on port 80 inside the container.

---

## Custom Web Content

A custom HTML page was created outside the container on the Ubuntu Server.

The host directory was mounted into Nginx's web root:

```text
Host:
~/docker/nginx-site

        ↓

Container:
/usr/share/nginx/html
```

This allowed Nginx to serve custom content without storing the website exclusively inside the container.

---

## Bind Mounts

The web directory was mounted using a configuration similar to:

```bash
-v ~/docker/nginx-site:/usr/share/nginx/html:ro
```

The mount consists of three components:

```text
Host Path : Container Path : Mount Options
```

### Meaning

The host maintains the actual website files while the container receives access to them.

This separates application data from the lifecycle of the container.

If the Nginx container is deleted, the website content remains on the Ubuntu Server.

---

## Read-Only Mounts

The mount used:

```text
:ro
```

which specifies **read-only** access.

The Nginx container can therefore read and serve the files but cannot modify them through that mount.

### Meaning

This applies the principle of least privilege.

The web server needs to:

```text
READ website content
```

but does not need to:

```text
MODIFY website content
```

Providing only the required level of access reduces unnecessary permissions.

---

## Container Lifecycle Management

Several commands were practiced to understand the lifecycle of a container.

### List Running Containers

```bash
docker ps
```

### List All Containers

```bash
docker ps -a
```

### Stop a Container

```bash
docker stop nginx-server
```

### Start a Container

```bash
docker start nginx-server
```

### Restart a Container

```bash
docker restart nginx-server
```

### Remove a Container

```bash
docker rm nginx-server
```

### Meaning

Containers are designed to be disposable.

Application configuration and persistent data should therefore be separated from the container whenever possible.

The basic lifecycle is:

```text
Image
  |
  v
Create
  |
  v
Running
  |
  +--> Stop
  |      |
  |      v
  |    Start
  |
  +--> Restart
  |
  v
Remove
```

Removing a container does not necessarily mean losing application data when persistent storage is designed correctly.

---

## Container Logs

Container logs were inspected using:

```bash
docker logs nginx-server
```

Live logs were monitored using:

```bash
docker logs -f nginx-server
```

Refreshing the Nginx web page generated HTTP requests that appeared in the live log stream.

`Ctrl+C` was used to exit log-following mode.

### Meaning

Logs provide visibility into what an application is doing internally.

A useful troubleshooting workflow is:

```text
Is the container running?
        |
        v
docker ps
        |
        v
Check application logs
        |
        v
docker logs
        |
        v
Inspect configuration if needed
```

This same troubleshooting mindset applies to cloud services, applications, and orchestration platforms.

---

## Container Inspection

Detailed container information can be retrieved using:

```bash
docker inspect nginx-server
```

This exposes information such as:

* Container configuration
* Networking
* IP addressing
* Port mappings
* Mounted storage
* Environment settings
* Restart policy
* Image information

### Meaning

`docker inspect` provides lower-level configuration information when basic status and logs are not sufficient to diagnose a problem.

---

## Automatic Restart Policy

The Nginx container was configured with:

```text
--restart unless-stopped
```

This allows Docker to restart the container automatically after events such as a server reboot unless the administrator intentionally stopped the container.

The policy can be inspected through:

```bash
docker inspect nginx-server
```

### Meaning

A server application should not require an administrator to manually start it after every system reboot.

Restart policies introduce basic service resiliency.

The `unless-stopped` policy means:

```text
Unexpected stop / reboot
        |
        v
Restart container

BUT

Administrator intentionally stops container
        |
        v
Leave container stopped
```

---

## Key Concepts Learned

### Images vs Containers

A Docker **image** is the packaged template used to create containers.

A **container** is a running or stopped instance created from an image.

Conceptually:

```text
Image = Blueprint

Container = Running instance of blueprint
```

Multiple containers can be created from the same image.

### Container Isolation

Containers isolate application processes and dependencies while sharing the host operating system's kernel.

They are generally lighter-weight than full virtual machines.

### Port Mapping

Docker can expose a service running inside a container through a different port on the host.

### Persistent Data

Important data should generally exist independently of disposable containers.

### Bind Mounts

Bind mounts allow containers to access specific files or directories stored on the host.

### Least Privilege

Read-only mounts can prevent applications from modifying data when write access is unnecessary.

### Observability

Container logs and inspection tools provide information necessary for troubleshooting and monitoring.

### Resiliency

Restart policies allow containerized services to recover automatically after certain failures or host restarts.

---

## Problems Encountered

### Docker Socket Permission Denied

**Problem**

Initial Docker commands returned:

```text
permission denied while trying to connect to the Docker API at unix:///var/run/docker.sock
```

**Cause**

The current user did not have permission to communicate with the Docker daemon.

**Resolution**

The user account was added to the Docker group and the updated group membership was applied.

**Lesson Learned**

Docker uses a Unix socket for local communication between the CLI and daemon. Access to this socket is controlled through Linux permissions.

Docker group membership should also be treated as privileged access because of the control it provides over the host.

---

## Security Considerations

Several security concepts were introduced during this lab.

### Read-Only Storage

Web content was mounted read-only because Nginx only needed permission to serve the files.

### Docker Daemon Privileges

Access to Docker should be controlled because Docker can perform privileged operations on the host.

### Network Exposure

Publishing a Docker port makes that service reachable through the host's network interfaces unless additional firewall or network controls restrict access.

### Image Trust

Container images should come from trusted sources and should be maintained and updated like any other software dependency.

---

## Troubleshooting Methodology

This lab reinforced a layered troubleshooting approach.

For a containerized web application:

```text
Can I reach the server?
        |
        v
Is Docker running?
        |
        v
Is the container running?
        |
        v
Is the port published?
        |
        v
What do the logs show?
        |
        v
Are the mounts/configuration correct?
```

Checking each layer independently helps identify where a failure actually occurs instead of making configuration changes blindly.

---

## Lessons Learned

* Containers provide a lightweight way to package and run applications.
* Docker images and containers are different concepts.
* Containers should generally be treated as disposable infrastructure.
* Persistent data should be separated from container lifecycle.
* Port mapping connects host networking to container networking.
* Read-only mounts are useful for applying least privilege.
* Logs should be checked before blindly restarting or rebuilding services.
* `docker inspect` provides detailed configuration information for troubleshooting.
* Restart policies improve basic service availability.
* Docker access itself represents a security boundary.

---

## Real-World Translation

The local lab:

```text
Ubuntu Server
      |
      v
Docker Engine
      |
      v
Nginx Container
      |
      v
Website
```

represents the same basic containerization model used in larger environments:

```text
Cloud / Datacenter Server
        |
        v
Container Runtime
        |
        v
Application Containers
        |
        v
Production Services
```

The scale and orchestration tools may change, but the fundamental concepts of images, containers, networking, storage, logging, and lifecycle management remain relevant.

---

## Next Steps

The next lab moves from manually defining containers with long `docker run` commands to managing services declaratively using **Docker Compose**.

This introduces:

* YAML configuration
* Declarative service definitions
* Reproducible deployments
* Multi-container environments
* Infrastructure-as-Code concepts
