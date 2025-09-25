#!/bin/bash

# Azure OpenAI-First Deployment Script
# Optimized for using Azure OpenAI instead of self-hosted LLMs
# GPU VM is OPTIONAL - only needed for image generation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Configuration
SUBSCRIPTION_ID="1992b163-f828-4887-90c0-b6d26c8ab353"
RESOURCE_GROUP="genai-azure-prod"
LOCATION="eastus"

# Ask user about GPU needs
print_header "🤔 Deployment Configuration"
echo -e "${YELLOW}Do you need GPU for image generation (ComfyUI)?${NC}"
echo "1) No - Azure OpenAI only (recommended, saves $150/mo)"
echo "2) Yes - Include GPU VM for ComfyUI"
echo "3) Maybe later - Can add GPU VM anytime"
read -p "Choice (1-3): " GPU_CHOICE

DEPLOY_GPU=false
if [ "$GPU_CHOICE" = "2" ]; then
    DEPLOY_GPU=true
    echo -e "${YELLOW}GPU VM will be deployed (adds $150/month)${NC}"
else
    echo -e "${GREEN}Skipping GPU VM - using Azure OpenAI for everything!${NC}"
fi

# Core VM Configuration (always needed)
CORE_VM_NAME="genai-core-azure"
CORE_VM_SIZE="Standard_D8s_v5"  # 8 vCPU, 32GB RAM

# Optional GPU VM Configuration
if [ "$DEPLOY_GPU" = true ]; then
    GPU_VM_NAME="genai-gpu-azure"
    GPU_VM_SIZE="Standard_NC8as_T4_v3"
    GPU_SPOT_MAX_PRICE="0.20"
fi

print_header "🚀 Azure OpenAI-First Deployment"

# Create simplified deployment
cat > .env.azure.minimal << EOF
# ============================================
# AZURE OPENAI-FIRST CONFIGURATION
# ============================================

# Deployment Mode
DEPLOYMENT_MODE=azure-openai-first
GPU_ENABLED=$DEPLOY_GPU

# Azure Resources
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION=$LOCATION

# LLM Provider (Azure OpenAI for everything!)
LLM_PROVIDER=azure-openai
OLLAMA_ENABLED=false
USE_LOCAL_MODELS=false

# Services using Azure OpenAI
OPENWEBUI_LLM=azure-openai
DEEP_RESEARCHER_LLM=azure-openai
N8N_AI_PROVIDER=azure-openai
WEAVIATE_VECTORIZER=text2vec-openai
ACI_LLM_PROVIDER=azure-openai

# Cost Optimization
AUTO_SHUTDOWN_ENABLED=true
AUTO_SHUTDOWN_TIME=2300
SPOT_INSTANCES=$DEPLOY_GPU
EOF

echo -e "${GREEN}✅ Configuration ready!${NC}"

# Show cost comparison
print_header "💰 Cost Comparison"

if [ "$DEPLOY_GPU" = true ]; then
    cat << EOF
WITH GPU VM:
- Core VM: $140/month
- GPU VM (Spot): $150/month
- Azure PostgreSQL: $50/month
- Azure Redis: $50/month
- Storage: $20/month
- Azure OpenAI: ~$100-300/month (usage)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: ~$510-710/month
EOF
else
    cat << EOF
WITHOUT GPU VM (Recommended):
- Core VM: $140/month
- Azure PostgreSQL: $50/month  
- Azure Redis: $50/month
- Storage: $20/month
- Azure OpenAI: ~$100-300/month (usage)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: ~$360-560/month (Save $150!)
EOF
fi

echo -e "\n${YELLOW}Proceed with deployment? (y/n)${NC}"
read -p "> " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Run main deployment
echo -e "${GREEN}Starting deployment...${NC}"
if [ "$DEPLOY_GPU" = true ]; then
    ./azure-deployment/azure-prod-deployment.sh
else
    # Modified deployment without GPU
    ./azure-deployment/azure-prod-deployment.sh --no-gpu
fi

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${YELLOW}Run ./azure-deployment/configure-azure-openai.sh to configure all services${NC}"
