# HTTPS and TLS Lab

**Lab Date:** August 2026
**Status:** Complete

## Objective

Secure the existing hostname-based reverse proxy environment using HTTPS and TLS.

The previous lab allowed applications to be accessed through:

```text
http://app1.lab
http://app2.lab
```

This lab added encrypted communication between the client and Nginx reverse proxy, resulting in:

```text
https://app1.lab:8443
https://app2.lab:8443
```

The goal was to understand the practical relationship between HTTP, HTTPS, TLS certificates, private keys, encryption in transit, certificate trust, and Nginx TLS termination.

---

## Previous Architecture

Before TLS was implemented:

```text
Linux Mint Browser
        |
        | HTTP
        | Unencrypted
        v
Nginx Reverse Proxy
        |
        +----> App1
        |
        +----> App2
```

The applications were functional, but traffic between the browser and reverse proxy was transmitted using HTTP.

---

## TLS-Enabled Architecture

After implementing TLS:

```text
Linux Mint Browser
        |
        | HTTPS / TLS
        | Encrypted
        v
+-----------------------+
| Nginx Reverse Proxy   |
|                       |
| TLS Certificate       |
| Private Key           |
+-----------------------+
        |
        | Internal Docker Network
        |
     +--+--+
     |     |
     v     v
   App1   App2
```

Nginx became responsible for accepting encrypted HTTPS connections from clients.

The backend applications remained behind the reverse proxy.

---

## HTTP vs HTTPS

HTTP provides application-layer communication between web clients and servers.

By itself, ordinary HTTP does not provide transport encryption.

Conceptually:

```text
Client
  |
  | HTTP
  | Plain application data
  v
Server
```

HTTPS combines HTTP with TLS:

```text
Client
  |
  | HTTP over TLS
  | Encrypted in transit
  v
Server
```

### Meaning

HTTPS is not a completely separate web protocol replacing HTTP.

It is HTTP communication protected by TLS.

TLS provides security properties including:

* Encryption
* Integrity
* Authentication of the server when certificate trust is properly established

---

## Encryption in Transit

TLS protects data while it travels between systems.

This is known as:

```text
Encryption in transit
```

Without transport encryption, an attacker capable of observing network traffic may potentially inspect application data.

With TLS, the data transmitted across the protected connection is encrypted.

### Meaning

Encryption in transit is different from encryption at rest.

```text
Encryption in Transit
        |
        v
Protect data moving across networks

Encryption at Rest
        |
        v
Protect stored data
```

A secure system may require both depending on its threat model and data.

---

## Generating a Self-Signed Certificate

A local certificate and private key were generated using OpenSSL.

The command used was:

```bash
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout lab.key \
  -out lab.crt
```

This generated:

```text
lab.crt
lab.key
```

### Command Breakdown

`req`

Invokes OpenSSL certificate request and certificate-generation functionality.

`-x509`

Creates a self-signed X.509 certificate rather than only generating a certificate signing request.

`-nodes`

Creates the private key without encrypting it with a passphrase.

For an unattended server process, this allows Nginx to access the key without requiring an administrator to manually enter a passphrase during startup.

This also increases the importance of protecting the private key at the filesystem level.

`-days 365`

Sets the certificate validity period to 365 days.

`-newkey rsa:2048`

Generates a new 2048-bit RSA private key.

`-keyout lab.key`

Writes the private key to:

```text
lab.key
```

`-out lab.crt`

Writes the certificate to:

```text
lab.crt
```

---

## Certificate and Private Key

The TLS configuration introduced two related but fundamentally different files.

### Certificate

```text
lab.crt
```

The certificate contains public information used as part of establishing the server's identity.

Certificates are designed to be presented to clients.

### Private Key

```text
lab.key
```

The private key is secret cryptographic material associated with the certificate.

It must be protected.

Conceptually:

```text
Certificate
    |
    +---- Public

Private Key
    |
    +---- Secret
```

### Meaning

Possession of the certificate does not need to be secret.

Possession of the private key is security-sensitive.

If an unauthorized party obtains a server's private key, the key should be treated as compromised and replaced.

---

## Self-Signed Certificates

The lab certificate was self-signed.

This means the certificate was signed using its own corresponding private key rather than being issued through a Certificate Authority trusted by the client.

Conceptually:

```text
Public Website

Server Certificate
       |
       v
Trusted Certificate Authority
       |
       v
Browser Trust Store
       |
       v
Trusted


Local Lab

Self-Signed Certificate
       |
       v
No pre-established trusted issuer
       |
       v
Browser Warning
```

### Meaning

A self-signed certificate can still be used to establish encrypted TLS communication.

However, encryption and certificate trust are related but separate concerns.

The browser can establish an encrypted connection while still warning:

> I cannot automatically verify that I should trust the identity represented by this certificate.

This distinction is important.

---

## Browser Certificate Warning

When the applications were accessed over HTTPS, the browser displayed a certificate warning.

This was expected.

### Cause

The locally generated certificate was not issued by a Certificate Authority trusted by the operating system/browser.

### Resolution

For this isolated lab, the warning was acknowledged and the connection was allowed to proceed.

### Meaning

The warning did **not** mean:

```text
TLS encryption failed
```

It meant:

```text
The browser cannot automatically establish trust in the certificate issuer.
```

For public production infrastructure, users should not normally be instructed to bypass certificate warnings.

A certificate from an appropriately trusted Certificate Authority should be used.

---

## Nginx TLS Configuration

Nginx was configured to listen for TLS connections.

Conceptually:

```nginx
server {
    listen 443 ssl;
    server_name app1.lab;

    ssl_certificate /etc/nginx/ssl/lab.crt;
    ssl_certificate_key /etc/nginx/ssl/lab.key;

    location / {
        proxy_pass http://app1/;
    }
}
```

A similar virtual server configuration was used for App2.

### Meaning

These directives tell Nginx:

```text
listen 443 ssl
    |
    v
Accept TLS connections

ssl_certificate
    |
    v
Present this certificate

ssl_certificate_key
    |
    v
Use this private key
```

Nginx performs the TLS operations before forwarding the HTTP request to the appropriate backend service.

---

## TLS Termination

In the lab, TLS was terminated at the Nginx reverse proxy.

```text
Browser
   |
   | HTTPS
   | Encrypted
   v
Nginx
   |
   | HTTP
   | Docker Network
   v
Backend Application
```

### Meaning

The reverse proxy handles the client-facing TLS connection.

After decrypting the request, it forwards traffic to the backend application.

This architecture is known as:

```text
TLS termination
```

TLS termination is commonly performed by:

* Reverse proxies
* Load balancers
* API gateways
* Ingress controllers
* Cloud-managed edge services

Whether traffic between the proxy and backend should also use TLS depends on the environment and security requirements.

---

## Docker TLS Mount

The certificate directory was mounted into the reverse proxy container.

Conceptually:

```yaml
volumes:
  - ./ssl:/etc/nginx/ssl:ro
```

The mount was configured read-only.

### Meaning

Nginx needs to read:

```text
lab.crt
lab.key
```

but does not need to modify them.

Using:

```text
:ro
```

limits the container's access to the required operation.

This is another application of least privilege.

---

## HTTPS Port Mapping

The reverse proxy exposed its TLS port through Docker using a mapping equivalent to:

```yaml
ports:
  - "8080:80"
  - "8443:443"
```

The HTTPS mapping means:

```text
Ubuntu Server :8443
        |
        v
Reverse Proxy Container :443
```

Therefore the local applications could be accessed using:

```text
https://app1.lab:8443
https://app2.lab:8443
```

### Meaning

Port `443` is the conventional HTTPS port.

The lab used host port `8443` so the mapping between host and container networking remained explicit.

A production HTTPS service commonly exposes port `443` directly.

---

## Complete Request Flow

After TLS was implemented, a request followed this path:

```text
https://app1.lab:8443
        |
        v
Local Name Resolution
/etc/hosts
        |
        v
Ubuntu Server IP
        |
        v
TCP Port 8443
        |
        v
Docker Port Mapping
8443 -> 443
        |
        v
Nginx Reverse Proxy
        |
        +--> TLS Handshake
        |
        +--> Certificate Presented
        |
        +--> Encrypted Session Established
        |
        +--> Request Decrypted
        |
        +--> Hostname Evaluated
        |
        v
App1 Container
```

This combines concepts from several previous labs into one request path.

---

## Key Concepts Learned

### TLS

Transport Layer Security protects network communications using cryptography.

### HTTPS

HTTP communication transported through a TLS-protected connection.

### Encryption in Transit

Protection applied to data while it moves between systems.

### X.509 Certificate

A digital certificate format commonly used with TLS to associate identity information with a public key.

### Private Key

Secret cryptographic material used by the server during TLS operations.

### Certificate Authority

An entity that issues or signs certificates and may be trusted by operating systems and browsers.

### Certificate Trust

The process through which a client determines whether it trusts the identity represented by a certificate.

### Self-Signed Certificate

A certificate signed using its own private key rather than through an independently trusted CA.

### TLS Termination

The point in the architecture where encrypted TLS traffic is decrypted before further processing or proxying.

### Least Privilege

Resources should receive only the permissions necessary to perform their intended function.

---

## Problems Encountered

### Browser Reported Certificate Warning

**Problem**

Accessing:

```text
https://app1.lab:8443
https://app2.lab:8443
```

produced a browser security warning.

**Cause**

The certificate was self-signed and was therefore not automatically trusted by the browser.

**Resolution**

The warning was expected and manually bypassed for the isolated lab.

**Lesson Learned**

Encryption and trust are separate properties.

A TLS connection can be encrypted while the client still lacks a trusted chain validating the server's identity.

---

## Security Considerations

### Private Key Protection

The private key must not be exposed publicly.

The portfolio repository therefore excludes private-key material through `.gitignore`.

Files such as:

```text
*.key
*.pem
```

are intentionally ignored.

### Certificate Repository Policy

The locally generated certificate is also excluded from this portfolio.

Instead, the repository contains instructions allowing another user to generate their own certificate.

This provides:

```text
Reproducibility
      +
Secret hygiene
```

without publishing local cryptographic material.

### File Permissions

Because the private key is sensitive, access should be restricted to only the processes and users that require it.

### Self-Signed Certificates

Self-signed certificates are useful for:

* Labs
* Testing
* Development
* Certain controlled internal environments

They are generally inappropriate as the trust model for public production websites.

### Certificate Lifecycle

Certificates have expiration dates and eventually require:

* Renewal
* Replacement
* Rotation
* Revocation when compromised

Certificate management is therefore an ongoing operational responsibility.

---

## Public Repository Security

Before publishing the project, the repository was configured to exclude certificate and private-key files.

The `.gitignore` configuration includes patterns such as:

```gitignore
*.key
*.pem
*.crt
```

The configuration was tested using:

```bash
git check-ignore -v PATH
```

A staged-content review was also performed before the first Git commit.

### Meaning

Security controls should be **verified**, not merely assumed to work.

The workflow used was:

```text
Create configuration
        |
        v
Define exclusion rules
        |
        v
Test exclusion rules
        |
        v
Stage repository
        |
        v
Review staged content
        |
        v
Commit
        |
        v
Push
```

This becomes increasingly important when infrastructure repositories begin containing cloud configuration.

---

## Troubleshooting Methodology

TLS introduces additional layers to the existing troubleshooting process.

A useful sequence becomes:

```text
Does hostname resolution work?
        |
        v
Can the server be reached?
        |
        v
Is the HTTPS port reachable?
        |
        v
Is the reverse proxy running?
        |
        v
Is Nginx listening for TLS?
        |
        v
Can Nginx read the certificate?
        |
        v
Can Nginx read the private key?
        |
        v
Does the certificate match the intended service?
        |
        v
Is the certificate trusted?
        |
        v
Can Nginx reach the backend?
```

The exact browser error or TLS error matters because different failures indicate problems at different layers.

---

## Problems Encountered Summary

| Problem                                                  | Cause                                                       | Resolution                                      |
| -------------------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------- |
| Browser certificate warning                              | Self-signed certificate was not in the client's trust chain | Expected for lab; warning manually acknowledged |
| Certificate files cannot be published safely as a bundle | Directory contained a private key                           | Private material excluded from Git              |
| Public repo still needed to be reproducible              | TLS files intentionally absent                              | Added certificate-generation instructions       |

---

## Lessons Learned

* HTTPS protects HTTP communication using TLS.
* TLS provides encryption in transit and integrity protection.
* Certificates and private keys serve different purposes and require different handling.
* Private keys must remain secret.
* A self-signed certificate can provide encryption without automatically providing trusted identity.
* Browser certificate warnings should be understood rather than treated as generic HTTPS failures.
* Reverse proxies can terminate TLS on behalf of backend services.
* Read-only mounts can reduce unnecessary container permissions.
* Certificates have a lifecycle and must eventually be renewed or rotated.
* Sensitive cryptographic material should not be committed to source control.
* Security controls such as `.gitignore` should be tested.
* Reproducibility does not require publishing secrets.

---

# Portfolio Summary

A concise portfolio description of this lab is:

> Added HTTPS encryption to the local containerized application stack using self-signed TLS certificates and Nginx TLS termination. Practiced certificate generation, private-key handling, secure Git exclusions, HTTP-to-HTTPS redirection, encrypted application access, and TLS troubleshooting.

---
## Real-World Translation

The local environment:

```text
Client
  |
  | HTTPS
  v
Nginx
  |
  | TLS Termination
  v
Backend Containers
```

maps conceptually to production architectures such as:

```text
Internet
   |
   | HTTPS
   v
Load Balancer / Reverse Proxy / CDN
   |
   | TLS Termination
   v
Application Infrastructure
```

In AWS, related responsibilities can involve:

```text
Route 53
    |
    v
DNS
    |
    v
Application Load Balancer
    |
    +--> AWS Certificate Manager
    |
    v
EC2 / Containers / Application Targets
```

This means the concepts practiced locally will transfer directly into upcoming cloud infrastructure labs.

---

## Local Infrastructure Arc Completed

With HTTPS implemented, the local environment now includes:

```text
Linux Mint Workstation
        |
        v
KVM/QEMU
        |
        v
Ubuntu Server
        |
        v
SSH Administration
        |
        v
Docker Engine
        |
        v
Docker Compose
        |
        v
Nginx Reverse Proxy
        |
        +--> Docker Service Discovery
        |
        +--> Host-Based Routing
        |
        +--> TLS Termination
        |
        v
Containerized Applications
```

The environment demonstrates foundational concepts across:

* Linux administration
* Virtualization
* Networking
* Containerization
* Service discovery
* Reverse proxying
* Name resolution
* HTTP
* TLS
* Security
* Git-based documentation

---

## Portfolio Evidence

The sanitized implementation is maintained under:

```text
docker/reverse-proxy/
```

The repository includes:

```text
docker-compose.yml
nginx/default.conf
app1/index.html
app2/index.html
ssl/README.md
```

The `ssl/README.md` file documents how to generate the required local certificate.

Private cryptographic material is intentionally excluded.

---

## Next Steps

The next phase moves these infrastructure concepts into AWS.

The progression becomes:

```text
Local VM
   |
   v
Cloud VM / EC2

Local Networking
   |
   v
VPC Networking

Local Access Controls
   |
   v
Security Groups + IAM

Manual Infrastructure
   |
   v
Terraform

Local Monitoring
   |
   v
CloudWatch
```

The first AWS lab will focus on establishing the account and identity foundation before deploying cloud infrastructure.
