# Nginx Reverse Proxy Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Build a multi-container application environment using Docker Compose and configure Nginx as a reverse proxy to route incoming HTTP requests to separate backend application containers.

The goal was to understand how a single entry point can provide access to multiple internal services while introducing Docker networking, service discovery, HTTP routing, and systematic troubleshooting.

---

## Architecture

The lab consisted of three containers:

```text
                    Client
                      |
                      |
                      v
              Ubuntu Server
                 Port 8080
                      |
                      v
             +----------------+
             | Nginx Reverse  |
             |     Proxy      |
             +----------------+
                |          |
                |          |
          /app1/|          |/app2/
                |          |
                v          v
          +----------+  +----------+
          |   App1   |  |   App2   |
          |  Nginx   |  |  Nginx   |
          +----------+  +----------+
```

The reverse proxy was the only service that needed to expose a port to the host.

The backend application containers remained accessible through Docker's internal network.

---

## Project Structure

The project was organized approximately as:

```text
reverse-proxy-lab/
├── docker-compose.yml
├── nginx/
│   └── default.conf
├── app1/
│   └── index.html
└── app2/
    └── index.html
```

This separated:

* Container definitions
* Reverse proxy configuration
* Application content

The same structure is preserved in the public Git repository under:

```text
docker/reverse-proxy/
```

---

## Multi-Container Deployment

Docker Compose was used to define:

* `app1`
* `app2`
* `reverse-proxy`

The complete environment could then be started with:

```bash
docker compose up -d
```

Compose automatically created a network for the project and connected the services to it.

### Meaning

The containers did not need to be managed as completely independent systems.

Docker Compose created a shared application environment:

```text
Compose Project
      |
      v
Docker Network
      |
      +------ app1
      |
      +------ app2
      |
      +------ reverse-proxy
```

This allowed the reverse proxy to communicate with the application containers without exposing each backend application directly through the Ubuntu Server.

---

## Docker Service Discovery

The Nginx reverse proxy could reference the backend containers using their Compose service names.

Conceptually:

```nginx
proxy_pass http://app1;
```

and:

```nginx
proxy_pass http://app2;
```

### Meaning

The reverse proxy did not need hard-coded container IP addresses.

Docker provides DNS-based service discovery within the Compose network.

Instead of:

```text
172.x.x.x
```

Nginx could use:

```text
app1
app2
```

This is important because container IP addresses are not necessarily permanent.

The service name provides a stable logical identifier.

---

## Reverse Proxying

A reverse proxy accepts requests from clients and forwards them to backend services.

The initial routing design used URL paths:

```text
Client Request
     |
     +---- /app1/ ----> App1
     |
     +---- /app2/ ----> App2
```

This provided one external entry point while allowing multiple applications to run behind it.

### Meaning

Without a reverse proxy, clients might need to connect directly to separate services:

```text
SERVER-IP:8081
SERVER-IP:8082
SERVER-IP:8083
```

With a reverse proxy:

```text
SERVER-IP:8080/app1/
SERVER-IP:8080/app2/
```

The proxy becomes responsible for determining which backend service should receive each request.

---

## Nginx Routing

Nginx `location` blocks were used to match incoming URL paths.

Conceptually:

```nginx
location /app1/ {
    proxy_pass http://app1/;
}

location /app2/ {
    proxy_pass http://app2/;
}
```

### Meaning

Nginx evaluates the incoming request and selects the appropriate routing rule.

For example:

```text
GET /app1/
      |
      v
Nginx
      |
      v
App1
```

while:

```text
GET /app2/
      |
      v
Nginx
      |
      v
App2
```

This is application-layer routing based on HTTP request information.

---

## Problem Encountered: Port Conflict

### Problem

During the initial deployment:

```bash
docker compose up -d
```

App1 and App2 started successfully, but the reverse proxy failed.

Docker returned an error similar to:

```text
Bind for 0.0.0.0:8080 failed:
port is already allocated
```

### Investigation

The error indicated that Docker could not bind the reverse proxy to host port `8080`.

A previously created Nginx container was already using that port.

Conceptually:

```text
Old Nginx Container
        |
        v
Host Port 8080
        ^
        |
Reverse Proxy
attempts same port
        |
        X
```

Only one process or container can normally bind to the same host IP/port combination at a time.

### Resolution

The previous container using port `8080` was stopped or removed.

The Compose deployment was then started again:

```bash
docker compose up -d
```

All three services successfully started.

### Meaning

A container can be healthy internally while still failing to start because a required host resource is unavailable.

### Lesson Learned

When Docker reports a port binding failure, investigate what is already listening on that port before modifying the application.

Useful commands include:

```bash
docker ps
```

and host-level networking tools such as:

```bash
ss -tulpn
```

---

## Problem Encountered: Browser Could Not Reach Applications

### Problem

After the containers started, attempts to access the applications from the browser initially returned:

```text
This site cannot be reached
```

### Investigation

Troubleshooting was moved closer to the application rather than immediately changing external network configuration.

Requests were tested directly from the Ubuntu Server using:

```bash
curl http://localhost:8080/app1
```

and:

```bash
curl http://localhost:8080/app2
```

The server was reachable, but Nginx returned:

```text
404 Not Found
```

### Meaning

This narrowed the problem significantly.

The request successfully traveled through:

```text
curl
  |
  v
localhost:8080
  |
  v
Docker port mapping
  |
  v
Reverse Proxy
```

Therefore:

* Docker was running
* The reverse proxy was running
* Port `8080` was reachable
* HTTP requests reached Nginx

The problem was no longer basic connectivity.

It was **application-layer routing**.

### Lesson Learned

A successful connection that returns the wrong HTTP response is fundamentally different from a connection failure.

Troubleshooting should distinguish between:

```text
Can't reach service
```

and:

```text
Reached service, but service returned an error
```

---

## Problem Encountered: Nginx 404 Responses

### Problem

The following requests returned Nginx `404 Not Found` responses:

```bash
curl http://localhost:8080/app1
curl http://localhost:8080/app2
```

### Investigation

The Nginx configuration defined routing locations with trailing slashes:

```text
/app1/
/app2/
```

but the requests were being made without the trailing slash.

Testing:

```bash
curl http://localhost:8080/app1/
```

returned:

```html
<h1>App 1</h1>
<p>Tankouban Reverse Proxy Lab</p>
```

Testing:

```bash
curl http://localhost:8080/app2/
```

returned:

```html
<h1>App 2</h1>
<p>Docker Reverse Proxy Working</p>
```

### Resolution

Requests were made using the paths expected by the Nginx configuration:

```text
/app1/
/app2/
```

The applications subsequently loaded successfully from the Linux Mint browser.

### Meaning

URL syntax can affect how Nginx matches and rewrites requests.

A small difference such as:

```text
/app1
```

versus:

```text
/app1/
```

can affect routing behavior depending on the configuration.

### Lesson Learned

When debugging HTTP routing:

1. Confirm basic connectivity.
2. Inspect the HTTP status code.
3. Compare the request URI against the proxy configuration.
4. Test locally with `curl`.
5. Inspect Nginx logs/configuration before changing unrelated network settings.

---

## Using `curl` for Troubleshooting

`curl` became an important diagnostic tool during this lab.

Instead of relying only on a graphical browser, requests could be tested directly from the server:

```bash
curl http://localhost:8080/app1/
```

### Meaning

Testing from the server removes several variables:

```text
External Client
     X

DNS
     X

Home network path
     X

Browser behavior
     X

Local HTTP request
     |
     v
Application
```

If a service works locally but not remotely, the problem likely exists somewhere between the client and server.

If it fails locally, troubleshooting can focus on the application/server stack.

This is an example of **isolating layers during troubleshooting**.

---

## Reverse Proxy as an Abstraction Layer

The client did not need to know where App1 or App2 actually ran.

The client only communicated with:

```text
Reverse Proxy
```

The proxy knew how to reach:

```text
App1
App2
```

### Meaning

This abstraction allows backend infrastructure to change without necessarily changing how clients access the application.

For example:

```text
Client
  |
  v
proxy.example.com
  |
  +----> Server A
  |
  +----> Server B
```

The backend systems can potentially be replaced, scaled, or reorganized while preserving the client-facing endpoint.

---

## Key Concepts Learned

### Reverse Proxy

A reverse proxy receives client requests and forwards them to backend services.

### Backend Service

An application or service that receives traffic through another system such as a proxy or load balancer.

### Docker Networking

Containers within a Compose project can communicate across a Docker-managed network.

### Service Discovery

Docker allows containers to locate one another through service names rather than hard-coded IP addresses.

### HTTP Routing

Nginx can route traffic based on request information such as URL paths or hostnames.

### Port Binding

A host port must be available before Docker can publish a container service through that port.

### HTTP Status Codes

Responses such as `404 Not Found` indicate that communication with the HTTP server succeeded but the requested resource or route was not found.

### Layered Troubleshooting

Infrastructure problems become easier to diagnose when networking, container runtime, proxy configuration, and application behavior are tested separately.

---

## Security Considerations

A reverse proxy creates a useful security boundary.

Instead of exposing every backend service directly:

```text
Internet / Client
     |
     +--> App1
     +--> App2
     +--> App3
```

the architecture can expose only the proxy:

```text
Internet / Client
        |
        v
   Reverse Proxy
        |
   Internal Network
     /       \
    v         v
  App1       App2
```

This can reduce the externally exposed attack surface.

A reverse proxy can also become a centralized location for controls such as:

* TLS termination
* Authentication
* Rate limiting
* Request filtering
* Logging
* Security headers
* Access restrictions

The proxy itself therefore becomes a security-critical component that must also be properly hardened.

---

## Troubleshooting Methodology

The lab produced a reusable troubleshooting sequence for containerized web infrastructure:

```text
Is the server reachable?
        |
        v
Is Docker running?
        |
        v
Are the containers running?
        |
        v
Is the expected host port available?
        |
        v
Is the reverse proxy listening?
        |
        v
Test locally with curl
        |
        v
What HTTP status is returned?
        |
        v
Does the request match Nginx routing?
        |
        v
Can the proxy reach the backend service?
        |
        v
Check logs
```

This prevents troubleshooting from turning into random configuration changes.

---

## Problems Encountered Summary

| Problem                             | Cause                                                                  | Resolution                                |
| ----------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------- |
| Reverse proxy failed to start       | Port `8080` already allocated                                          | Stopped/removed conflicting container     |
| Applications inaccessible initially | Required additional layer-by-layer testing                             | Tested from Ubuntu Server with `curl`     |
| `404 Not Found`                     | Request path did not match expected trailing-slash routing             | Used `/app1/` and `/app2/`                |
| Browser access uncertainty          | Needed to distinguish local application behavior from network behavior | Verified locally before testing from Mint |

---

## Lessons Learned

* A reverse proxy provides a centralized entry point for multiple backend services.
* Docker Compose automatically provides networking for services in the same project.
* Docker service names provide more stable routing targets than container IP addresses.
* Host port conflicts can prevent otherwise healthy containers from starting.
* HTTP errors and network connection failures represent different troubleshooting layers.
* `curl` is extremely useful for isolating web application problems.
* Nginx path matching is sensitive to configuration details such as trailing slashes.
* Backend services do not necessarily need to expose host ports when traffic reaches them through a reverse proxy.
* Infrastructure troubleshooting should move systematically through layers rather than relying on guesswork.
* Failures encountered during a lab are valuable documentation because they demonstrate diagnostic reasoning.

---

## Real-World Translation

The lab architecture:

```text
Client
  |
  v
Nginx Reverse Proxy
  |
  +----> App1
  |
  +----> App2
```

maps conceptually to production architectures such as:

```text
Users
  |
  v
DNS
  |
  v
Load Balancer / Reverse Proxy / Ingress
  |
  +----> Web Application
  |
  +----> API
  |
  +----> Internal Service
```

Technologies may change, but the underlying concepts remain similar:

* One controlled entry point
* Internal backend services
* Request routing
* Service discovery
* Centralized security controls
* Centralized logging

---

## Portfolio Evidence

The sanitized implementation files for this lab are available in:

```text
docker/reverse-proxy/
```

These include:

```text
docker-compose.yml
nginx/default.conf
app1/index.html
app2/index.html
ssl/README.md
```

Private TLS keys and locally generated certificate material are intentionally excluded from source control.

---

## Next Steps

The next lab improves the client experience by moving from path-based routing:

```text
SERVER-IP:8080/app1/
SERVER-IP:8080/app2/
```

to hostname-based routing:

```text
app1.lab
app2.lab
```

This introduces:

* Hostname resolution
* `/etc/hosts`
* HTTP `Host` headers
* Nginx `server_name`
* Host-based virtual hosting
* DNS concepts
