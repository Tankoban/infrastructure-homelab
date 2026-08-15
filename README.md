# Linux, Cloud & Security Infrastructure Homelab

A hands-on infrastructure lab documenting my transition into Linux administration, cloud engineering, and cybersecurity.

This repository contains practical work performed in a local Linux homelab, including Linux workstation configuration, Ubuntu Server administration, Docker containerization, Nginx reverse proxying, local DNS resolution, TLS encryption, and eventually AWS and Terraform infrastructure.

## Current Architecture

Linux Mint Workstation  
↓  
KVM / QEMU  
↓  
Ubuntu Server VM  
↓  
Docker  
↓  
Docker Compose  
↓  
Nginx Reverse Proxy  
↓  
Containerized Applications

The environment is currently accessible only within the local lab network.

## Technologies

- Linux Mint
- Ubuntu Server
- Bash / Zsh
- SSH
- Git / GitHub
- Docker
- Docker Compose
- KVM / QEMU
- Nginx
- OpenSSL / TLS
- Wireshark
- Nmap
- AWS CLI
- Azure CLI
- Terraform
- PowerShell

## Labs

| Lab | Technologies | Status |
|---|---|---|
| Linux Workstation Migration | Mint, UEFI, Zsh, KVM | Complete |
| Ubuntu Server Administration | Ubuntu Server, SSH | Complete |
| Docker Fundamentals | Docker, Nginx | Complete |
| Docker Compose | Docker Compose, YAML | Complete |
| Reverse Proxy | Nginx, Docker networking | Complete |
| Local Hostname Routing | `/etc/hosts`, Nginx | Complete |
| HTTPS / TLS | OpenSSL, Nginx | Complete |
| AWS Foundations | AWS | In Progress |
| Infrastructure as Code | Terraform | Planned |

## Repository Structure


docs/       Technical documentation and walkthroughs
docker/     Docker and Nginx configurations
terraform/  Infrastructure-as-Code projects
scripts/    Administrative and automation scripts
diagrams/   Architecture diagrams

## Goals

The purpose of this lab is to build practical experience in:

Linux systems administration
Cloud infrastructure
Infrastructure as Code
Networking
Containerization
Identity and access management
Infrastructure security
Troubleshooting and technical documentation
