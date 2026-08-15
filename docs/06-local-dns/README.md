# Local Hostname Routing Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Replace path-based access to containerized applications with hostname-based routing using local hostname resolution and Nginx virtual hosts.

The goal was to understand how a client translates a human-readable hostname into an IP address and how a reverse proxy can use the requested hostname to route traffic to the correct backend service.

The resulting applications could be accessed as:

```text
http://app1.lab:8080
http://app2.lab:8080
```

rather than:

```text
http://SERVER-IP:8080/app1/
http://SERVER-IP:8080/app2/
```

---

## Previous Architecture

The reverse proxy originally routed requests based on URL paths:

```text
Client
  |
  v
SERVER-IP:8080
  |
  v
Nginx Reverse Proxy
  |
  +---- /app1/ ----> App1
  |
  +---- /app2/ ----> App2
```

This worked, but both applications shared the same hostname and were differentiated by their request paths.

---

## New Architecture

The environment was changed to route based on hostnames:

```text
                Linux Mint Client
                       |
             +---------+---------+
             |                   |
             v                   v
         app1.lab            app2.lab
             |                   |
             +---------+---------+
                       |
                       v
                /etc/hosts
                       |
                       v
             Ubuntu Server IP
                       |
                       v
              Nginx Reverse Proxy
                  /           \
                 /             \
        Host: app1.lab     Host: app2.lab
               |                 |
               v                 v
             App1              App2
```

Both hostnames resolve to the same Ubuntu Server.

Nginx then determines which backend application should receive the request.

---

## Local Hostname Resolution

The Linux Mint workstation's:

```text
/etc/hosts
```

file was configured with mappings similar to:

```text
SERVER-IP    app1.lab
SERVER-IP    app2.lab
```

For example:

```text
192.168.x.x    app1.lab
192.168.x.x    app2.lab
```

The actual server IP may vary depending on the local environment.

### Meaning

Computers ultimately communicate using IP addresses.

A hostname such as:

```text
app1.lab
```

must therefore be translated into an address such as:

```text
192.168.x.x
```

before the client can establish a connection.

Conceptually:

```text
app1.lab
    |
    | Name Resolution
    v
192.168.x.x
```

For this lab, `/etc/hosts` provides that mapping locally.

---

## `/etc/hosts`

The hosts file provides static hostname-to-IP mappings on an individual machine.

A simplified lookup process is:

```text
Application requests app1.lab
            |
            v
Operating system resolves hostname
            |
            +---- Local hosts configuration
            |
            +---- DNS resolution when necessary
            |
            v
IP address returned
```

### Meaning

Using `/etc/hosts` allowed DNS-like behavior to be simulated without deploying a dedicated DNS server.

This was useful for learning hostname routing while keeping the environment isolated to the homelab.

It is important, however, to distinguish:

```text
/etc/hosts
```

from:

```text
DNS Server
```

The hosts file is a **local static name-resolution mechanism**. It is not itself a network DNS server.

---

## Scope of the Configuration

The hostname mappings were added only to the Linux Mint workstation.

Therefore:

```text
Linux Mint
    |
    +---- Knows app1.lab
    |
    +---- Knows app2.lab
```

Other devices on the network do not automatically know these names.

For example:

```text
Phone
Laptop
Tablet
Other workstation
```

would require their own hostname mappings or access to a DNS server configured with equivalent records.

### Meaning

This demonstrated the difference between:

```text
Local name resolution
```

and:

```text
Network-wide DNS
```

The current implementation is intentionally local.

---

## Testing Name Resolution

The configured hostnames were tested using:

```bash
ping app1.lab
```

and:

```bash
ping app2.lab
```

Successful resolution confirmed that the Linux Mint workstation translated both hostnames to the Ubuntu Server's IP address.

### Meaning

A successful hostname lookup verifies one layer of the environment:

```text
Hostname
    |
    v
IP Address
```

It does **not** automatically prove that:

* Nginx is running
* Docker is running
* The application is healthy
* The expected port is open
* HTTP routing is correct

Each layer must still be tested independently when troubleshooting.

---

## HTTP Host Header

Although both names resolve to the same server IP, Nginx can still distinguish the applications because HTTP requests include the hostname being requested.

Conceptually:

```text
GET /
Host: app1.lab
```

versus:

```text
GET /
Host: app2.lab
```

Both requests can arrive at:

```text
Same IP
Same Port
Same Reverse Proxy
```

but contain different `Host` values.

### Meaning

This allows one server to host multiple websites or applications behind the same network address.

The reverse proxy can inspect the hostname and select the correct configuration.

---

## Nginx `server_name`

Nginx was configured with separate virtual server definitions.

Conceptually:

```nginx
server {
    listen 80;
    server_name app1.lab;

    location / {
        proxy_pass http://app1/;
    }
}

server {
    listen 80;
    server_name app2.lab;

    location / {
        proxy_pass http://app2/;
    }
}
```

### Meaning

The:

```nginx
server_name
```

directive tells Nginx which hostname a server block is intended to handle.

The routing flow becomes:

```text
Request for app1.lab
        |
        v
Nginx checks Host header
        |
        v
server_name app1.lab
        |
        v
Proxy to App1
```

while:

```text
Request for app2.lab
        |
        v
Nginx checks Host header
        |
        v
server_name app2.lab
        |
        v
Proxy to App2
```

---

## Host-Based vs Path-Based Routing

The previous implementation used path-based routing:

```text
SERVER-IP/app1/
SERVER-IP/app2/
```

The new implementation uses host-based routing:

```text
app1.lab
app2.lab
```

### Path-Based Routing

The proxy makes a decision using the URL path:

```text
Host: example
Path: /app1/
```

### Host-Based Routing

The proxy makes a decision using the requested hostname:

```text
Host: app1.lab
Path: /
```

### Meaning

Both techniques are widely used.

A production environment might use path routing such as:

```text
example.com/api/
example.com/admin/
example.com/store/
```

or hostname routing such as:

```text
api.example.com
admin.example.com
store.example.com
```

The correct design depends on application and infrastructure requirements.

---

## Virtual Hosting

This lab introduced the concept of **name-based virtual hosting**.

Multiple logical applications can share:

```text
One server
One IP address
One listening port
```

while still being accessed using different hostnames.

Conceptually:

```text
                 One IP Address
                       |
                       v
                  Web Server
                /      |      \
               /       |       \
              v        v        v
          app1.lab  app2.lab  app3.lab
```

### Meaning

This is one reason a server does not require a unique public IP address for every website it hosts.

The application layer can distinguish requests after they reach the server.

---

## Browser Testing

After hostname resolution and Nginx configuration were completed, both applications were successfully opened from the Linux Mint browser.

The applications were accessible through their individual hostnames.

This verified the complete request path:

```text
Browser
   |
   v
Hostname Resolution
   |
   v
Ubuntu Server IP
   |
   v
Docker Published Port
   |
   v
Nginx
   |
   v
Host-Based Routing
   |
   +----> App1
   |
   +----> App2
```

---

## Key Concepts Learned

### Hostname

A human-readable name associated with a network destination.

### Name Resolution

The process of translating a hostname into an IP address.

### `/etc/hosts`

A local static mapping of hostnames to IP addresses.

### DNS

A distributed naming system used to resolve domain names and other DNS records across networks.

### HTTP Host Header

Information within an HTTP request identifying the hostname the client intended to reach.

### Nginx `server_name`

A directive used to select a virtual server configuration based on the requested hostname.

### Virtual Hosting

The ability to serve multiple logical websites or applications from shared server infrastructure.

### Host-Based Routing

Routing traffic based on the hostname requested by the client.

---

## Problems Encountered

No major configuration failure occurred during this portion of the lab.

The primary conceptual challenge was understanding why:

```text
app1.lab
```

and:

```text
app2.lab
```

could both resolve to the exact same IP address while still displaying different applications.

### Resolution

The complete request flow clarified the separation between name resolution and HTTP routing:

```text
Hostname
   |
   | /etc/hosts
   v
IP Address
   |
   | TCP connection
   v
Nginx
   |
   | HTTP Host header
   v
Correct Backend
```

### Lesson Learned

DNS or hostname resolution answers:

> "What IP address should I contact?"

It does not necessarily answer:

> "Which application on that server should handle my request?"

The web server or reverse proxy can make that second decision using application-layer information.

---

## Security Considerations

Local hostname routing does not make a service inherently secure.

It primarily improves naming and routing.

Security still depends on controls such as:

* Firewall rules
* Service exposure
* Authentication
* Authorization
* Encryption
* Patch management
* Network segmentation

A hostname that is difficult to guess should never be treated as an access control.

---

## Troubleshooting Methodology

Hostname-based applications introduce another layer that can fail.

A useful sequence is:

```text
Does the hostname resolve?
        |
        v
ping / getent hosts
        |
        v
Does it resolve to the expected IP?
        |
        v
Can the server be reached?
        |
        v
Is the required port reachable?
        |
        v
Does Nginx receive the request?
        |
        v
Does server_name match the Host header?
        |
        v
Can Nginx reach the backend?
```

A useful Linux command for checking hostname resolution is:

```bash
getent hosts app1.lab
```

This queries the system's configured name-resolution mechanisms and is often more appropriate than relying exclusively on `ping`.

---

## Lessons Learned

* Hostnames must be resolved to IP addresses before network communication can occur.
* `/etc/hosts` provides local static name resolution but is not a DNS server.
* Multiple hostnames can resolve to the same IP address.
* HTTP can preserve the requested hostname through the `Host` header.
* Nginx can use `server_name` to route requests based on hostname.
* One IP address can host multiple logical applications.
* Name resolution and application routing are separate infrastructure layers.
* Local hosts-file entries affect only the systems on which they are configured.
* Network-wide naming requires a centralized naming solution such as DNS.
* Troubleshooting hostname-based applications requires checking both name resolution and application routing.

---

## Real-World Translation

The local lab:

```text
/etc/hosts
    |
    v
app1.lab / app2.lab
    |
    v
Nginx
    |
    v
Containerized Applications
```

maps conceptually to production infrastructure:

```text
DNS
 |
 v
app1.example.com
app2.example.com
 |
 v
Load Balancer / Reverse Proxy
 |
 +----> Application 1
 |
 +----> Application 2
```

In AWS, similar responsibilities may involve services such as:

```text
Route 53
   |
   v
DNS Records
   |
   v
Application Load Balancer
   |
   v
Backend Targets
```

The specific technology changes, but the fundamental sequence remains:

```text
Name Resolution
      ↓
Network Connection
      ↓
Application Routing
      ↓
Backend Service
```

---

## Future Homelab Expansion

The current hostname mappings exist only on the Linux Mint workstation.

A future homelab improvement could introduce centralized internal DNS.

That would allow:

```text
Desktop
Laptop
Phone
Other VMs
```

to resolve internal services without manually editing each device's hosts file.

Potential future technologies include:

* Pi-hole
* dnsmasq
* BIND
* AdGuard Home
* Dedicated internal DNS infrastructure

This would move the lab from:

```text
Per-device static resolution
```

toward:

```text
Centralized network name resolution
```

---

## Portfolio Evidence

The Nginx and Docker configuration supporting hostname routing is maintained under:

```text
docker/reverse-proxy/
```

Sensitive TLS private keys are intentionally excluded from source control.

---

## Next Steps

The next lab secures the hostname-based applications using HTTPS and TLS.

The environment will progress from:

```text
http://app1.lab
http://app2.lab
```

to:

```text
https://app1.lab
https://app2.lab
```

This introduces:

* TLS
* Encryption in transit
* Certificates
* Private keys
* Certificate trust
* HTTPS
* Secure reverse proxy configuration
