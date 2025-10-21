#!/bin/sh

# Enable logging
LOGFILE="deploy_$(date +%Y%m%d).log"
exec > >(tee -i "$LOGFILE") 2>&1
trap 'echo "❌ Error occurred at line $LINENO"; exit 1' ERR

# Collect user input
read -p "Enter Git Repository URL: " REPO_URL
read -p "Enter Personal Access Token (PAT): " PAT
read -p "Enter Branch name [default: main]: " BRANCH
BRANCH=${BRANCH:-main}
read -p "Enter SSH Username: " SSH_USER
read -p "Enter Server IP Address: " SERVER_IP
read -p "Enter SSH Key Path: " SSH_KEY
read -p "Enter Application Port (internal container port): " APP_PORT

# Validate inputs
[ -z "$REPO_URL" ] && echo "Repository URL is required" && exit 1
[ -z "$PAT" ] && echo "PAT is required" && exit 1
[ -z "$SSH_USER" ] && echo "SSH Username is required" && exit 1
[ -z "$SERVER_IP" ] && echo "Server IP is required" && exit 1
[ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ] && echo "Valid SSH key path is required" && exit 1
[ -z "$APP_PORT" ] && echo "Application port is required" && exit 1

# Clone or update repository
REPO_AUTH_URL=$(echo "$REPO_URL" | sed "s#https://#https://$PAT@#")
REPO_NAME=$(basename "$REPO_URL" .git)
if [ -d "$REPO_NAME" ]; then
  cd "$REPO_NAME" && git pull origin "$BRANCH"
else
  git clone -b "$BRANCH" "$REPO_AUTH_URL"
  cd "$REPO_NAME"
fi

# Check for Dockerfile or docker-compose.yml
if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
  echo "✅ Docker configuration found."
else
  echo "❌ No Dockerfile or docker-compose.yml found." && exit 1
fi

# SSH connectivity check
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "echo 'SSH connection successful'"

# Prepare remote environment
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << EOF
  sudo apt update && sudo apt install -y docker.io docker-compose nginx
  sudo usermod -aG docker $USER
  sudo systemctl enable docker nginx
  sudo systemctl start docker nginx
  docker --version && docker-compose --version && nginx -v
EOF

# Transfer project files
rsync -avz -e "ssh -i $SSH_KEY" ./ "$SSH_USER@$SERVER_IP:/home/$SSH_USER/app"

# Deploy Dockerized application
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << EOF
  cd /home/$SSH_USER/app
  docker-compose down || docker stop $(docker ps -q) && docker rm $(docker ps -aq)
  docker-compose up -d --build || docker build -t app . && docker run -d -p $APP_PORT:$APP_PORT app
  docker ps
EOF

# Configure Nginx reverse proxy
NGINX_CONF="/etc/nginx/sites-available/app"
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << EOF
  sudo bash -c 'cat > $NGINX_CONF' << EOL
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL
  sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/app
  sudo nginx -t && sudo systemctl reload nginx
EOF

# Validate deployment
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << EOF
  docker ps
  curl -I http://localhost:$APP_PORT
  curl -I http://localhost
EOF

# Optional cleanup
if [ "$1" = "--cleanup" ]; then
  ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" << EOF
    docker-compose down || docker stop $(docker ps -q) && docker rm $(docker ps -aq)
    sudo rm -rf /home/$SSH_USER/app
    sudo rm /etc/nginx/sites-available/app
    sudo rm /etc/nginx/sites-enabled/app
    sudo systemctl reload nginx
EOF
  echo "✅ Cleanup complete."
  exit 0
fi

echo "✅ Deployment completed successfully."
