#!/bin/bash

# Setup Azure CLI for Azure DevOps MCP
# This script installs Azure CLI and configures it for the GenAI project

set -e

# Colors
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

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header "🔧 Azure CLI Setup for GenAI Stack"

# Check if Azure CLI is installed
if command -v az &> /dev/null; then
    print_success "Azure CLI is already installed"
    az --version | head -1
else
    print_status "Azure CLI not found. Installing..."
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        print_status "Installing Azure CLI via Homebrew..."
        if ! command -v brew &> /dev/null; then
            print_error "Homebrew not found. Please install from https://brew.sh"
            exit 1
        fi
        brew update && brew install azure-cli
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        print_status "Installing Azure CLI for Linux..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        print_error "Unsupported OS. Please install Azure CLI manually:"
        echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    print_success "Azure CLI installed successfully"
fi

print_header "🔐 Azure Authentication"

# Check login status
if az account show &> /dev/null; then
    print_success "Already logged in to Azure"
    echo -e "${GREEN}Current subscription:${NC}"
    az account show --query "{Name:name, ID:id}" -o table
else
    print_status "Not logged in. Starting login process..."
    az login
    
    if [ $? -eq 0 ]; then
        print_success "Successfully logged in to Azure"
    else
        print_error "Login failed. Please try again."
        exit 1
    fi
fi

# Set subscription if specified
if [ ! -z "$AZURE_SUBSCRIPTION_ID" ]; then
    print_status "Setting subscription to: $AZURE_SUBSCRIPTION_ID"
    az account set --subscription "$AZURE_SUBSCRIPTION_ID"
    print_success "Subscription set"
fi

print_header "🚀 Azure DevOps Extension"

# Install Azure DevOps extension
if az extension show --name azure-devops &> /dev/null; then
    print_success "Azure DevOps extension is already installed"
else
    print_status "Installing Azure DevOps extension..."
    az extension add --name azure-devops
    print_success "Azure DevOps extension installed"
fi

print_header "📋 Configuration Check"

# Test Azure DevOps access
print_status "Enter your Azure DevOps organization name (e.g., 'contoso'):"
read -p "> " ADO_ORG

if [ ! -z "$ADO_ORG" ]; then
    print_status "Testing Azure DevOps access..."
    if az devops project list --organization "https://dev.azure.com/$ADO_ORG" &> /dev/null; then
        print_success "Successfully connected to Azure DevOps organization: $ADO_ORG"
        
        # Save to environment
        echo -e "\n${YELLOW}Add this to your shell profile (.zshrc or .bashrc):${NC}"
        echo "export AZURE_DEVOPS_ORG=$ADO_ORG"
        
        # Update project MCP config
        print_status "Updating project MCP configuration..."
        if [ -f ".cursor/mcp.json" ]; then
            print_success "Project MCP config found and ready"
        else
            print_status "Creating project MCP config..."
            mkdir -p .cursor
            cat > .cursor/mcp.json << EOF
{
  "inputs": [
    {
      "id": "ado_org",
      "type": "promptString",
      "description": "Azure DevOps organization name",
      "default": "$ADO_ORG"
    }
  ],
  "mcpServers": {
    "azure-devops": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@azure-devops/mcp",
        "\${input:ado_org}",
        "-d",
        "core",
        "work",
        "work-items",
        "repositories",
        "pipelines",
        "wiki"
      ]
    }
  }
}
EOF
            print_success "Project MCP config created with organization: $ADO_ORG"
        fi
    else
        print_error "Could not connect to Azure DevOps organization: $ADO_ORG"
        echo "Please check the organization name and your permissions"
    fi
fi

print_header "✅ Setup Complete!"

echo -e "\n${GREEN}Azure CLI is configured and ready for use with:${NC}"
echo "• Azure subscription access"
echo "• Azure DevOps MCP server"
echo "• GenAI deployment scripts"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Restart Cursor to load the MCP configuration"
echo "2. In Cursor chat, you'll be prompted for your Azure DevOps org name"
echo "3. Try: 'List my ADO projects' to test the connection"

echo -e "\n${BLUE}Useful commands:${NC}"
echo "az account show                    # View current Azure account"
echo "az devops project list              # List Azure DevOps projects"
echo "az vm list -o table                 # List Azure VMs"
echo "az resource list -o table           # List all Azure resources"

