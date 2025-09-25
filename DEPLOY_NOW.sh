#!/bin/bash

# Direct Azure Deployment Commands
# Run these commands in your terminal

echo "🚀 Starting Azure Deployment for GenAI Stack"

# Step 1: Check/Install Azure CLI
if ! command -v az &> /dev/null; then
    echo "Installing Azure CLI..."
    brew update && brew install azure-cli
fi

# Step 2: Login to Azure
echo "Logging into Azure..."
az login

# Step 3: Set subscription
az account set --subscription "1992b163-f828-4887-90c0-b6d26c8ab353"

# Step 4: Run the Container Apps deployment
echo "Starting deployment (this will take ~30 minutes)..."
./azure-deployment/container-apps/deploy-aca.sh

echo "✅ Deployment initiated!"

