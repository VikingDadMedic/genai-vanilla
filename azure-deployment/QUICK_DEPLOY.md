# 🚀 Quick Azure Deployment Guide

## Current Status
✅ **All deployment scripts ready**
⚠️ **Azure CLI needs to be installed**

## Local Development + Cloud Deployment Strategy

### How It Works:
```
Local Mac (Development)          GitHub              Azure (Production)
    │                              │                      │
    ├── Code changes ──────────────├──> Push ────────────>│
    │                              │                      │
    ├── Docker Compose (local) ────┤                      ├── Container Apps
    │                              │                      │
    └── Full control               └── Version Control    └── Auto-scaling
```

### ✅ **YES! You can:**
- Work locally on your Mac
- Push changes to GitHub
- Deploy to Azure Container Apps
- Have both running simultaneously
- Sync configurations via Git

## 🎯 Deployment Prerequisites

### 1. Install Azure CLI (Mac)
```bash
# Install via Homebrew
brew update && brew install azure-cli

# Or download directly
curl -L https://aka.ms/InstallAzureCli | bash
```

### 2. Login to Azure
```bash
# Login
az login

# Set subscription
az account set --subscription "1992b163-f828-4887-90c0-b6d26c8ab353"
```

### 3. Deploy in Background (Once Azure CLI is ready)
```bash
# Make script executable
chmod +x azure-deployment/container-apps/deploy-aca.sh

# Run deployment in background
nohup ./azure-deployment/container-apps/deploy-aca.sh > azure-deployment.log 2>&1 &

# Monitor progress
tail -f azure-deployment.log
```

## 🔄 Development Workflow

### Local Development (Your Mac)
```bash
# Work locally as usual
docker-compose up -d

# Make changes
edit files...

# Test locally
curl http://localhost:63015  # Open-WebUI
```

### Push to GitHub
```bash
git add .
git commit -m "Feature update"
git push origin main
```

### Update Azure Deployment
```bash
# Option 1: Manual update specific service
az containerapp update \
  -n open-webui \
  -g genai-aca-rg \
  --image ghcr.io/open-webui/open-webui:latest

# Option 2: Use CI/CD (GitHub Actions)
# Automatically deploys on push to main
```

## 📊 Why Deploy Now?

### Benefits of Parallel Development:
1. **Test in production environment** while developing locally
2. **Share with team/users** without exposing local machine
3. **Validate Azure OpenAI integration** early
4. **Get real performance metrics**
5. **Set up monitoring** while you work

### No Interference:
- ✅ Different ports (local vs cloud)
- ✅ Different databases (local vs Azure PostgreSQL)
- ✅ Different URLs (localhost vs *.azurecontainerapps.io)
- ✅ Independent scaling

## 🚨 Quick Deployment Script

Save this as `quick-deploy.sh`:

```bash
#!/bin/bash

echo "🚀 Starting Azure Deployment for GenAI Stack"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install azure-cli
    else
        curl -L https://aka.ms/InstallAzureCli | bash
    fi
fi

# Login to Azure
echo "🔐 Logging into Azure..."
az login

# Set subscription
az account set --subscription "1992b163-f828-4887-90c0-b6d26c8ab353"

# Run deployment
echo "🏗️ Starting deployment (this will take ~30 minutes)..."
./azure-deployment/container-apps/deploy-aca.sh

echo "✅ Deployment complete!"
```

## 📝 Environment Separation

### Local (.env)
```env
DATABASE_URL=postgresql://localhost:54322/genai
REDIS_URL=redis://localhost:63379
BASE_URL=http://localhost:63015
```

### Azure (.env.azure)
```env
DATABASE_URL=postgresql://azure-postgres/genai
REDIS_URL=redis://azure-redis:6379
BASE_URL=https://genai.azurecontainerapps.io
```

## 🎮 Management Commands

### Check Deployment Status
```bash
# List all container apps
az containerapp list -g genai-aca-rg -o table

# View specific app logs
az containerapp logs show -n open-webui -g genai-aca-rg --follow
```

### Scale Services
```bash
# Scale up for production
az containerapp update -n open-webui -g genai-aca-rg --max-replicas 10

# Scale down to save costs
az containerapp update -n open-webui -g genai-aca-rg --max-replicas 1
```

## 💰 Cost Control

### While Developing:
- **Scale to minimum** (1 replica each)
- **Use spot instances** for GPU
- **Stop services** not in use

```bash
# Stop a service (scale to 0)
az containerapp update -n comfyui -g genai-aca-rg --min-replicas 0 --max-replicas 0

# Restart when needed
az containerapp update -n comfyui -g genai-aca-rg --min-replicas 1 --max-replicas 3
```

## ✅ No Blockers to Deploy Now!

The only requirement is Azure CLI installation. Once that's done (5 minutes), you can deploy immediately:

1. **Install Azure CLI** (if not installed)
2. **Run deployment script** in background
3. **Continue local development** 
4. **Check deployment** in ~30 minutes

Both environments (local and Azure) will work independently! 🎉
