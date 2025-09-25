# 🚀 Azure Deployment Guide for GenAI Power Users

## 📋 Pre-Deployment Checklist

- [x] Azure subscription with credits
- [x] NCasT4v3 quota (8 vCPUs approved)
- [x] Azure CLI logged in
- [ ] Review costs (~$400-600/month with spot instances)
- [ ] Backup existing data if migrating

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                 Azure Resource Group                 │
│                   genai-power-rg                     │
├─────────────────────────┬───────────────────────────┤
│      GPU VM (Spot)      │      CPU VM (Reserved)    │
│    NC8as_T4_v3          │       D8s_v5              │
│  - Ollama               │  - PostgreSQL/Redis       │
│  - ComfyUI              │  - Open-WebUI             │
│  - Deep Researcher      │  - n8n                    │
│  - Weaviate             │  - Backend API            │
│  8 vCPU, 56GB, T4 GPU   │  8 vCPU, 32GB            │
├─────────────────────────┴───────────────────────────┤
│              Azure Managed Services                  │
│  - Azure OpenAI (GPT-4, DALL-E)                     │
│  - Azure PostgreSQL Flexible Server                 │
│  - Azure Cache for Redis                            │
│  - Blob Storage (Models, Research)                  │
│  - Key Vault (Secrets)                              │
└─────────────────────────────────────────────────────┘
```

## 🚀 Deployment Steps

### Step 1: Deploy Azure Infrastructure

```bash
# Make script executable
chmod +x azure-deployment/deploy-azure-stack.sh

# Run deployment (takes ~10-15 minutes)
./azure-deployment/deploy-azure-stack.sh
```

This creates:
- Resource group with all services
- VMs (GPU spot + CPU regular)
- Managed services (PostgreSQL, Redis, Storage)
- Azure OpenAI with GPT-4
- Network security rules
- Key Vault for secrets

### Step 2: Configure VMs

#### GPU VM Setup
```bash
# Copy .env.azure to GPU VM
scp .env.azure genaiuser@<GPU_IP>:/tmp/

# SSH to GPU VM
ssh genaiuser@<GPU_IP>

# Run setup script
curl -O https://raw.githubusercontent.com/yourusername/genai-vanilla/main/azure-deployment/setup-gpu-vm.sh
chmod +x setup-gpu-vm.sh
./setup-gpu-vm.sh
```

#### Core VM Setup
```bash
# SSH to Core VM
ssh genaiuser@<CORE_IP>

# Clone repository
git clone https://github.com/yourusername/genai-vanilla.git
cd genai-vanilla

# Copy Azure config
cp /tmp/.env.azure .env

# Start core services
./start.sh
```

### Step 3: Verify Deployment

```bash
# Check GPU services
ssh genaiuser@<GPU_IP> "./check-gpu.sh"

# Check core services
curl http://<CORE_IP>:63015  # Open-WebUI
curl http://<CORE_IP>:63017  # n8n
curl http://<CORE_IP>:63026/v1/health  # ACI Backend
```

## 💰 Cost Optimization

### Current Monthly Costs
```
GPU VM (Spot):         ~$150  (vs $450 regular)
CPU VM (Reserved):     ~$140  (vs $280 regular)
PostgreSQL:            ~$50
Redis:                 ~$50
Storage:               ~$20
Azure OpenAI:          Usage-based (~$100-500)
-------------------
Total:                 ~$510 + OpenAI usage
```

### Cost Saving Tips

1. **Use Spot Instances for GPU**
   - 60-70% cheaper
   - Set max price: $0.20/hour
   - Auto-restart on eviction

2. **Schedule GPU VM**
   ```bash
   # Auto-shutdown at night
   az vm auto-shutdown \
     --resource-group genai-power-rg \
     --name genai-gpu-vm \
     --time 2300
   ```

3. **Use Reserved Instances**
   - 1-year: Save 40%
   - 3-year: Save 60%

4. **Monitor Usage**
   ```bash
   # Check costs
   az consumption usage list \
     --start-date 2024-01-01 \
     --end-date 2024-01-31
   ```

## 👥 Power User Configuration

### User Onboarding
```bash
# Create user namespace
./azure-deployment/create-user.sh user001 "Power User Alpha"

# Assign resources
- Database schema: user_001
- Blob container: user-001
- Redis DB: 1
- GPU hours: 100/month
```

### Resource Limits per User
```yaml
Premium Tier:
  gpu_hours_monthly: 100
  storage_gb: 100
  api_calls_daily: 10000
  concurrent_research: 3
  
Standard Tier:
  gpu_hours_monthly: 50
  storage_gb: 50
  api_calls_daily: 5000
  concurrent_research: 1
```

## 🔧 Management Commands

### Start/Stop VMs
```bash
# Stop GPU VM (save money when not needed)
az vm deallocate \
  --resource-group genai-power-rg \
  --name genai-gpu-vm

# Start GPU VM
az vm start \
  --resource-group genai-power-rg \
  --name genai-gpu-vm
```

### Backup Data
```bash
# Backup PostgreSQL
az postgres flexible-server backup create \
  --resource-group genai-power-rg \
  --server-name genai-postgres \
  --backup-name backup-$(date +%Y%m%d)

# Snapshot blob storage
az storage blob snapshot \
  --account-name $STORAGE_ACCOUNT \
  --container-name user-data
```

### Scale Resources
```bash
# Upgrade CPU VM
az vm resize \
  --resource-group genai-power-rg \
  --name genai-core-vm \
  --size Standard_D16s_v5

# Add more GPU VMs
./azure-deployment/add-gpu-node.sh
```

## 📊 Monitoring

### Azure Monitor Dashboard
1. Go to Azure Portal
2. Create Dashboard
3. Add widgets:
   - VM CPU/Memory usage
   - GPU utilization
   - PostgreSQL connections
   - Storage usage
   - Cost analysis

### Alerts
```bash
# CPU > 80% alert
az monitor metrics alert create \
  --name high-cpu \
  --resource-group genai-power-rg \
  --scopes /subscriptions/.../VMs/genai-core-vm \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m
```

## 🔐 Security Best Practices

1. **Network Security**
   - Only expose necessary ports
   - Use Azure Bastion for SSH
   - Enable DDoS protection

2. **Secrets Management**
   - Store all secrets in Key Vault
   - Rotate keys quarterly
   - Use Managed Identity

3. **Data Protection**
   - Enable encryption at rest
   - Regular backups
   - Geo-redundant storage

## 🚨 Troubleshooting

### GPU Not Available
```bash
# Check GPU status
nvidia-smi

# Restart Docker with GPU
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

### Spot VM Evicted
```bash
# Check eviction
az vm get-instance-view \
  --resource-group genai-power-rg \
  --name genai-gpu-vm \
  --query instanceView.statuses[1]

# Restart
az vm start \
  --resource-group genai-power-rg \
  --name genai-gpu-vm
```

### Connection Issues
```bash
# Check NSG rules
az network nsg rule list \
  --resource-group genai-power-rg \
  --nsg-name genai-nsg

# Check VM status
az vm list -d \
  --resource-group genai-power-rg \
  --query "[].{Name:name, Status:powerState}"
```

## 📈 Scaling Path

### Phase 1: Current (3-5 users)
- Single GPU VM (spot)
- Single CPU VM
- Shared resources

### Phase 2: Growth (10 users)
- 2x GPU VMs
- Load balanced CPU VMs
- User quotas

### Phase 3: Scale (20+ users)
- Azure Kubernetes Service
- GPU node pool
- Auto-scaling

## 🎯 Next Steps

1. [ ] Complete deployment
2. [ ] Configure first power user
3. [ ] Test all services
4. [ ] Set up monitoring
5. [ ] Document user onboarding
6. [ ] Schedule cost review

## 📞 Support

- Azure Support: Portal tickets
- GenAI Issues: GitHub
- Architecture Questions: Team Discord

---

**Remember**: This is optimized for power users, not public access. Keep security tight! 🔐
