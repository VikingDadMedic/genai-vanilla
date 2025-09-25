#!/bin/bash

# Azure Container Apps Deployment Script for GenAI Stack
# Simplified, managed deployment using serverless containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
SUBSCRIPTION_ID="1992b163-f828-4887-90c0-b6d26c8ab353"
RESOURCE_GROUP="genai-aca-rg"
LOCATION="eastus"
ENVIRONMENT_NAME="genai-aca-env"
WORKSPACE_NAME="genai-logs"
VNET_NAME="genai-vnet"
SUBNET_NAME="aca-subnet"

# Container Registry
ACR_NAME="genaiacr$(date +%s)"

print_header "🚀 Azure Container Apps Deployment for GenAI Stack"

# Check prerequisites
print_status "Checking prerequisites..."
if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI not found. Please install it first.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Please install it first.${NC}"
    exit 1
fi

# Login check
print_status "Checking Azure login..."
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in. Starting login...${NC}"
    az login
fi

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_success "Using subscription: $SUBSCRIPTION_ID"

print_header "📦 Step 1: Create Resource Group"
if az group exists --name "$RESOURCE_GROUP" | grep -q "false"; then
    print_status "Creating resource group..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Project=GenAI" "Deployment=ContainerApps" "Environment=Production"
    print_success "Resource group created"
else
    print_success "Resource group already exists"
fi

print_header "🔒 Step 2: Create Container Registry"
print_status "Creating Azure Container Registry..."
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
print_success "Container Registry created: $ACR_LOGIN_SERVER"

print_header "📊 Step 3: Create Log Analytics Workspace"
print_status "Creating Log Analytics workspace..."
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --location "$LOCATION"

WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --query primarySharedKey -o tsv)

print_success "Log Analytics workspace created"

print_header "🌐 Step 4: Create Virtual Network"
print_status "Creating VNet for Container Apps..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix 10.0.0.0/23

SUBNET_ID=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query id -o tsv)

print_success "Virtual network created"

print_header "🏗️ Step 5: Create Container Apps Environment"
print_status "Creating Container Apps environment..."
az containerapp env create \
    --name "$ENVIRONMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --logs-workspace-id "$WORKSPACE_ID" \
    --logs-workspace-key "$WORKSPACE_KEY" \
    --infrastructure-subnet-resource-id "$SUBNET_ID"

print_success "Container Apps environment created"

print_header "🔑 Step 6: Setup Azure Services"

# PostgreSQL
print_status "Creating Azure Database for PostgreSQL..."
POSTGRES_SERVER="genai-postgres-aca"
POSTGRES_ADMIN="genaidbadmin"
POSTGRES_PASSWORD="GenAI2024#Secure$(date +%s)"

az postgres flexible-server create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$POSTGRES_SERVER" \
    --location "$LOCATION" \
    --admin-user "$POSTGRES_ADMIN" \
    --admin-password "$POSTGRES_PASSWORD" \
    --sku-name "Standard_B2ms" \
    --storage-size 128 \
    --version 15 \
    --public-access "All"

POSTGRES_HOST=$(az postgres flexible-server show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$POSTGRES_SERVER" \
    --query fullyQualifiedDomainName -o tsv)

print_success "PostgreSQL created: $POSTGRES_HOST"

# Redis
print_status "Creating Azure Cache for Redis..."
REDIS_NAME="genai-redis-aca"

az redis create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$REDIS_NAME" \
    --location "$LOCATION" \
    --sku "Basic" \
    --vm-size "C1"

REDIS_HOST=$(az redis show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$REDIS_NAME" \
    --query hostName -o tsv)

REDIS_KEY=$(az redis list-keys \
    --resource-group "$RESOURCE_GROUP" \
    --name "$REDIS_NAME" \
    --query primaryKey -o tsv)

print_success "Redis created: $REDIS_HOST"

# Storage Account
print_status "Creating Storage Account..."
STORAGE_ACCOUNT="genaisto$(date +%s)"

az storage account create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --location "$LOCATION" \
    --sku "Standard_LRS"

STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

print_success "Storage account created: $STORAGE_ACCOUNT"

print_header "🐳 Step 7: Build and Push Container Images"

# Login to ACR
print_status "Logging into Container Registry..."
az acr login --name "$ACR_NAME"

# Build custom images (if any)
if [ -f "./backend/Dockerfile" ]; then
    print_status "Building backend image..."
    docker build -t "$ACR_LOGIN_SERVER/genai-backend:latest" ./backend
    docker push "$ACR_LOGIN_SERVER/genai-backend:latest"
    print_success "Backend image pushed"
fi

print_header "🚢 Step 8: Deploy Container Apps"

# Deploy Open-WebUI
print_status "Deploying Open-WebUI..."
az containerapp create \
    --name "open-webui" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "ghcr.io/open-webui/open-webui:main" \
    --target-port 8080 \
    --ingress 'external' \
    --cpu 2 \
    --memory 4.0Gi \
    --min-replicas 1 \
    --max-replicas 3 \
    --env-vars \
        "DATABASE_URL=postgresql://$POSTGRES_ADMIN:$POSTGRES_PASSWORD@$POSTGRES_HOST/openwebui" \
        "WEBUI_SECRET_KEY=$(openssl rand -hex 32)" \
        "ENABLE_OAUTH=false" \
        "OLLAMA_BASE_URL=http://ollama:11434" \
        "OPENAI_API_KEY=\${OPENAI_API_KEY}"

OPENWEBUI_URL=$(az containerapp show \
    --name "open-webui" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn -o tsv)

print_success "Open-WebUI deployed: https://$OPENWEBUI_URL"

# Deploy n8n
print_status "Deploying n8n..."
az containerapp create \
    --name "n8n" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "n8nio/n8n:latest" \
    --target-port 5678 \
    --ingress 'external' \
    --cpu 1 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 2 \
    --env-vars \
        "N8N_BASIC_AUTH_ACTIVE=true" \
        "N8N_BASIC_AUTH_USER=admin" \
        "N8N_BASIC_AUTH_PASSWORD=GenAI2024" \
        "DB_TYPE=postgresdb" \
        "DB_POSTGRESDB_HOST=$POSTGRES_HOST" \
        "DB_POSTGRESDB_DATABASE=n8n" \
        "DB_POSTGRESDB_USER=$POSTGRES_ADMIN" \
        "DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD"

N8N_URL=$(az containerapp show \
    --name "n8n" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn -o tsv)

print_success "n8n deployed: https://$N8N_URL"

# Deploy Backend API
print_status "Deploying Backend API..."
az containerapp create \
    --name "backend-api" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$ACR_LOGIN_SERVER/genai-backend:latest" \
    --registry-server "$ACR_LOGIN_SERVER" \
    --target-port 8000 \
    --ingress 'external' \
    --cpu 1 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 5 \
    --env-vars \
        "DATABASE_URL=postgresql://$POSTGRES_ADMIN:$POSTGRES_PASSWORD@$POSTGRES_HOST/genai" \
        "REDIS_URL=redis://:$REDIS_KEY@$REDIS_HOST:6379/0" \
        "AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=$STORAGE_ACCOUNT;AccountKey=$STORAGE_KEY"

BACKEND_URL=$(az containerapp show \
    --name "backend-api" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn -o tsv)

print_success "Backend API deployed: https://$BACKEND_URL"

print_header "🔗 Step 9: Configure Service Discovery"

# Create Dapr components for service mesh
print_status "Setting up Dapr service mesh..."

# State store component
az containerapp env dapr-component create \
    --name "statestore" \
    --environment "$ENVIRONMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --dapr-component-name "statestore" \
    --yaml '
version: v1
metadata:
  - name: redisHost
    value: "'$REDIS_HOST':6379"
  - name: redisPassword
    value: "'$REDIS_KEY'"
scopes:
  - open-webui
  - n8n
  - backend-api'

print_success "Dapr state store configured"

print_header "📝 Step 10: Create Configuration File"

cat > .env.aca << EOF
# ============================================
# AZURE CONTAINER APPS CONFIGURATION
# Generated: $(date)
# ============================================

# Resource Information
RESOURCE_GROUP=$RESOURCE_GROUP
ENVIRONMENT_NAME=$ENVIRONMENT_NAME
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER

# Service URLs
OPEN_WEBUI_URL=https://$OPENWEBUI_URL
N8N_URL=https://$N8N_URL
BACKEND_API_URL=https://$BACKEND_URL

# Database
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_USER=$POSTGRES_ADMIN
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis
REDIS_HOST=$REDIS_HOST
REDIS_KEY=$REDIS_KEY

# Storage
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
STORAGE_KEY=$STORAGE_KEY

# Deployment Info
DEPLOYMENT_TYPE=azure-container-apps
DEPLOYMENT_DATE=$(date)
EOF

print_success "Configuration saved to .env.aca"

print_header "✅ Deployment Complete!"

echo -e "\n${GREEN}Your GenAI Stack is now running on Azure Container Apps!${NC}"
echo -e "\n${CYAN}Access your services:${NC}"
echo -e "  Open-WebUI: ${BLUE}https://$OPENWEBUI_URL${NC}"
echo -e "  n8n:        ${BLUE}https://$N8N_URL${NC}"
echo -e "  Backend:    ${BLUE}https://$BACKEND_URL${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Configure Azure OpenAI integration"
echo "2. Set up custom domains (optional)"
echo "3. Configure auto-scaling rules"
echo "4. Set up monitoring alerts"

echo -e "\n${CYAN}Useful commands:${NC}"
echo "  View apps:     az containerapp list -g $RESOURCE_GROUP -o table"
echo "  View logs:     az containerapp logs show -n open-webui -g $RESOURCE_GROUP"
echo "  Scale app:     az containerapp update -n open-webui -g $RESOURCE_GROUP --max-replicas 10"
echo "  View metrics:  az monitor metrics list --resource open-webui --metric-names CpuUsage"

echo -e "\n${GREEN}Happy deploying! 🚀${NC}"
