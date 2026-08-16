#!/bin/bash
set -euxo pipefail

# ============================================================
# 1. SYSTEM UPDATES
# ============================================================

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y


# ============================================================
# 2. INSTALL REQUIRED PACKAGES
# ============================================================

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker.io \
  docker-compose-v2 \
  ufw \
  unattended-upgrades


# ============================================================
# 3. SSH HARDENING
# ============================================================

cat > /etc/ssh/sshd_config.d/00-homelab-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
EOF

/usr/sbin/sshd -t
systemctl reload ssh


# ============================================================
# 4. HOST FIREWALL
# ============================================================

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp comment 'SSH administration'
ufw allow 80/tcp comment 'Nginx web application'

ufw --force enable


# ============================================================
# 5. AUTOMATIC SECURITY UPDATES
# ============================================================

systemctl enable --now unattended-upgrades


# ============================================================
# 6. DOCKER
# ============================================================

systemctl enable --now docker

# ============================================================
# 7. APPLICATION DIRECTORIES / FILES
# ============================================================

mkdir -p /opt/aws-web-lab/app1
mkdir -p /opt/aws-web-lab/app2
mkdir -p /opt/aws-web-lab/nginx

cat > /opt/aws-web-lab/app1/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Terraform AWS Lab - App 1</title>
</head>
<body>
    <h1>App 1 - Terraform AWS Lab</h1>
    <p>This application was automatically deployed during EC2 bootstrap.</p>
</body>
</html>
EOF

cat > /opt/aws-web-lab/app2/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Terraform AWS Lab - App 2</title>
</head>
<body>
    <h1>App 2 - Terraform AWS Lab</h1>
    <p>Terraform provisioned the infrastructure and bootstrapped this application.</p>
</body>
</html>
EOF

cat > /opt/aws-web-lab/nginx/default.conf <<'EOF'
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
EOF

# ============================================================
# 8. HARDENED DOCKER COMPOSE CONFIGURATION
# ============================================================

cat > /opt/aws-web-lab/docker-compose.yml <<'EOF'
services:
  reverse-proxy:
    image: nginx
    container_name: tf-aws-reverse-proxy
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app1
      - app2
    security_opt:
      - no-new-privileges:true

  app1:
    image: nginx
    container_name: tf-aws-app1
    restart: unless-stopped
    volumes:
      - ./app1:/usr/share/nginx/html:ro
    security_opt:
      - no-new-privileges:true

  app2:
    image: nginx
    container_name: tf-aws-app2
    restart: unless-stopped
    volumes:
      - ./app2:/usr/share/nginx/html:ro
    security_opt:
      - no-new-privileges:true
EOF


# ============================================================
# 9. START APPLICATION
# ============================================================

cd /opt/aws-web-lab
docker compose config
docker compose up -d
