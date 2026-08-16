#!/bin/bash

set -e

apt-get update
apt-get install -y docker.io docker-compose-v2

systemctl enable --now docker

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

  app1:
    image: nginx
    container_name: tf-aws-app1
    restart: unless-stopped
    volumes:
      - ./app1:/usr/share/nginx/html:ro

  app2:
    image: nginx
    container_name: tf-aws-app2
    restart: unless-stopped
    volumes:
      - ./app2:/usr/share/nginx/html:ro
EOF

cd /opt/aws-web-lab
docker compose up -d
