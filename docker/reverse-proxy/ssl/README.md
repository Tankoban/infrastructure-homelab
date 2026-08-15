# Local TLS Certificates

TLS certificates and private keys are intentionally excluded from this repository.

This project uses locally generated, self-signed TLS certificates to provide HTTPS for the reverse proxy lab.

## Generate a Self-Signed Certificate

Before starting the Docker Compose stack, generate a certificate and private key with OpenSSL:

```bash
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout lab.key \
  -out lab.crt
```

When prompted for the **Common Name (CN)**, use:

```text
*.lab
```

## Expected Files

Place the generated certificate and private key in this directory:

```text
ssl/
├── README.md
├── lab.crt
└── lab.key
```

The Docker Compose configuration mounts this directory into the Nginx reverse proxy container.

## Security

The private key:

```text
lab.key
```

must **never be committed to source control**.

Private key files are excluded by the repository's `.gitignore` configuration.

The certificate:

```text
lab.crt
```

contains public certificate information, but the locally generated certificate is also excluded from this repository because each user should generate their own certificate for their environment.

## Lab Scope

These certificates are self-signed and intended only for local lab use.

Because the certificate is not signed by a publicly trusted Certificate Authority (CA), browsers will display a certificate trust warning when accessing the lab applications over HTTPS.

This is expected behavior for this lab.
