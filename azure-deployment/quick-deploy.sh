#!/bin/bash

# Quick Azure Deployment Script
# Handles Azure CLI installation and deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}   🚀 GenAI Stack - Quick Azure Deploy      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

# Check if running in background
if [ "$1" == "--background" ]; then
    echo -e "${YELLOW}Running in background mode...${NC}"
    nohup $0 --execute > azure-deployment.log 2>&1 &
    PID=$!
    echo -e "${GREEN}✓ Deployment started in background (PID: $PID)${NC}"
    echo -e "${YELLOW}Monitor with: tail -f azure-deployment.log${NC}"
    exit 0
fi

# Step 1: Check Azure CLI
echo -e "\n${YELLOW}Step 1: Checking Azure CLI...${NC}"
if command -v az &> /dev/null; then
    echo -e "${GREEN}✓ Azure CLI is installed${NC}"
    az --version | head -1
else
    echo -e "${RED}✗ Azure CLI not found${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Installing Azure CLI via Homebrew...${NC}"
        
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}Installing Homebrew first...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # Install Azure CLI
        brew update && brew install azure-cli
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Azure CLI installed successfully${NC}"
        else
            echo -e "${RED}Failed to install Azure CLI${NC}"
            echo "Please install manually: https://docs.microsoft.com/cli/azure/install-azure-cli"
            exit 1
        fi
    else
        echo -e "${YELLOW}Please install Azure CLI manually:${NC}"
        echo "https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
fi

# Step 2: Azure Login
echo -e "\n${YELLOW}Step 2: Azure Authentication...${NC}"
if az account show &> /dev/null; then
    echo -e "${GREEN}✓ Already logged in to Azure${NC}"
    CURRENT_SUB=$(az account show --query id -o tsv)
    echo -e "Current subscription: $CURRENT_SUB"
    
    if [ "$CURRENT_SUB" != "1992b163-f828-4887-90c0-b6d26c8ab353" ]; then
        echo -e "${YELLOW}Switching to GenAI subscription...${NC}"
        az account set --subscription "1992b163-f828-4887-90c0-b6d26c8ab353"
    fi
else
    echo -e "${YELLOW}Please login to Azure...${NC}"
    az login
    
    echo -e "${YELLOW}Setting subscription...${NC}"
    az account set --subscription "1992b163-f828-4887-90c0-b6d26c8ab353"
fi

# Step 3: Deployment Choice
if [ "$1" != "--execute" ]; then
    echo -e "\n${YELLOW}Step 3: Deployment Options${NC}"
    echo "1) Deploy now (interactive)"
    echo "2) Deploy in background"
    echo "3) Just setup, deploy later"
    read -p "Choice (1-3): " CHOICE
    
    case $CHOICE in
        1)
            echo -e "${GREEN}Starting deployment...${NC}"
            ;;
        2)
            exec $0 --background
            ;;
        3)
            echo -e "${GREEN}✓ Setup complete! Run deployment later with:${NC}"
            echo "./azure-deployment/container-apps/deploy-aca.sh"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
fi

# Step 4: Run Deployment
echo -e "\n${YELLOW}Step 4: Running Azure Container Apps Deployment${NC}"
echo -e "${BLUE}This will take approximately 30 minutes...${NC}"

# Check if deployment script exists
DEPLOY_SCRIPT="./azure-deployment/container-apps/deploy-aca.sh"
if [ ! -f "$DEPLOY_SCRIPT" ]; then
    echo -e "${RED}Deployment script not found at $DEPLOY_SCRIPT${NC}"
    exit 1
fi

# Make it executable
chmod +x "$DEPLOY_SCRIPT"

# Create deployment log directory
mkdir -p ./azure-deployment/logs

# Run deployment with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="./azure-deployment/logs/deployment-$TIMESTAMP.log"

echo -e "${YELLOW}Logging to: $LOG_FILE${NC}"
$DEPLOY_SCRIPT 2>&1 | tee "$LOG_FILE"

# Check if deployment succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "\n${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ✅ DEPLOYMENT SUCCESSFUL!              ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    
    # Extract URLs from deployment
    if [ -f ".env.aca" ]; then
        echo -e "\n${BLUE}Your services are available at:${NC}"
        grep "_URL=" .env.aca | while read -r line; do
            echo -e "  ${GREEN}$line${NC}"
        done
    fi
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Continue local development as usual"
    echo "2. Push changes to GitHub"
    echo "3. Services auto-update in Azure"
    
    echo -e "\n${BLUE}Useful commands:${NC}"
    echo "  View apps:  az containerapp list -g genai-aca-rg -o table"
    echo "  View logs:  az containerapp logs show -n open-webui -g genai-aca-rg"
    echo "  Scale app:  az containerapp update -n open-webui -g genai-aca-rg --max-replicas 5"
else
    echo -e "\n${RED}═══════════════════════════════════════════${NC}"
    echo -e "${RED}     ❌ DEPLOYMENT FAILED                   ${NC}"
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Check the log file: $LOG_FILE${NC}"
    exit 1
fi

echo -e "\n${GREEN}You can now work locally and in Azure simultaneously!${NC}"
