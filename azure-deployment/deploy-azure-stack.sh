#!/bin/bash

# Azure Deployment Script for GenAI Vanilla Stack
# Optimized for power users with GPU workloads

set -e

# Configuration
SUBSCRIPTION_ID="1992b163-f828-4887-90c0-b6d26c8ab353"
RESOURCE_GROUP="genai-power-rg"
LOCATION="eastus"
ADMIN_USERNAME="genaiuser"

# VM Names
GPU_VM_NAME="genai-gpu-vm"
CPU_VM_NAME="genai-core-vm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 GenAI Azure Deployment - Power User Edition${NC}"
echo "================================================"

# Set subscription
echo -e "\n${YELLOW}Setting subscription...${NC}"
az account set --subscription $SUBSCRIPTION_ID

# Create Resource Group
echo -e "\n${YELLOW}Creating resource group...${NC}"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --tags Environment=Production Project=GenAI

# Create Virtual Network
echo -e "\n${YELLOW}Creating virtual network...${NC}"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name genai-vnet \
    --address-prefix 10.0.0.0/16 \
    --subnet-name genai-subnet \
    --subnet-prefix 10.0.1.0/24

# Create Network Security Group
echo -e "\n${YELLOW}Creating network security group...${NC}"
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name genai-nsg

# Add NSG rules for services
echo -e "\n${YELLOW}Adding security rules...${NC}"
# SSH
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name genai-nsg \
    --name AllowSSH \
    --priority 1000 \
    --source-address-prefixes Internet \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow

# Open-WebUI
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name genai-nsg \
    --name AllowOpenWebUI \
    --priority 1010 \
    --source-address-prefixes Internet \
    --destination-port-ranges 63015 \
    --protocol Tcp \
    --access Allow

# n8n
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name genai-nsg \
    --name AllowN8N \
    --priority 1020 \
    --source-address-prefixes Internet \
    --destination-port-ranges 63017 \
    --protocol Tcp \
    --access Allow

# Create Storage Account for shared data
echo -e "\n${YELLOW}Creating storage account...${NC}"
STORAGE_ACCOUNT="genaistorage$(date +%s)"
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot

# Get storage key
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT \
    --query '[0].value' -o tsv)

# Create blob containers
echo -e "\n${YELLOW}Creating blob containers...${NC}"
az storage container create \
    --name models \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --public-access off

az storage container create \
    --name research \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --public-access off

az storage container create \
    --name user-data \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --public-access off

# Create Azure File Share for shared config
echo -e "\n${YELLOW}Creating file share...${NC}"
az storage share create \
    --name genai-config \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --quota 100

# Create Key Vault
echo -e "\n${YELLOW}Creating Key Vault...${NC}"
KEY_VAULT_NAME="genai-kv-$(date +%s)"
az keyvault create \
    --name $KEY_VAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --enable-soft-delete true \
    --retention-days 7

# Create Azure Cache for Redis
echo -e "\n${YELLOW}Creating Azure Cache for Redis...${NC}"
az redis create \
    --name genai-redis \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Basic \
    --vm-size C1 \
    --enable-non-ssl-port

# Create Azure Database for PostgreSQL
echo -e "\n${YELLOW}Creating PostgreSQL server...${NC}"
az postgres flexible-server create \
    --name genai-postgres \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user genaidbadmin \
    --admin-password "GenAI2024Secure!" \
    --sku-name Standard_B2ms \
    --storage-size 128 \
    --version 15 \
    --public-access 0.0.0.0 \
    --yes

# Create database
az postgres flexible-server db create \
    --server-name genai-postgres \
    --resource-group $RESOURCE_GROUP \
    --database-name genaidb

# Create Azure OpenAI instance
echo -e "\n${YELLOW}Creating Azure OpenAI...${NC}"
az cognitiveservices account create \
    --name genai-openai \
    --resource-group $RESOURCE_GROUP \
    --kind OpenAI \
    --sku S0 \
    --location $LOCATION \
    --yes

# Deploy models
echo -e "\n${YELLOW}Deploying OpenAI models...${NC}"
# GPT-4
az cognitiveservices account deployment create \
    --name genai-openai \
    --resource-group $RESOURCE_GROUP \
    --deployment-name gpt-4 \
    --model-name gpt-4 \
    --model-version "0613" \
    --model-format OpenAI \
    --sku-capacity 10 \
    --sku-name "Standard" 2>/dev/null || echo "GPT-4 deployment exists or not available"

# GPT-3.5-turbo
az cognitiveservices account deployment create \
    --name genai-openai \
    --resource-group $RESOURCE_GROUP \
    --deployment-name gpt-35-turbo \
    --model-name gpt-35-turbo \
    --model-version "0613" \
    --model-format OpenAI \
    --sku-capacity 10 \
    --sku-name "Standard" 2>/dev/null || echo "GPT-3.5 deployment exists or not available"

# Create GPU VM (NC8as_T4_v3)
echo -e "\n${YELLOW}Creating GPU VM (this may take a while)...${NC}"
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $GPU_VM_NAME \
    --image Ubuntu2204 \
    --size Standard_NC8as_T4_v3 \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --vnet-name genai-vnet \
    --subnet genai-subnet \
    --nsg genai-nsg \
    --public-ip-address genai-gpu-ip \
    --storage-sku Premium_LRS \
    --data-disk-sizes-gb 512 \
    --priority Spot \
    --max-price 0.2 \
    --eviction-policy Deallocate

# Create CPU VM (D8s_v5)
echo -e "\n${YELLOW}Creating CPU VM...${NC}"
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $CPU_VM_NAME \
    --image Ubuntu2204 \
    --size Standard_D8s_v5 \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --vnet-name genai-vnet \
    --subnet genai-subnet \
    --nsg genai-nsg \
    --public-ip-address genai-core-ip \
    --storage-sku Premium_LRS \
    --data-disk-sizes-gb 256

# Get connection strings and keys
echo -e "\n${YELLOW}Retrieving connection information...${NC}"

# PostgreSQL connection string
PG_HOST=$(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name genai-postgres \
    --query fullyQualifiedDomainName -o tsv)

# Redis connection string
REDIS_KEY=$(az redis list-keys \
    --resource-group $RESOURCE_GROUP \
    --name genai-redis \
    --query primaryKey -o tsv)

REDIS_HOST=$(az redis show \
    --resource-group $RESOURCE_GROUP \
    --name genai-redis \
    --query hostName -o tsv)

# Azure OpenAI endpoint and key
OPENAI_ENDPOINT=$(az cognitiveservices account show \
    --name genai-openai \
    --resource-group $RESOURCE_GROUP \
    --query properties.endpoint -o tsv)

OPENAI_KEY=$(az cognitiveservices account keys list \
    --name genai-openai \
    --resource-group $RESOURCE_GROUP \
    --query key1 -o tsv)

# Get VM IPs
GPU_IP=$(az vm show -d \
    --resource-group $RESOURCE_GROUP \
    --name $GPU_VM_NAME \
    --query publicIps -o tsv)

CORE_IP=$(az vm show -d \
    --resource-group $RESOURCE_GROUP \
    --name $CPU_VM_NAME \
    --query publicIps -o tsv)

# Generate .env.azure file
echo -e "\n${YELLOW}Generating Azure configuration...${NC}"
cat > .env.azure << EOF
# Azure Configuration for GenAI Stack
# Generated: $(date)

# Azure Resources
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION=$LOCATION

# VM Access
GPU_VM_IP=$GPU_IP
CORE_VM_IP=$CORE_IP
SSH_USER=$ADMIN_USERNAME

# Azure PostgreSQL (replaces local PostgreSQL)
AZURE_PG_HOST=$PG_HOST
AZURE_PG_USER=genaidbadmin
AZURE_PG_PASSWORD=GenAI2024Secure!
AZURE_PG_DATABASE=genaidb
DATABASE_URL=postgresql://genaidbadmin:GenAI2024Secure!@$PG_HOST:5432/genaidb?sslmode=require

# Azure Cache for Redis (replaces local Redis)
AZURE_REDIS_HOST=$REDIS_HOST
AZURE_REDIS_KEY=$REDIS_KEY
AZURE_REDIS_PORT=6380
REDIS_URL=rediss://:$REDIS_KEY@$REDIS_HOST:6380/0

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_KEY=$OPENAI_KEY
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview

# Azure Storage
AZURE_STORAGE_ACCOUNT=$STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$STORAGE_KEY
AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=$STORAGE_ACCOUNT;AccountKey=$STORAGE_KEY;EndpointSuffix=core.windows.net"

# Azure Key Vault
AZURE_KEY_VAULT_NAME=$KEY_VAULT_NAME
AZURE_KEY_VAULT_URI=https://$KEY_VAULT_NAME.vault.azure.net/

# Service URLs (after deployment)
OPEN_WEBUI_URL=http://$CORE_IP:63015
N8N_URL=http://$CORE_IP:63017
COMFYUI_URL=http://$GPU_IP:63018
ACI_PORTAL_URL=http://$CORE_IP:63027
EOF

echo -e "\n${GREEN}✅ Azure infrastructure created successfully!${NC}"
echo -e "\n${BLUE}Connection Information:${NC}"
echo "================================"
echo -e "GPU VM: ${GREEN}$GPU_IP${NC}"
echo -e "Core VM: ${GREEN}$CORE_IP${NC}"
echo -e "PostgreSQL: ${GREEN}$PG_HOST${NC}"
echo -e "Redis: ${GREEN}$REDIS_HOST${NC}"
echo -e "OpenAI Endpoint: ${GREEN}$OPENAI_ENDPOINT${NC}"
echo -e "Storage Account: ${GREEN}$STORAGE_ACCOUNT${NC}"
echo -e "Key Vault: ${GREEN}$KEY_VAULT_NAME${NC}"
echo ""
echo -e "${YELLOW}Configuration saved to: .env.azure${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. SSH to GPU VM: ssh $ADMIN_USERNAME@$GPU_IP"
echo "2. SSH to Core VM: ssh $ADMIN_USERNAME@$CORE_IP"
echo "3. Run setup scripts on each VM"
echo "4. Deploy containers with Azure configuration"
