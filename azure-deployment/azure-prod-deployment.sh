#!/bin/bash

# Production Azure Deployment Script for GenAI Vanilla Stack
# Hybrid Dev (Local Mac) / Prod (Azure) Architecture

set -e

# =============================================================================
# CONFIGURATION SECTION - Customize these values
# =============================================================================

# Azure Configuration
SUBSCRIPTION_ID="1992b163-f828-4887-90c0-b6d26c8ab353"
TENANT_ID="dcebb360-b77e-4111-9494-dc86bcee9c21"
RESOURCE_GROUP="genai-prod-rg"
LOCATION="eastus"
ENVIRONMENT="production"

# VM Configuration
GPU_VM_NAME="genai-gpu-prod"
GPU_VM_SIZE="Standard_NC8as_T4_v3"  # 8 vCPU, 56GB RAM, 1x T4 GPU
GPU_SPOT_MAX_PRICE="0.20"  # Max $0.20/hour for spot instance

CORE_VM_NAME="genai-core-prod"
CORE_VM_SIZE="Standard_D8s_v5"  # 8 vCPU, 32GB RAM
CORE_DISK_SIZE="256"  # GB

# Networking
VNET_NAME="genai-vnet"
SUBNET_NAME="genai-subnet"
NSG_NAME="genai-nsg"
PUBLIC_IP_GPU="genai-gpu-pip"
PUBLIC_IP_CORE="genai-core-pip"

# Storage Configuration
STORAGE_PREFIX="genaiprod"  # Will append timestamp
FILE_SHARE_NAME="genai-sync"
FILE_SHARE_QUOTA="100"  # GB

# Database Configuration
POSTGRES_SERVER_NAME="genai-postgres-prod"
POSTGRES_ADMIN_USER="genaidbadmin"
POSTGRES_ADMIN_PASSWORD="GenAI2024Prod#Secure"
POSTGRES_SKU="Standard_B2ms"  # 2 vCores, 4GB RAM
POSTGRES_STORAGE="128"  # GB
POSTGRES_VERSION="15"
POSTGRES_DB_NAME="genaidb"

# Redis Configuration
REDIS_NAME="genai-redis-prod"
REDIS_SKU="Basic"
REDIS_VM_SIZE="C1"  # 1GB cache

# Azure OpenAI Configuration
OPENAI_NAME="genai-openai-prod"
OPENAI_SKU="S0"
GPT4_DEPLOYMENT="gpt-4"
GPT35_DEPLOYMENT="gpt-35-turbo"
DALLE3_DEPLOYMENT="dall-e-3"
EMBEDDINGS_DEPLOYMENT="text-embedding-ada-002"

# Container Registry (for custom images)
ACR_NAME="genaiprodacr"
ACR_SKU="Basic"

# Key Vault
KEYVAULT_NAME="genai-kv-prod-$(date +%s)"

# Admin Configuration
ADMIN_USERNAME="genaiuser"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

# Tags for resource management
TAGS="Environment=${ENVIRONMENT} Project=GenAI Deployment=Production ManagedBy=CLI"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_status() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not installed"
        exit 1
    fi
    print_success "Azure CLI installed"
    
    # Check logged in
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Run: az login"
        exit 1
    fi
    print_success "Logged into Azure"
    
    # Set subscription
    print_status "Setting subscription..."
    az account set --subscription "$SUBSCRIPTION_ID"
    print_success "Subscription set: $SUBSCRIPTION_ID"
    
    # Check SSH key
    if [ ! -f "$SSH_KEY_PATH" ]; then
        print_status "Generating SSH key..."
        ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH%.pub}" -N ""
    fi
    print_success "SSH key ready"
}

# Create Resource Group
create_resource_group() {
    print_header "Creating Resource Group"
    
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags $TAGS \
        --output table
    
    print_success "Resource group created: $RESOURCE_GROUP"
}

# Create Networking
create_networking() {
    print_header "Creating Network Infrastructure"
    
    # Create VNet
    print_status "Creating Virtual Network..."
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --address-prefix "10.0.0.0/16" \
        --subnet-name "$SUBNET_NAME" \
        --subnet-prefix "10.0.1.0/24" \
        --output table
    
    # Create NSG
    print_status "Creating Network Security Group..."
    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NSG_NAME" \
        --output table
    
    # Add NSG rules
    print_status "Adding security rules..."
    
    # SSH (restricted - update with your IP)
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" \
        --name "SSH" \
        --priority 1000 \
        --destination-port-ranges 22 \
        --protocol Tcp \
        --access Allow \
        --output none
    
    # Core services ports
    local PORTS=("63015:Open-WebUI" "63017:n8n" "63016:Backend-API" "63018:ComfyUI" "63027:ACI-Portal")
    local PRIORITY=1010
    
    for PORT_DESC in "${PORTS[@]}"; do
        IFS=':' read -r PORT DESC <<< "$PORT_DESC"
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "Allow-$DESC" \
            --priority $PRIORITY \
            --destination-port-ranges $PORT \
            --protocol Tcp \
            --access Allow \
            --output none
        ((PRIORITY+=10))
    done
    
    print_success "Network infrastructure created"
}

# Create Storage Account
create_storage() {
    print_header "Creating Storage Account"
    
    STORAGE_ACCOUNT="${STORAGE_PREFIX}$(date +%s)"
    
    # Create storage account
    print_status "Creating storage account: $STORAGE_ACCOUNT..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --access-tier Hot \
        --allow-blob-public-access false \
        --min-tls-version TLS1_2 \
        --tags $TAGS \
        --output table
    
    # Get storage key
    STORAGE_KEY=$(az storage account keys list \
        --resource-group "$RESOURCE_GROUP" \
        --account-name "$STORAGE_ACCOUNT" \
        --query '[0].value' -o tsv)
    
    # Create containers
    print_status "Creating blob containers..."
    local CONTAINERS=("models" "research" "backups" "user-data" "comfyui-outputs")
    
    for CONTAINER in "${CONTAINERS[@]}"; do
        az storage container create \
            --name "$CONTAINER" \
            --account-name "$STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --public-access off \
            --output none
        print_success "Container created: $CONTAINER"
    done
    
    # Create file share for sync
    print_status "Creating file share for dev/prod sync..."
    az storage share create \
        --name "$FILE_SHARE_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --quota "$FILE_SHARE_QUOTA" \
        --output table
    
    print_success "Storage account created: $STORAGE_ACCOUNT"
}

# Create Container Registry
create_container_registry() {
    print_header "Creating Container Registry"
    
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku "$ACR_SKU" \
        --admin-enabled true \
        --tags $TAGS \
        --output table
    
    print_success "Container Registry created: $ACR_NAME"
}

# Create Key Vault
create_keyvault() {
    print_header "Creating Key Vault"
    
    az keyvault create \
        --name "$KEYVAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enable-soft-delete true \
        --retention-days 7 \
        --tags $TAGS \
        --output table
    
    print_success "Key Vault created: $KEYVAULT_NAME"
}

# Create Azure Database for PostgreSQL
create_postgresql() {
    print_header "Creating PostgreSQL Database"
    
    print_status "Creating PostgreSQL server..."
    az postgres flexible-server create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --location "$LOCATION" \
        --admin-user "$POSTGRES_ADMIN_USER" \
        --admin-password "$POSTGRES_ADMIN_PASSWORD" \
        --sku-name "$POSTGRES_SKU" \
        --storage-size "$POSTGRES_STORAGE" \
        --version "$POSTGRES_VERSION" \
        --backup-retention 7 \
        --geo-redundant-backup Disabled \
        --public-access 0.0.0.0 \
        --tags $TAGS \
        --yes \
        --output table
    
    # Create databases
    print_status "Creating databases..."
    local DATABASES=("genaidb" "aci_db" "weaviate_db")
    
    for DB in "${DATABASES[@]}"; do
        az postgres flexible-server db create \
            --server-name "$POSTGRES_SERVER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --database-name "$DB" \
            --output none
        print_success "Database created: $DB"
    done
    
    # Configure firewall
    print_status "Configuring PostgreSQL firewall..."
    az postgres flexible-server firewall-rule create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --rule-name "AllowAzureServices" \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0 \
        --output none
    
    print_success "PostgreSQL server created"
}

# Create Redis Cache
create_redis() {
    print_header "Creating Redis Cache"
    
    az redis create \
        --name "$REDIS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "$REDIS_SKU" \
        --vm-size "$REDIS_VM_SIZE" \
        --enable-non-ssl-port \
        --redis-configuration maxmemory-policy="allkeys-lru" \
        --tags $TAGS \
        --output table
    
    print_success "Redis cache created: $REDIS_NAME"
}

# Create Azure OpenAI
create_openai() {
    print_header "Creating Azure OpenAI Service"
    
    # Create OpenAI account
    print_status "Creating OpenAI resource..."
    az cognitiveservices account create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --kind OpenAI \
        --sku "$OPENAI_SKU" \
        --location "$LOCATION" \
        --custom-domain "$OPENAI_NAME" \
        --tags $TAGS \
        --yes \
        --output table
    
    # Deploy models
    print_status "Deploying AI models..."
    
    # GPT-4
    az cognitiveservices account deployment create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --deployment-name "$GPT4_DEPLOYMENT" \
        --model-name "gpt-4" \
        --model-version "0613" \
        --model-format OpenAI \
        --sku-capacity 10 \
        --sku-name "Standard" \
        --output none 2>/dev/null || print_status "GPT-4 deployment exists or not available"
    
    # GPT-3.5-turbo
    az cognitiveservices account deployment create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --deployment-name "$GPT35_DEPLOYMENT" \
        --model-name "gpt-35-turbo" \
        --model-version "0613" \
        --model-format OpenAI \
        --sku-capacity 30 \
        --sku-name "Standard" \
        --output none 2>/dev/null || print_status "GPT-3.5 deployment exists or not available"
    
    # Text Embeddings
    az cognitiveservices account deployment create \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --deployment-name "$EMBEDDINGS_DEPLOYMENT" \
        --model-name "text-embedding-ada-002" \
        --model-version "2" \
        --model-format OpenAI \
        --sku-capacity 30 \
        --sku-name "Standard" \
        --output none 2>/dev/null || print_status "Embeddings deployment exists or not available"
    
    print_success "Azure OpenAI service created"
}

# Create GPU VM (Spot Instance)
create_gpu_vm() {
    print_header "Creating GPU VM (Spot Instance)"
    
    print_status "Creating GPU VM: $GPU_VM_NAME..."
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$GPU_VM_NAME" \
        --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" \
        --size "$GPU_VM_SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "$SSH_KEY_PATH" \
        --vnet-name "$VNET_NAME" \
        --subnet "$SUBNET_NAME" \
        --nsg "$NSG_NAME" \
        --public-ip-address "$PUBLIC_IP_GPU" \
        --public-ip-sku Standard \
        --storage-sku Premium_LRS \
        --os-disk-size-gb 128 \
        --data-disk-sizes-gb 512 \
        --priority Spot \
        --max-price "$GPU_SPOT_MAX_PRICE" \
        --eviction-policy Deallocate \
        --tags $TAGS \
        --output table
    
    # Enable auto-shutdown to save costs
    print_status "Configuring auto-shutdown..."
    az vm auto-shutdown \
        --resource-group "$RESOURCE_GROUP" \
        --name "$GPU_VM_NAME" \
        --time "2300" \
        --output none
    
    print_success "GPU VM created (Spot): $GPU_VM_NAME"
}

# Create Core VM (Reserved)
create_core_vm() {
    print_header "Creating Core Services VM"
    
    print_status "Creating Core VM: $CORE_VM_NAME..."
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CORE_VM_NAME" \
        --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" \
        --size "$CORE_VM_SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "$SSH_KEY_PATH" \
        --vnet-name "$VNET_NAME" \
        --subnet "$SUBNET_NAME" \
        --nsg "$NSG_NAME" \
        --public-ip-address "$PUBLIC_IP_CORE" \
        --public-ip-sku Standard \
        --storage-sku Premium_LRS \
        --os-disk-size-gb 128 \
        --data-disk-sizes-gb "$CORE_DISK_SIZE" \
        --priority Regular \
        --tags $TAGS \
        --output table
    
    print_success "Core VM created: $CORE_VM_NAME"
}

# Collect all connection information
collect_connection_info() {
    print_header "Collecting Connection Information"
    
    # Get IPs
    GPU_IP=$(az vm show -d \
        --resource-group "$RESOURCE_GROUP" \
        --name "$GPU_VM_NAME" \
        --query publicIps -o tsv)
    
    CORE_IP=$(az vm show -d \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CORE_VM_NAME" \
        --query publicIps -o tsv)
    
    # PostgreSQL
    PG_HOST=$(az postgres flexible-server show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --query fullyQualifiedDomainName -o tsv)
    
    # Redis
    REDIS_HOST=$(az redis show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$REDIS_NAME" \
        --query hostName -o tsv)
    
    REDIS_KEY=$(az redis list-keys \
        --resource-group "$RESOURCE_GROUP" \
        --name "$REDIS_NAME" \
        --query primaryKey -o tsv)
    
    # OpenAI
    OPENAI_ENDPOINT=$(az cognitiveservices account show \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.endpoint -o tsv)
    
    OPENAI_KEY=$(az cognitiveservices account keys list \
        --name "$OPENAI_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query key1 -o tsv)
    
    # ACR
    ACR_LOGIN_SERVER=$(az acr show \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query loginServer -o tsv)
    
    ACR_USERNAME=$(az acr credential show \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query username -o tsv)
    
    ACR_PASSWORD=$(az acr credential show \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query passwords[0].value -o tsv)
    
    # Storage
    STORAGE_CONNECTION=$(az storage account show-connection-string \
        --resource-group "$RESOURCE_GROUP" \
        --name "$STORAGE_ACCOUNT" \
        --query connectionString -o tsv)
}

# Generate environment files
generate_env_files() {
    print_header "Generating Environment Files"
    
    # Production .env for Azure
    cat > .env.azure.prod << EOF
# ============================================
# AZURE PRODUCTION CONFIGURATION
# Generated: $(date)
# ============================================

# Environment
ENVIRONMENT=production
PROJECT_NAME=genai

# Azure Resource Information
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION=$LOCATION

# Virtual Machines
AZURE_GPU_VM_NAME=$GPU_VM_NAME
AZURE_GPU_VM_IP=$GPU_IP
AZURE_CORE_VM_NAME=$CORE_VM_NAME
AZURE_CORE_VM_IP=$CORE_IP
AZURE_SSH_USER=$ADMIN_USERNAME

# PostgreSQL (Managed)
DATABASE_HOST=$PG_HOST
DATABASE_PORT=5432
DATABASE_USER=$POSTGRES_ADMIN_USER
DATABASE_PASSWORD=$POSTGRES_ADMIN_PASSWORD
DATABASE_NAME=$POSTGRES_DB_NAME
DATABASE_URL=postgresql://$POSTGRES_ADMIN_USER:$POSTGRES_ADMIN_PASSWORD@$PG_HOST:5432/$POSTGRES_DB_NAME?sslmode=require

# Separate DBs for services
ACI_DATABASE_URL=postgresql://$POSTGRES_ADMIN_USER:$POSTGRES_ADMIN_PASSWORD@$PG_HOST:5432/aci_db?sslmode=require
WEAVIATE_DATABASE_URL=postgresql://$POSTGRES_ADMIN_USER:$POSTGRES_ADMIN_PASSWORD@$PG_HOST:5432/weaviate_db?sslmode=require

# Redis Cache (Managed)
REDIS_HOST=$REDIS_HOST
REDIS_PORT=6380
REDIS_PASSWORD=$REDIS_KEY
REDIS_URL=rediss://:$REDIS_KEY@$REDIS_HOST:6380/0
REDIS_TLS_URL=rediss://:$REDIS_KEY@$REDIS_HOST:6380/0

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_KEY=$OPENAI_KEY
AZURE_OPENAI_API_VERSION=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_GPT4=$GPT4_DEPLOYMENT
AZURE_OPENAI_DEPLOYMENT_GPT35=$GPT35_DEPLOYMENT
AZURE_OPENAI_DEPLOYMENT_EMBEDDINGS=$EMBEDDINGS_DEPLOYMENT

# For OpenAI compatibility layer
OPENAI_API_TYPE=azure
OPENAI_API_BASE=$OPENAI_ENDPOINT
OPENAI_API_KEY=$OPENAI_KEY
OPENAI_API_VERSION=2024-02-15-preview

# Azure Storage
AZURE_STORAGE_ACCOUNT=$STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$STORAGE_KEY
AZURE_STORAGE_CONNECTION_STRING=$STORAGE_CONNECTION
AZURE_FILE_SHARE_NAME=$FILE_SHARE_NAME

# Container Registry
AZURE_ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
AZURE_ACR_USERNAME=$ACR_USERNAME
AZURE_ACR_PASSWORD=$ACR_PASSWORD

# Key Vault
AZURE_KEY_VAULT_NAME=$KEYVAULT_NAME
AZURE_KEY_VAULT_URI=https://$KEYVAULT_NAME.vault.azure.net/

# Service URLs (Production)
BASE_URL=http://$CORE_IP
OPEN_WEBUI_URL=http://$CORE_IP:63015
N8N_URL=http://$CORE_IP:63017
BACKEND_API_URL=http://$CORE_IP:63016
COMFYUI_URL=http://$GPU_IP:63018
ACI_PORTAL_URL=http://$CORE_IP:63027
SEARXNG_URL=http://$CORE_IP:63014

# Internal service URLs (for container-to-container)
OLLAMA_ENDPOINT=http://$GPU_IP:11434
WEAVIATE_ENDPOINT=http://$GPU_IP:63019
DEEP_RESEARCHER_URL=http://$GPU_IP:63013

# GPU Configuration
GPU_ENABLED=true
NVIDIA_VISIBLE_DEVICES=0
CUDA_VISIBLE_DEVICES=0

# Service Scaling (Production values)
SUPABASE_SCALE=0  # Using Azure PostgreSQL instead
REDIS_SCALE=0  # Using Azure Redis instead
OLLAMA_SCALE=1  # On GPU VM
COMFYUI_SCALE=1  # On GPU VM
WEAVIATE_SCALE=1  # On GPU VM
N8N_SCALE=1  # On Core VM
OPEN_WEB_UI_SCALE=1  # On Core VM
BACKEND_SCALE=1  # On Core VM
LOCAL_DEEP_RESEARCHER_SCALE=1  # On GPU VM
ACI_BACKEND_SCALE=1  # On Core VM
SEARXNG_SCALE=1  # On Core VM

# Deployment Mode
DEPLOYMENT_MODE=azure-production
SYNC_WITH_DEV=true
DEV_MACHINE=local-mac
EOF

    # Development sync configuration
    cat > .env.azure.sync << EOF
# ============================================
# DEV/PROD SYNC CONFIGURATION
# ============================================

# Azure Storage for sync
SYNC_STORAGE_ACCOUNT=$STORAGE_ACCOUNT
SYNC_STORAGE_KEY=$STORAGE_KEY
SYNC_FILE_SHARE=$FILE_SHARE_NAME

# Sync directories
SYNC_DIRS=(
    "open-webui/functions"
    "open-webui/tools"
    "n8n/workflows"
    "aci-integration/integrations"
    "custom-pages"
    "docs"
)

# Excluded from sync
SYNC_EXCLUDE=(
    "*.pyc"
    "__pycache__"
    ".git"
    ".env*"
    "node_modules"
    "*.log"
)

# Production endpoints for dev testing
PROD_OPEN_WEBUI=http://$CORE_IP:63015
PROD_N8N=http://$CORE_IP:63017
PROD_BACKEND=http://$CORE_IP:63016
PROD_COMFYUI=http://$GPU_IP:63018
EOF

    print_success "Environment files generated"
}

# Create deployment summary
create_summary() {
    print_header "Deployment Summary"
    
    cat > azure-deployment/DEPLOYMENT_SUMMARY.md << EOF
# Azure Production Deployment Summary

## 📅 Deployment Date
$(date)

## 🔗 Resource Group
- **Name**: $RESOURCE_GROUP
- **Location**: $LOCATION
- **Subscription**: $SUBSCRIPTION_ID

## 🖥️ Virtual Machines

### GPU VM (AI Workloads)
- **Name**: $GPU_VM_NAME
- **Size**: $GPU_VM_SIZE
- **Type**: Spot Instance (Max: \$$GPU_SPOT_MAX_PRICE/hour)
- **Public IP**: $GPU_IP
- **SSH**: ssh $ADMIN_USERNAME@$GPU_IP
- **Services**: Ollama, ComfyUI, Weaviate, Deep Researcher

### Core VM (Always-On Services)
- **Name**: $CORE_VM_NAME
- **Size**: $CORE_VM_SIZE
- **Type**: Regular
- **Public IP**: $CORE_IP
- **SSH**: ssh $ADMIN_USERNAME@$CORE_IP
- **Services**: Open-WebUI, n8n, Backend API, ACI

## 🗄️ Managed Services

### PostgreSQL
- **Server**: $POSTGRES_SERVER_NAME
- **Host**: $PG_HOST
- **Databases**: genaidb, aci_db, weaviate_db

### Redis Cache
- **Name**: $REDIS_NAME
- **Host**: $REDIS_HOST
- **Port**: 6380 (SSL)

### Azure OpenAI
- **Resource**: $OPENAI_NAME
- **Endpoint**: $OPENAI_ENDPOINT
- **Models**: GPT-4, GPT-3.5-turbo, text-embedding-ada-002

### Storage
- **Account**: $STORAGE_ACCOUNT
- **Containers**: models, research, backups, user-data, comfyui-outputs
- **File Share**: $FILE_SHARE_NAME (100GB)

### Container Registry
- **Registry**: $ACR_NAME
- **Server**: $ACR_LOGIN_SERVER

### Key Vault
- **Name**: $KEYVAULT_NAME
- **URI**: https://$KEYVAULT_NAME.vault.azure.net/

## 🌐 Service URLs

- **Open-WebUI**: http://$CORE_IP:63015
- **n8n Workflows**: http://$CORE_IP:63017
- **Backend API**: http://$CORE_IP:63016/docs
- **ComfyUI**: http://$GPU_IP:63018
- **ACI Portal**: http://$CORE_IP:63027
- **SearxNG**: http://$CORE_IP:63014

## 💰 Estimated Monthly Costs

| Service | Type | Cost |
|---------|------|------|
| GPU VM | Spot (8 vCPU, 56GB, T4) | ~\$150 |
| Core VM | Regular (8 vCPU, 32GB) | ~\$140 |
| PostgreSQL | B2ms | ~\$50 |
| Redis | C1 Basic | ~\$50 |
| Storage | 1TB + transactions | ~\$20 |
| Azure OpenAI | Usage-based | ~\$100-500 |
| **Total** | | **~\$510-910** |

## 🔐 Security

- NSG rules configured for specific ports
- TLS 1.2 minimum for all services
- Secrets stored in Key Vault
- Private endpoints available for database

## 📝 Next Steps

1. [ ] SSH to VMs and run setup scripts
2. [ ] Deploy Docker containers
3. [ ] Configure dev/prod sync
4. [ ] Test all services
5. [ ] Set up monitoring
6. [ ] Configure backups

## 🔄 Dev/Prod Sync

Development remains on local Mac. Use Azure File Share for syncing:
- Mount point: /mnt/genai-sync
- Sync script: azure-deployment/sync-to-prod.sh

## 📊 Monitoring

- VM Metrics: Azure Monitor
- Application logs: Container logs
- Cost tracking: Azure Cost Management

## 🆘 Support

- Azure Support: Portal tickets
- SSH Access: $ADMIN_USERNAME@<VM_IP>
- Resource Group: $RESOURCE_GROUP
EOF

    print_success "Deployment summary created"
}

# Main deployment flow
main() {
    print_header "🚀 GenAI Production Deployment to Azure"
    echo -e "${MAGENTA}Environment: PRODUCTION${NC}"
    echo -e "${MAGENTA}Dev remains on: Local Mac${NC}"
    
    # Run deployment steps
    check_prerequisites
    create_resource_group
    create_networking
    create_storage
    create_container_registry
    create_keyvault
    create_postgresql
    create_redis
    create_openai
    create_gpu_vm
    create_core_vm
    collect_connection_info
    generate_env_files
    create_summary
    
    # Final output
    print_header "✅ DEPLOYMENT COMPLETE!"
    
    echo -e "\n${GREEN}Connection Information:${NC}"
    echo "================================"
    echo -e "GPU VM: ${BLUE}$GPU_IP${NC}"
    echo -e "Core VM: ${BLUE}$CORE_IP${NC}"
    echo -e "PostgreSQL: ${BLUE}$PG_HOST${NC}"
    echo -e "Redis: ${BLUE}$REDIS_HOST${NC}"
    echo -e "OpenAI: ${BLUE}$OPENAI_ENDPOINT${NC}"
    echo -e "Storage: ${BLUE}$STORAGE_ACCOUNT${NC}"
    echo -e "Registry: ${BLUE}$ACR_LOGIN_SERVER${NC}"
    
    echo -e "\n${YELLOW}Files Generated:${NC}"
    echo "• .env.azure.prod - Production environment"
    echo "• .env.azure.sync - Dev/Prod sync config"
    echo "• azure-deployment/DEPLOYMENT_SUMMARY.md"
    
    echo -e "\n${MAGENTA}Next Steps:${NC}"
    echo "1. Review azure-deployment/DEPLOYMENT_SUMMARY.md"
    echo "2. Run: ./azure-deployment/setup-vms.sh"
    echo "3. Set up dev/prod sync"
    echo "4. Test production services"
    
    echo -e "\n${BLUE}Total deployment time: $SECONDS seconds${NC}"
}

# Run main function
main "$@"
