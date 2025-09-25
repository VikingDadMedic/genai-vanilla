# ✅ Azure Production Deployment Checklist

## 📋 Pre-Deployment

- [ ] **Azure Credits Available** (Need ~$500-600/month)
- [ ] **NCasT4v3 Quota Confirmed** (8 vCPUs approved ✓)
- [ ] **Azure CLI Logged In** ✓
- [ ] **SSH Keys Generated** (`~/.ssh/id_rsa.pub`)
- [ ] **Git Repository Ready** (commit all changes)

## 🚀 Phase 1: Infrastructure Deployment

### Step 1: Deploy Azure Resources
```bash
# Run the main deployment script (~15 minutes)
./azure-deployment/azure-prod-deployment.sh
```

This creates:
- [ ] Resource Group (`genai-prod-rg`)
- [ ] Virtual Network & Security Groups
- [ ] GPU VM (NC8as_T4_v3 - Spot Instance)
- [ ] Core VM (D8s_v5 - Regular)
- [ ] Azure PostgreSQL (3 databases)
- [ ] Azure Redis Cache
- [ ] Azure OpenAI (GPT-4, GPT-3.5, Embeddings)
- [ ] Storage Account (Blob + File Share)
- [ ] Container Registry
- [ ] Key Vault

**Verify Output:**
- [ ] Note down GPU VM IP: `_____________`
- [ ] Note down Core VM IP: `_____________`
- [ ] Check `.env.azure.prod` generated
- [ ] Check `DEPLOYMENT_SUMMARY.md` created

## 🖥️ Phase 2: VM Configuration

### Step 2: Configure Virtual Machines
```bash
# Setup both VMs with Docker and services (~10 minutes)
./azure-deployment/setup-vms.sh
```

**GPU VM Services:**
- [ ] Docker + NVIDIA Container Toolkit installed
- [ ] Ollama running (with models)
- [ ] ComfyUI accessible
- [ ] Weaviate running
- [ ] Deep Researcher configured

**Core VM Services:**
- [ ] Docker installed
- [ ] Open-WebUI running
- [ ] n8n configured
- [ ] Backend API running
- [ ] SearxNG running
- [ ] ACI services deployed

### Step 3: Verify Services
```bash
# Check all services are running
./azure-deployment/check-production.sh
```

- [ ] Open-WebUI: http://CORE_IP:63015
- [ ] n8n: http://CORE_IP:63017
- [ ] Backend API: http://CORE_IP:63016/docs
- [ ] ComfyUI: http://GPU_IP:63018
- [ ] ACI Portal: http://CORE_IP:63027

## 🔄 Phase 3: Dev/Prod Sync Setup

### Step 4: Configure Sync
```bash
# Setup dev/prod synchronization
./azure-deployment/setup-sync.sh
```

This configures:
- [ ] Azure Storage sync tools (azcopy)
- [ ] File watcher (fswatch on macOS)
- [ ] Git hooks for auto-sync
- [ ] Sync scripts created
- [ ] Production VMs configured for sync

### Step 5: Test Sync
```bash
# Test pushing changes to production
echo "test" > test.txt
./sync-to-prod.sh

# Test pulling from production
./sync-from-prod.sh
```

- [ ] Files sync to Azure Storage
- [ ] Production services reload
- [ ] Research data pulls back

## 🎯 Phase 4: Service Configuration

### Open-WebUI Setup
1. [ ] Access http://CORE_IP:63015
2. [ ] Create admin account (first user)
3. [ ] Configure Azure OpenAI connection
4. [ ] Import Tools from `open-webui/tools/`
5. [ ] Import Functions from `open-webui/functions/`
6. [ ] Test chat with GPT-4

### n8n Workflows
1. [ ] Access http://CORE_IP:63017
2. [ ] Import workflows from `n8n/workflows/`
3. [ ] Configure webhook URLs
4. [ ] Test workflow execution
5. [ ] Set up automation schedules

### ComfyUI Models
1. [ ] Access http://GPU_IP:63018
2. [ ] Verify SDXL model loaded
3. [ ] Test image generation
4. [ ] Configure custom workflows

### ACI Portal
1. [ ] Access http://CORE_IP:63027
2. [ ] Create API keys
3. [ ] Configure tool access
4. [ ] Test tool execution

## 📊 Phase 5: Monitoring & Optimization

### Cost Optimization
- [ ] Enable GPU VM auto-shutdown (11 PM)
- [ ] Set up spot instance restart policy
- [ ] Configure backup schedule
- [ ] Review resource usage

```bash
# Set auto-shutdown
az vm auto-shutdown \
  --resource-group genai-prod-rg \
  --name genai-gpu-prod \
  --time 2300
```

### Monitoring Setup
- [ ] Azure Monitor dashboard created
- [ ] Cost alerts configured ($600 threshold)
- [ ] Service health checks scheduled
- [ ] Log collection enabled

## 🔐 Phase 6: Security Hardening

### Network Security
- [ ] Update NSG rules with your IP only
- [ ] Enable Azure DDoS Protection (optional)
- [ ] Configure Azure Firewall (optional)
- [ ] Set up VPN/Bastion (optional)

### Secrets Management
- [ ] All secrets in Key Vault
- [ ] Service principals configured
- [ ] API keys rotated
- [ ] Backup encryption enabled

## 📝 Phase 7: Documentation

### Update Documentation
- [ ] Service URLs documented
- [ ] SSH access instructions
- [ ] Troubleshooting guide updated
- [ ] User onboarding process

### Team Access
- [ ] SSH keys distributed
- [ ] Service credentials shared
- [ ] Admin accounts created
- [ ] Access matrix defined

## 🎉 Go-Live Checklist

### Final Verification
- [ ] All services responding
- [ ] Dev/prod sync working
- [ ] Backups configured
- [ ] Monitoring active
- [ ] Cost tracking enabled

### Production Readiness
- [ ] Performance baseline established
- [ ] Disaster recovery plan
- [ ] Incident response process
- [ ] Change management process

## 🚨 Rollback Plan

If issues occur:
1. [ ] Stop problematic services
2. [ ] Restore from backup
3. [ ] Switch to local development
4. [ ] Debug in isolation

```bash
# Emergency shutdown
az vm deallocate --resource-group genai-prod-rg --name genai-gpu-prod
az vm deallocate --resource-group genai-prod-rg --name genai-core-prod
```

## 📞 Support Contacts

- **Azure Support**: Portal > Help + Support
- **Service Issues**: Check logs first
- **Cost Concerns**: Azure Cost Management
- **Emergency**: Have rollback ready

---

## 🎯 Success Criteria

- ✅ All services accessible
- ✅ < 2s response time
- ✅ Costs within budget
- ✅ Sync working both ways
- ✅ Users can access tools

## 📅 Post-Deployment Tasks

**Day 1:**
- [ ] Monitor service stability
- [ ] Check resource usage
- [ ] Verify backups

**Week 1:**
- [ ] Optimize performance
- [ ] Review costs
- [ ] Gather user feedback

**Month 1:**
- [ ] Cost analysis
- [ ] Capacity planning
- [ ] Security audit

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Total Time**: _______________
**Issues Encountered**: _______________
