#!/bin/bash
# setup.sh - Quick setup script for Docker Swarm Discord Monitor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                Docker Swarm Discord Monitor                  ║
║                      Quick Setup Script                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
info "Checking prerequisites..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker service."
    exit 1
fi

# Check if we're in a swarm
if ! docker node ls &> /dev/null; then
    warn "This node is not part of a Docker Swarm."
    echo "Would you like to initialize a new swarm? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Initializing Docker Swarm..."
        docker swarm init
        log "Swarm initialized successfully!"
    else
        warn "Continuing without swarm mode (single node deployment)"
    fi
fi

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    warn "docker-compose not found. Using 'docker compose' instead."
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

log "Prerequisites check completed!"

# Get Discord webhook URL
echo ""
info "Discord Webhook Configuration"
echo "To get your Discord webhook URL:"
echo "1. Go to your Discord server"
echo "2. Server Settings → Integrations → Webhooks"  
echo "3. Create New Webhook → Copy Webhook URL"
echo ""

while true; do
    echo -n "Enter your Discord Webhook URL: "
    read -r WEBHOOK_URL
    
    if [[ -z "$WEBHOOK_URL" ]]; then
        error "Webhook URL cannot be empty!"
        continue
    fi
    
    if [[ ! "$WEBHOOK_URL" =~ ^https://discord\.com/api/webhooks/ ]]; then
        error "Invalid Discord webhook URL format!"
        continue
    fi
    
    # Test webhook
    info "Testing webhook..."
    if curl -X POST -H "Content-Type: application/json" \
        -d '{"content":"🧪 Test message from Docker Swarm Monitor setup!"}' \
        --silent --fail "$WEBHOOK_URL" > /dev/null; then
        log "Webhook test successful! ✅"
        break
    else
        error "Webhook test failed! Please check the URL and try again."
    fi
done

# Choose deployment method
echo ""
info "Choose deployment method:"
echo "1) Docker Compose (single node)"
echo "2) Docker Swarm (all nodes)"
echo "3) Docker run (quick test)"
echo "4) Host installation (systemd service)"
echo ""
echo -n "Enter your choice (1-4): "
read -r DEPLOY_METHOD

case $DEPLOY_METHOD in
    1)
        info "Setting up Docker Compose deployment..."
        
        # Create .env file
        cat > .env << EOF
# Discord Webhook Configuration
DISCORD_WEBHOOK_URL=$WEBHOOK_URL

# Optional Configuration
LOG_LEVEL=INFO
RETRY_ATTEMPTS=3
TIMEOUT_SECONDS=30
DISCORD_USERNAME=Docker Swarm Monitor
DISCORD_AVATAR_URL=https://raw.githubusercontent.com/docker/compose/v2/logo.png
EOF
        
        log "Created .env file with your configuration"
        
        # Pull latest image or build
        if docker pull ghcr.io/your-username/docker-swarm-discord-monitor:latest 2>/dev/null; then
            log "Using pre-built image from GitHub Container Registry"
            # Update docker-compose.yml to use the image
            sed -i 's/build: \./image: ghcr.io\/your-username\/docker-swarm-discord-monitor:latest/' docker-compose.yml
        else
            warn "Pre-built image not available, will build locally"
        fi
        
        # Start the service
        log "Starting Docker Compose..."
        $COMPOSE_CMD up -d
        
        log "Deployment completed! 🎉"
        echo "View logs: $COMPOSE_CMD logs -f docker-monitor"
        ;;
        
    2)
        info "Setting up Docker Swarm deployment..."
        
        # Export environment variable
        export DISCORD_WEBHOOK_URL="$WEBHOOK_URL"
        
        # Deploy to swarm
        log "Deploying to Docker Swarm..."
        docker stack deploy -c docker-compose.swarm.yml discord-monitor
        
        log "Swarm deployment completed! 🎉"
        echo "View logs: docker service logs -f discord-monitor_docker-monitor"
        ;;
        
    3)
        info "Starting quick test deployment..."
        
        docker run -d \
            --name docker-monitor-test \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            -e DISCORD_WEBHOOK_URL="$WEBHOOK_URL" \
            -e LOG_LEVEL=DEBUG \
            ghcr.io/your-username/docker-swarm-discord-monitor:latest
        
        log "Test deployment started! 🎉"
        echo "View logs: docker logs -f docker-monitor-test"
        echo "Stop test: docker stop docker-monitor-test && docker rm docker-monitor-test"
        ;;
        
    4)
        info "Setting up host installation..."
        
        # Check if Python 3 is available
        if ! command -v python3 &> /dev/null; then
            error "Python 3 is required for host installation"
            exit 1
        fi
        
        # Install to /opt/docker-monitor
        INSTALL_DIR="/opt/docker-monitor"
        log "Installing to $INSTALL_DIR..."
        
        sudo mkdir -p "$INSTALL_DIR"
        sudo cp docker-monitor.py "$INSTALL_DIR/"
        sudo cp requirements.txt "$INSTALL_DIR/"
        
        # Install Python dependencies
        log "Installing Python dependencies..."
        sudo pip3 install -r "$INSTALL_DIR/requirements.txt"
        
        # Create systemd service
        sudo tee /etc/systemd/system/docker-monitor.service > /dev/null << EOF
[Unit]
Description=Docker Swarm Discord Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment=DISCORD_WEBHOOK_URL=$WEBHOOK_URL
Environment=LOG_LEVEL=INFO
ExecStart=/usr/bin/python3 $INSTALL_DIR/docker-monitor.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable and start service
        sudo systemctl daemon-reload
        sudo systemctl enable docker-monitor.service
        sudo systemctl start docker-monitor.service
        
        log "Host installation completed! 🎉"
        echo "Service status: sudo systemctl status docker-monitor"
        echo "View logs: sudo journalctl -u docker-monitor -f"
        ;;
        
    *)
        error "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Final instructions
echo ""
info "Setup Complete! 🚀"
echo ""
echo "Your Docker Swarm Discord Monitor is now running and will send"
echo "notifications to your Discord channel when containers start or stop."
echo ""
echo "Test it by running: docker run --rm hello-world"
echo ""
echo "Need help? Check the documentation or open an issue on GitHub."
echo "Repository: https://github.com/your-username/docker-swarm-discord-monitor"

---

# install.py - Alternative Python installer

#!/usr/bin/env python3
"""
Interactive installer for Docker Swarm Discord Monitor
"""

import os
import sys
import subprocess
import requests
import json
from pathlib import Path

def run_command(cmd, check=True):
    """Run a shell command"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"❌ Command failed: {cmd}")
        print(f"Error: {result.stderr}")
        sys.exit(1)
    return result

def test_webhook(url):
    """Test Discord webhook"""
    try:
        payload = {"content": "🧪 Test message from Docker Swarm Monitor installer!"}
        response = requests.post(url, json=payload, timeout=10)
        response.raise_for_status()
        return True
    except Exception as e:
        print(f"❌ Webhook test failed: {e}")
        return False

def main():
    print("🐳 Docker Swarm Discord Monitor - Python Installer")
    print("=" * 50)
    
    # Check Docker
    try:
        run_command("docker --version")
        print("✅ Docker found")
    except:
        print("❌ Docker not found. Please install Docker first.")
        sys.exit(1)
    
    # Get webhook URL
    while True:
        webhook_url = input("\n📡 Enter your Discord webhook URL: ").strip()
        if not webhook_url:
            print("❌ URL cannot be empty")
            continue
        if not webhook_url.startswith("https://discord.com/api/webhooks/"):
            print("❌ Invalid Discord webhook URL")
            continue
        if test_webhook(webhook_url):
            print("✅ Webhook test successful!")
            break
    
    # Choose installation method
    print("\n🚀 Choose installation method:")
    print("1. Docker Compose (recommended)")
    print("2. Docker Swarm")  
    print("3. Quick test run")
    
    choice = input("\nEnter choice (1-3): ").strip()
    
    if choice == "1":
        # Docker Compose
        env_content = f"""DISCORD_WEBHOOK_URL={webhook_url}
LOG_LEVEL=INFO
RETRY_ATTEMPTS=3
TIMEOUT_SECONDS=30
DISCORD_USERNAME=Docker Swarm Monitor"""
        
        with open(".env", "w") as f:
            f.write(env_content)
        
        print("✅ Created .env file")
        
        # Create docker-compose.yml if it doesn't exist
        if not Path("docker-compose.yml").exists():
            compose_content = """version: '3.8'
services:
  docker-monitor:
    image: ghcr.io/your-username/docker-swarm-discord-monitor:latest
    container_name: docker-monitor
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    env_file:
      - .env
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
"""
            with open("docker-compose.yml", "w") as f:
                f.write(compose_content)
            print("✅ Created docker-compose.yml")
        
        run_command("docker-compose up -d")
        print("🎉 Installation complete!")
        print("📋 View logs: docker-compose logs -f docker-monitor")
        
    elif choice == "2":
        # Docker Swarm
        os.environ["DISCORD_WEBHOOK_URL"] = webhook_url
        run_command("docker node ls")  # Verify swarm
        print("✅ Swarm mode confirmed")
        
        # Deploy stack
        run_command("docker stack deploy -c docker-compose.swarm.yml discord-monitor")
        print("🎉 Swarm deployment complete!")
        print("📋 View logs: docker service logs -f discord-monitor_docker-monitor")
        
    elif choice == "3":
        # Quick test
        cmd = f"""docker run -d \\
  --name docker-monitor-test \\
  -v /var/run/docker.sock:/var/run/docker.sock:ro \\
  -e DISCORD_WEBHOOK_URL="{webhook_url}" \\
  -e LOG_LEVEL=DEBUG \\
  ghcr.io/your-username/docker-swarm-discord-monitor:latest"""
        
        run_command(cmd)
        print("🎉 Test deployment started!")
        print("📋 View logs: docker logs -f docker-monitor-test")
        print("🛑 Stop test: docker stop docker-monitor-test && docker rm docker-monitor-test")
    
    else:
        print("❌ Invalid choice")
        sys.exit(1)
    
    print("\n🧪 Test your setup by running: docker run --rm hello-world")

if __name__ == "__main__":
    main()