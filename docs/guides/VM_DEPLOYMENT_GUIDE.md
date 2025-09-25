# GenAI Vanilla Stack - VM Deployment Guide

## Current Local Configuration
- **Date**: January 2025
- **Local Environment**: macOS 15.7, ARM64 (Apple Silicon)
- **Docker**: v28.3.3 with 54GB memory
- **Services**: 19 containers running successfully

## Configuration Summary

### Service Modes (from .env)
```bash
# Core Services
LLM_PROVIDER_SOURCE=api  # Using OpenAI API
COMFYUI_SOURCE=container-cpu  # Container-based image generation
WEAVIATE_SOURCE=container  # Vector database for RAG
N8N_SOURCE=container  # Workflow automation
SEARXNG_SOURCE=container  # Web search engine

# Infrastructure (always container-based)
SUPABASE_DB_SOURCE=container
REDIS_SOURCE=container
NEO4J_GRAPH_DB_SOURCE=container
```

### Ports Configuration
Base port: 63000 (all services use BASE_PORT + offset)
- Database: 63000
- Redis: 63001
- Kong Gateway: 63002-63003
- Supabase Services: 63004-63009
- Neo4j: 63010-63011
- Deep Researcher: 63013
- SearxNG: 63014
- Open-WebUI: 63015
- Backend API: 63016
- n8n: 63017
- ComfyUI: 63018
- Weaviate: 63019-63020

## VM Requirements

### Minimum Specifications
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 16GB minimum (32GB+ recommended)
- **Storage**: 50GB+ free space
- **OS**: Ubuntu 22.04 LTS or similar
- **Docker**: Latest stable version
- **Docker Compose**: v2.0+

### Network Requirements
- Ports 63000-63020 available
- Outbound internet for:
  - Docker image downloads
  - OpenAI API calls
  - Web search (SearxNG)
  - Model downloads (ComfyUI)

## Deployment Steps

### 1. Prepare VM
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Install required tools
sudo apt install git python3 python3-pip curl jq -y
```

### 2. Clone Repository
```bash
git clone https://github.com/[your-fork]/genai-vanilla.git
cd genai-vanilla
```

### 3. Configure Environment
```bash
# Copy your local .env to VM
# IMPORTANT: Remove or regenerate sensitive keys!

# Generate new Supabase keys
cd bootstrapper
./generate_supabase_keys.sh
cd ..

# Edit .env and update:
# - OPENAI_API_KEY (if different)
# - Any localhost references to proper hostnames
# - SEARXNG_PUBLIC_INSTANCE=true (if external access needed)
```

### 4. VM-Specific Configurations

#### For Cloud VMs (AWS/Azure/GCP)
```bash
# Update .env for external access
# Replace localhost with VM's public IP or domain
# Configure security groups/firewall for ports 63000-63020

# For production, consider:
# - Using a reverse proxy (nginx/traefik)
# - SSL certificates
# - Firewall rules
```

#### For GPU Support
```bash
# If VM has NVIDIA GPU:
# 1. Install NVIDIA Docker runtime
# 2. Update .env:
LLM_PROVIDER_SOURCE=ollama-container-gpu
COMFYUI_SOURCE=container-gpu
MULTI2VEC_CLIP_SOURCE=container-gpu
```

### 5. Start Services
```bash
# Start all services
./start.sh

# Or with custom base port
./start.sh --base-port 64000

# Monitor startup
docker compose logs -f
```

### 6. Verify Deployment
```bash
# Check all services are running
docker ps

# Test endpoints
curl http://localhost:63015  # Open-WebUI
curl http://localhost:63016  # Backend API
curl http://localhost:63017  # n8n
```

## Migration Checklist

### Before Migration
- [ ] Backup local .env configuration
- [ ] Document any custom workflows in n8n
- [ ] Export any ComfyUI custom nodes/models
- [ ] Note Weaviate collections if any

### After Migration
- [ ] Regenerate Supabase JWT keys
- [ ] Update OPENAI_API_KEY if needed
- [ ] Configure domain/SSL if public facing
- [ ] Set up monitoring (optional)
- [ ] Configure backups for persistent data

## Data Persistence

The following directories contain persistent data:
```
volumes/
├── supabase-db/      # PostgreSQL data
├── neo4j/            # Graph database
├── weaviate/         # Vector database
├── n8n/              # Workflow configurations
├── comfyui/          # Models and outputs
└── redis/            # Cache data
```

## Troubleshooting

### Common Issues
1. **Port conflicts**: Change BASE_PORT in start.sh
2. **Memory issues**: Adjust Docker memory limits
3. **Slow startup**: ComfyUI models download on first run
4. **Auth issues**: Regenerate Supabase keys

### Health Checks
```bash
# Check service health
docker ps --filter "health=unhealthy"

# View logs
docker compose logs [service-name]

# Restart specific service
docker compose restart [service-name]
```

## Security Considerations

1. **API Keys**: Store securely, use environment variables
2. **Firewall**: Only expose necessary ports
3. **Updates**: Keep Docker images updated
4. **Backups**: Regular backups of volumes/
5. **Monitoring**: Set up logging and monitoring

## Support Resources

- GitHub Issues: [your-repo]/issues
- Documentation: /docs/
- Service configs: bootstrapper/service-configs.yml
- Environment template: .env.example

---
Generated: January 2025
Stack Version: GenAI Vanilla v1.0
