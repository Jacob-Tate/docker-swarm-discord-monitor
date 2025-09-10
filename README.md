# Docker Swarm Discord Monitor

🐳 **Monitor your Docker Swarm container events and get beautiful Discord notifications!**

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Discord](https://img.shields.io/badge/Discord-%235865F2.svg?style=for-the-badge&logo=discord&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)

## Features

- 🔔 **Real-time notifications** for container start/stop events
- 🎨 **Beautiful Discord embeds** with colors and emojis
- 🌐 **Multi-platform support** (AMD64, ARM64)
- 🔄 **Automatic retry logic** for webhook delivery
- 📊 **Comprehensive logging** and health checks
- 🔐 **Security-first approach** with non-root containers
- 🚀 **Easy deployment** with Docker Compose or Swarm

## Quick Start

### 1. Set Up Discord Webhook

1. Go to your Discord server
2. Navigate to **Server Settings** → **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Choose a channel and copy the webhook URL
5. Save the URL for later use

### 2. Deploy with Docker Compose (Single Node)

```bash
# Clone the repository
git clone https://github.com/your-username/docker-swarm-discord-monitor.git
cd docker-swarm-discord-monitor

# Copy environment file
cp .env.example .env

# Edit .env file with your Discord webhook URL
nano .env

# Start the monitor
docker-compose up -d
```

### 3. Deploy with Docker Swarm (Multi-Node)

```bash
# Set environment variable
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"

# Deploy to swarm (monitors all nodes)
docker stack deploy -c docker-compose.swarm.yml discord-monitor
```

### 4. Quick Run (Development)

```bash
docker run -d \
  --name docker-monitor \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL" \
  ghcr.io/your-username/docker-swarm-discord-monitor:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISCORD_WEBHOOK_URL` | **Required** | Your Discord webhook URL |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `RETRY_ATTEMPTS` | `3` | Number of retry attempts for failed webhooks |
| `TIMEOUT_SECONDS` | `30` | Webhook request timeout |
| `DISCORD_USERNAME` | `Docker Swarm Monitor` | Bot username in Discord |
| `DISCORD_AVATAR_URL` | Docker logo | Bot avatar URL |
| `DEDUP_WINDOW` | `10` | Seconds to prevent duplicate notifications |

## Discord Notification Examples

### Container Started
```
🟢 Container Started
📦 Container: myapp_web.1.abc123def
🔧 Service: myapp_web  
🖥️ Node: swarm-node-01
✅ Container is now running
```

### Container Stopped
```
🔴 Container Stopped
📦 Container: myapp_web.1.abc123def
🔧 Service: myapp_web
🖥️ Node: swarm-node-01  
❌ Container has stopped
```

## GitHub Actions Setup

### 1. Repository Setup

1. Fork/clone this repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username (optional) |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token (optional) |

### 2. Automatic Builds

The GitHub workflow automatically:
- ✅ Builds multi-platform Docker images (AMD64, ARM64)
- ✅ Pushes to GitHub Container Registry (`ghcr.io`)
- ✅ Pushes to Docker Hub (if credentials provided)
- ✅ Runs security scans with Trivy
- ✅ Generates Software Bill of Materials (SBOM)
- ✅ Creates releases for tagged versions

### 3. Using Built Images

After the workflow runs, use the pre-built images:

```bash
# From GitHub Container Registry (recommended)
docker pull ghcr.io/your-username/docker-swarm-discord-monitor:latest

# From Docker Hub (if configured)
docker pull your-dockerhub-username/docker-swarm-discord-monitor:latest
```

## Manual Build

```bash
# Build locally
docker build -t docker-swarm-discord-monitor .

# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 -t your-repo/docker-swarm-discord-monitor .
```

## Advanced Configuration

### Custom Discord Styling

```bash
# Custom bot appearance
export DISCORD_USERNAME="🐳 Production Monitor"
export DISCORD_AVATAR_URL="https://your-domain.com/custom-avatar.png"
```

### Resource Limits

```yaml
# In docker-compose.swarm.yml
deploy:
  resources:
    limits:
      memory: 128M
      cpus: '0.1'
    reservations:
      memory: 64M
      cpus: '0.05'
```

### Monitoring Multiple Swarms

Deploy the monitor on each swarm with different Discord channels:

```bash
# Production swarm
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/PROD_WEBHOOK"
docker stack deploy -c docker-compose.swarm.yml prod-monitor

# Staging swarm  
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/STAGING_WEBHOOK"
docker stack deploy -c docker-compose.swarm.yml staging-monitor
```

## Troubleshooting

### Check Logs
```bash
# Docker Compose
docker-compose logs -f docker-monitor

# Docker Swarm
docker service logs -f discord-monitor_docker-monitor
```

### Common Issues

**❌ "Not connected to Docker Swarm"**
- Ensure the node is part of a swarm: `docker node ls`
- Initialize swarm: `docker swarm init`

**❌ "Webhook failed"**
- Verify Discord webhook URL is correct
- Check Discord channel permissions
- Test webhook manually:
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"content":"Test message"}' \
  "YOUR_WEBHOOK_URL"
```

**❌ Permission denied on `/var/run/docker.sock`**
- Ensure Docker socket is accessible
- Check container user permissions

### Health Check

```bash
# Check container health
docker ps --filter name=docker-monitor

# Manual health check
docker exec docker-monitor python -c "import docker; docker.from_env().ping()"
```

## Security Considerations

- ✅ **Non-root container** - Runs as unprivileged user
- ✅ **Read-only Docker socket** - Cannot modify containers
- ✅ **Minimal attack surface** - Only required dependencies
- ✅ **Regular security scans** - Automated vulnerability scanning
- ✅ **Resource limits** - Prevents resource exhaustion

## Development

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment
export DISCORD_WEBHOOK_URL="your_webhook_url"
export LOG_LEVEL="DEBUG"

# Run locally
python docker-monitor.py
```

### Testing

```bash
# Test container events
docker run --rm hello-world

# Test webhook delivery
curl -X POST -H "Content-Type: application/json" \
  -d '{"content":"Test from curl"}' \
  "$DISCORD_WEBHOOK_URL"
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 **Documentation**: Check this README
- 🐛 **Bug Reports**: [Open an issue](https://github.com/your-username/docker-swarm-discord-monitor/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-username/docker-swarm-discord-monitor/discussions)
- 🔧 **Discord Webhook Setup**: [Discord Documentation](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)

---

**Made with ❤️ for the Docker community**