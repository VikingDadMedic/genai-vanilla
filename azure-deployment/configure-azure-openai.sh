#!/bin/bash

# Configure all services to use Azure OpenAI
# This reduces/eliminates the need for GPU VM and Ollama

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

print_status() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Load environment
if [ ! -f ".env.azure.prod" ]; then
    echo -e "${RED}Error: .env.azure.prod not found. Run deployment first.${NC}"
    exit 1
fi

source .env.azure.prod

print_header "🚀 Configuring Azure OpenAI for All Services"

# =============================================================================
# UPDATE ENVIRONMENT VARIABLES
# =============================================================================

update_env_file() {
    print_header "Updating Environment Configuration"
    
    # Backup current env
    cp .env.azure.prod .env.azure.prod.backup
    
    # Add Azure OpenAI specific configurations
    cat >> .env.azure.prod << EOF

# ============================================
# AZURE OPENAI CONFIGURATION FOR ALL SERVICES
# ============================================

# Primary LLM Configuration (Azure OpenAI)
LLM_PROVIDER=azure-openai
LLM_PROVIDER_SOURCE=api
DEFAULT_LLM_MODEL=gpt-4

# Azure OpenAI Settings
AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_KEY=$AZURE_OPENAI_KEY
AZURE_OPENAI_API_VERSION=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_GPT4=$AZURE_OPENAI_DEPLOYMENT_GPT4
AZURE_OPENAI_DEPLOYMENT_GPT35=$AZURE_OPENAI_DEPLOYMENT_GPT35
AZURE_OPENAI_DEPLOYMENT_EMBEDDINGS=$AZURE_OPENAI_DEPLOYMENT_EMBEDDINGS

# OpenAI SDK Compatibility
OPENAI_API_TYPE=azure
OPENAI_API_BASE=$AZURE_OPENAI_ENDPOINT
OPENAI_API_KEY=$AZURE_OPENAI_KEY
OPENAI_API_VERSION=2024-02-15-preview

# Service-Specific Azure OpenAI Config
# Open-WebUI
WEBUI_OPENAI_API_BASE=$AZURE_OPENAI_ENDPOINT
WEBUI_OPENAI_API_KEY=$AZURE_OPENAI_KEY
WEBUI_DEFAULT_MODELS=gpt-4,gpt-35-turbo
WEBUI_MODEL_FILTER_ENABLED=false
ENABLE_OPENAI_API=true

# Deep Researcher
DEEP_RESEARCHER_LLM_PROVIDER=azure-openai
DEEP_RESEARCHER_AZURE_ENDPOINT=$AZURE_OPENAI_ENDPOINT
DEEP_RESEARCHER_AZURE_KEY=$AZURE_OPENAI_KEY
DEEP_RESEARCHER_MODEL=$AZURE_OPENAI_DEPLOYMENT_GPT4

# n8n
N8N_AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
N8N_AZURE_OPENAI_KEY=$AZURE_OPENAI_KEY
N8N_DEFAULT_AI_MODEL=$AZURE_OPENAI_DEPLOYMENT_GPT35

# ComfyUI (for prompting)
COMFYUI_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
COMFYUI_OPENAI_KEY=$AZURE_OPENAI_KEY

# Weaviate
WEAVIATE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
WEAVIATE_OPENAI_KEY=$AZURE_OPENAI_KEY
WEAVIATE_DEFAULT_VECTORIZER=text2vec-openai
WEAVIATE_DEFAULT_GENERATIVE=generative-openai

# Fallback to Ollama (optional, disabled by default)
OLLAMA_ENABLED=false
OLLAMA_FALLBACK=false
OLLAMA_SCALE=0
GPU_VM_REQUIRED=false
EOF
    
    print_success "Environment file updated with Azure OpenAI config"
}

# =============================================================================
# CONFIGURE OPEN-WEBUI
# =============================================================================

configure_open_webui() {
    print_header "Configuring Open-WebUI for Azure OpenAI"
    
    cat > open-webui/azure-openai-config.json << 'EOF'
{
  "name": "Azure OpenAI Configuration",
  "config": {
    "openai": {
      "enabled": true,
      "api_base": "${AZURE_OPENAI_ENDPOINT}",
      "api_key": "${AZURE_OPENAI_KEY}",
      "api_type": "azure",
      "api_version": "2024-02-15-preview",
      "deployments": {
        "gpt-4": {
          "deployment_name": "gpt-4",
          "model": "gpt-4",
          "max_tokens": 4096,
          "temperature": 0.7
        },
        "gpt-35-turbo": {
          "deployment_name": "gpt-35-turbo",
          "model": "gpt-35-turbo",
          "max_tokens": 4096,
          "temperature": 0.7
        },
        "embeddings": {
          "deployment_name": "text-embedding-ada-002",
          "model": "text-embedding-ada-002"
        }
      }
    },
    "models": {
      "filter": {
        "enabled": false,
        "list": ["gpt-4", "gpt-35-turbo"]
      },
      "default": "gpt-4"
    },
    "ollama": {
      "enabled": false,
      "base_url": "http://localhost:11434"
    }
  }
}
EOF

    # Update Open-WebUI Docker compose
    cat > docker-compose.openwebui-azure.yml << 'EOF'
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: genai-open-webui
    environment:
      # Azure OpenAI Configuration
      - OPENAI_API_TYPE=azure
      - OPENAI_API_BASE=${AZURE_OPENAI_ENDPOINT}
      - OPENAI_API_KEY=${AZURE_OPENAI_KEY}
      - OPENAI_API_VERSION=2024-02-15-preview
      
      # Disable Ollama
      - ENABLE_OLLAMA_API=false
      - OLLAMA_BASE_URL=""
      
      # Model Settings
      - DEFAULT_MODELS=gpt-4,gpt-35-turbo
      - MODEL_FILTER_ENABLED=false
      - TASK_MODEL=gpt-35-turbo
      - TASK_MODEL_EXTERNAL=gpt-4
      
      # WebUI Settings
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)}
      - WEBUI_NAME=GenAI Azure Portal
      - ENABLE_SIGNUP=true
      - DEFAULT_USER_ROLE=user
      - ENABLE_COMMUNITY_SHARING=false
      
      # Database
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - open-webui-data:/app/backend/data
      - ./open-webui/tools:/app/backend/data/tools
      - ./open-webui/functions:/app/backend/data/functions
    ports:
      - "63015:8080"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  open-webui-data:
EOF
    
    print_success "Open-WebUI configured for Azure OpenAI"
}

# =============================================================================
# CONFIGURE DEEP RESEARCHER
# =============================================================================

configure_deep_researcher() {
    print_header "Configuring Deep Researcher for Azure OpenAI"
    
    # Update Deep Researcher config
    cat > local-deep-researcher/config/azure-openai-config.py << 'EOF'
"""
Azure OpenAI Configuration for Deep Researcher
"""

import os
from typing import Dict, Any

class AzureOpenAIConfig:
    def __init__(self):
        self.endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        self.api_key = os.getenv("AZURE_OPENAI_KEY")
        self.api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview")
        self.deployment_gpt4 = os.getenv("AZURE_OPENAI_DEPLOYMENT_GPT4", "gpt-4")
        self.deployment_gpt35 = os.getenv("AZURE_OPENAI_DEPLOYMENT_GPT35", "gpt-35-turbo")
        self.deployment_embeddings = os.getenv("AZURE_OPENAI_DEPLOYMENT_EMBEDDINGS", "text-embedding-ada-002")
    
    def get_llm_config(self, model: str = "gpt-4") -> Dict[str, Any]:
        """Get LangChain compatible Azure OpenAI configuration"""
        deployment = self.deployment_gpt4 if model == "gpt-4" else self.deployment_gpt35
        
        return {
            "api_type": "azure",
            "api_base": self.endpoint,
            "api_key": self.api_key,
            "api_version": self.api_version,
            "deployment_name": deployment,
            "model_name": model,
            "temperature": 0.7,
            "max_tokens": 4096,
            "streaming": True
        }
    
    def get_embeddings_config(self) -> Dict[str, Any]:
        """Get embeddings configuration"""
        return {
            "api_type": "azure",
            "api_base": self.endpoint,
            "api_key": self.api_key,
            "api_version": self.api_version,
            "deployment_name": self.deployment_embeddings,
            "model": "text-embedding-ada-002"
        }

# Export configuration
azure_config = AzureOpenAIConfig()
EOF

    # Update Deep Researcher main script
    cat > local-deep-researcher/scripts/init-azure.py << 'EOF'
#!/usr/bin/env python3
"""
Initialize Deep Researcher with Azure OpenAI
"""

import os
import sys
import json
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from config.azure_openai_config import azure_config
from langchain_openai import AzureChatOpenAI, AzureOpenAIEmbeddings
from langchain.memory import ConversationBufferMemory
from langgraph.graph import StateGraph, END

def initialize_azure_llm():
    """Initialize Azure OpenAI LLM"""
    config = azure_config.get_llm_config("gpt-4")
    
    llm = AzureChatOpenAI(
        azure_endpoint=config["api_base"],
        openai_api_key=config["api_key"],
        openai_api_version=config["api_version"],
        deployment_name=config["deployment_name"],
        temperature=config["temperature"],
        max_tokens=config["max_tokens"],
        streaming=config["streaming"]
    )
    
    return llm

def initialize_azure_embeddings():
    """Initialize Azure OpenAI Embeddings"""
    config = azure_config.get_embeddings_config()
    
    embeddings = AzureOpenAIEmbeddings(
        azure_endpoint=config["api_base"],
        openai_api_key=config["api_key"],
        openai_api_version=config["api_version"],
        azure_deployment=config["deployment_name"]
    )
    
    return embeddings

def create_research_graph(llm, embeddings):
    """Create LangGraph research workflow with Azure OpenAI"""
    
    # Define the graph state
    class ResearchState(dict):
        query: str
        search_results: list
        analysis: str
        final_answer: str
    
    # Create the graph
    workflow = StateGraph(ResearchState)
    
    # Add nodes for research steps
    def search_web(state):
        # Use SearxNG for web search
        return state
    
    def analyze_results(state):
        # Use Azure GPT-4 for analysis
        response = llm.invoke(f"Analyze these search results: {state['search_results']}")
        state['analysis'] = response.content
        return state
    
    def generate_answer(state):
        # Use Azure GPT-4 for final answer
        response = llm.invoke(f"Based on this analysis: {state['analysis']}, answer: {state['query']}")
        state['final_answer'] = response.content
        return state
    
    # Add nodes to workflow
    workflow.add_node("search", search_web)
    workflow.add_node("analyze", analyze_results)
    workflow.add_node("answer", generate_answer)
    
    # Define edges
    workflow.add_edge("search", "analyze")
    workflow.add_edge("analyze", "answer")
    workflow.add_edge("answer", END)
    
    # Set entry point
    workflow.set_entry_point("search")
    
    return workflow.compile()

if __name__ == "__main__":
    print("🚀 Initializing Deep Researcher with Azure OpenAI...")
    
    # Initialize components
    llm = initialize_azure_llm()
    embeddings = initialize_azure_embeddings()
    research_graph = create_research_graph(llm, embeddings)
    
    print("✅ Deep Researcher configured with Azure OpenAI!")
    print(f"  - LLM: Azure GPT-4")
    print(f"  - Embeddings: Azure text-embedding-ada-002")
    print(f"  - Endpoint: {azure_config.endpoint}")
EOF

    # Update Dockerfile to use Azure OpenAI
    cat > local-deep-researcher/Dockerfile.azure << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    langchain \
    langchain-openai \
    langgraph \
    langserve \
    fastapi \
    uvicorn \
    httpx \
    pydantic

# Copy application
COPY config/ /app/config/
COPY scripts/ /app/scripts/
COPY *.py /app/

# Environment variables for Azure OpenAI
ENV AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
ENV AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
ENV AZURE_OPENAI_API_VERSION=2024-02-15-preview
ENV AZURE_OPENAI_DEPLOYMENT_GPT4=gpt-4
ENV AZURE_OPENAI_DEPLOYMENT_GPT35=gpt-35-turbo
ENV AZURE_OPENAI_DEPLOYMENT_EMBEDDINGS=text-embedding-ada-002

# No need for Ollama
ENV USE_OLLAMA=false
ENV LLM_PROVIDER=azure-openai

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
    
    print_success "Deep Researcher configured for Azure OpenAI"
}

# =============================================================================
# CONFIGURE N8N
# =============================================================================

configure_n8n() {
    print_header "Configuring n8n for Azure OpenAI"
    
    # Create n8n Azure OpenAI credentials template
    cat > n8n/credentials/azure-openai.json << 'EOF'
{
  "name": "Azure OpenAI",
  "type": "azureOpenAi",
  "data": {
    "endpoint": "${AZURE_OPENAI_ENDPOINT}",
    "apiKey": "${AZURE_OPENAI_KEY}",
    "apiVersion": "2024-02-15-preview",
    "deployments": {
      "chat": {
        "gpt4": "gpt-4",
        "gpt35": "gpt-35-turbo"
      },
      "embeddings": "text-embedding-ada-002"
    }
  }
}
EOF

    # Create n8n workflow for Azure OpenAI
    cat > n8n/workflows/azure-openai-workflow.json << 'EOF'
{
  "name": "Azure OpenAI Workflow",
  "nodes": [
    {
      "parameters": {
        "model": "gpt-4",
        "prompt": "={{ $json.prompt }}",
        "temperature": 0.7,
        "maxTokens": 4096
      },
      "name": "Azure OpenAI Chat",
      "type": "n8n-nodes-base.openAi",
      "typeVersion": 1,
      "position": [450, 300],
      "credentials": {
        "openAiApi": {
          "id": "azure-openai",
          "name": "Azure OpenAI"
        }
      },
      "azure": {
        "endpoint": "${AZURE_OPENAI_ENDPOINT}",
        "apiVersion": "2024-02-15-preview",
        "deploymentName": "gpt-4"
      }
    }
  ]
}
EOF

    # Update n8n Docker compose
    cat > docker-compose.n8n-azure.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: genai-n8n
    environment:
      # Database
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${DATABASE_HOST}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DATABASE_NAME}
      - DB_POSTGRESDB_USER=${DATABASE_USER}
      - DB_POSTGRESDB_PASSWORD=${DATABASE_PASSWORD}
      
      # Azure OpenAI
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - AZURE_OPENAI_API_VERSION=2024-02-15-preview
      
      # n8n Configuration
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://${AZURE_CORE_VM_IP}:63017
      
      # Enable AI features
      - N8N_AI_ENABLED=true
      - N8N_AI_PROVIDER=azure-openai
    volumes:
      - n8n-data:/home/node/.n8n
      - ./n8n/workflows:/home/node/workflows
      - ./n8n/credentials:/home/node/.n8n/credentials
    ports:
      - "63017:5678"
    restart: unless-stopped

volumes:
  n8n-data:
EOF
    
    print_success "n8n configured for Azure OpenAI"
}

# =============================================================================
# UPDATE DOCKER COMPOSE FILES
# =============================================================================

create_optimized_compose() {
    print_header "Creating Optimized Docker Compose (No GPU Required)"
    
    cat > docker-compose.azure-optimized.yml << 'EOF'
version: '3.8'

services:
  # Backend API - using Azure OpenAI
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: genai-backend
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - LLM_PROVIDER=azure-openai
      - USE_OLLAMA=false
    volumes:
      - ./backend/app:/app
    ports:
      - "63016:8000"
    restart: unless-stopped
    networks:
      - genai-network

  # Open-WebUI - Azure OpenAI configured
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: genai-open-webui
    environment:
      - OPENAI_API_TYPE=azure
      - OPENAI_API_BASE=${AZURE_OPENAI_ENDPOINT}
      - OPENAI_API_KEY=${AZURE_OPENAI_KEY}
      - OPENAI_API_VERSION=2024-02-15-preview
      - ENABLE_OLLAMA_API=false
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - open-webui-data:/app/backend/data
      - ./open-webui/tools:/app/backend/data/tools
      - ./open-webui/functions:/app/backend/data/functions
    ports:
      - "63015:8080"
    restart: unless-stopped
    networks:
      - genai-network

  # n8n - Azure OpenAI configured
  n8n:
    image: n8nio/n8n:latest
    container_name: genai-n8n
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${DATABASE_HOST}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DATABASE_NAME}
      - DB_POSTGRESDB_USER=${DATABASE_USER}
      - DB_POSTGRESDB_PASSWORD=${DATABASE_PASSWORD}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - N8N_AI_ENABLED=true
      - N8N_AI_PROVIDER=azure-openai
    volumes:
      - n8n-data:/home/node/.n8n
      - ./n8n/workflows:/home/node/workflows
    ports:
      - "63017:5678"
    restart: unless-stopped
    networks:
      - genai-network

  # Deep Researcher - Azure OpenAI configured
  deep-researcher:
    build:
      context: ./local-deep-researcher
      dockerfile: Dockerfile.azure
    container_name: genai-researcher
    environment:
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - AZURE_OPENAI_API_VERSION=2024-02-15-preview
      - USE_OLLAMA=false
      - LLM_PROVIDER=azure-openai
      - SEARXNG_URL=http://searxng:8080
    volumes:
      - ./local-deep-researcher/config:/app/config
      - research-data:/app/research
    ports:
      - "63013:8000"
    restart: unless-stopped
    depends_on:
      - searxng
    networks:
      - genai-network

  # SearxNG - for web search
  searxng:
    image: searxng/searxng:latest
    container_name: genai-searxng
    environment:
      - SEARXNG_BASE_URL=http://localhost:63014/
    volumes:
      - ./searxng/config:/etc/searxng
    ports:
      - "63014:8080"
    restart: unless-stopped
    networks:
      - genai-network

  # Weaviate - using Azure OpenAI for vectorization
  weaviate:
    image: cr.weaviate.io/semitechnologies/weaviate:latest
    container_name: genai-weaviate
    environment:
      - QUERY_DEFAULTS_LIMIT=25
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=true
      - PERSISTENCE_DATA_PATH=/var/lib/weaviate
      - DEFAULT_VECTORIZER_MODULE=text2vec-openai
      - ENABLE_MODULES=text2vec-openai,generative-openai
      - OPENAI_APIKEY=${AZURE_OPENAI_KEY}
      - OPENAI_BASEURL=${AZURE_OPENAI_ENDPOINT}
      - OPENAI_ORGANIZATION=azure
    volumes:
      - weaviate-data:/var/lib/weaviate
    ports:
      - "63019:8080"
      - "50051:50051"
    restart: unless-stopped
    networks:
      - genai-network

  # ComfyUI - still needs GPU but can use Azure for prompting
  # This can be moved to a separate GPU VM or Azure Container Instance
  # comfyui:
  #   ... (optional, only if image generation needed)

  # ACI Backend - already configured
  aci-backend:
    build:
      context: ./aci-integration/aci-opensource/backend
      dockerfile: Dockerfile.server
    container_name: genai-aci-backend
    environment:
      - SERVER_DB_HOST=${DATABASE_HOST}
      - SERVER_DB_PORT=5432
      - SERVER_DB_USER=${DATABASE_USER}
      - SERVER_DB_PASSWORD=${DATABASE_PASSWORD}
      - SERVER_DB_NAME=aci_db
      - SERVER_OPENAI_API_KEY=${AZURE_OPENAI_KEY}
      - SERVER_OPENAI_API_BASE=${AZURE_OPENAI_ENDPOINT}
    ports:
      - "63026:8000"
    restart: unless-stopped
    networks:
      - genai-network

  # ACI Frontend
  aci-frontend:
    build:
      context: ./aci-integration/aci-opensource/frontend
      dockerfile: Dockerfile
    container_name: genai-aci-frontend
    environment:
      - NEXT_PUBLIC_BACKEND_URL=http://localhost:63026
    ports:
      - "63027:3000"
    restart: unless-stopped
    depends_on:
      - aci-backend
    networks:
      - genai-network

volumes:
  open-webui-data:
  n8n-data:
  weaviate-data:
  research-data:

networks:
  genai-network:
    driver: bridge
EOF
    
    print_success "Optimized Docker Compose created (no GPU required)"
}

# =============================================================================
# CREATE COST COMPARISON
# =============================================================================

create_cost_analysis() {
    print_header "Creating Cost Analysis"
    
    cat > azure-deployment/AZURE_OPENAI_COST_ANALYSIS.md << 'EOF'
# 💰 Azure OpenAI Cost Analysis

## Architecture Comparison

### Option A: GPU VM + Ollama (Original)
```yaml
Infrastructure:
  GPU VM (NC8as_T4_v3): $150/month (spot)
  Core VM (D8s_v5): $140/month
  PostgreSQL: $50/month
  Redis: $50/month
  Storage: $20/month
  Total: $410/month

Usage Costs:
  Ollama: $0 (self-hosted)
  Total: $410/month fixed
```

### Option B: Azure OpenAI Only (Optimized) ✅
```yaml
Infrastructure:
  Core VM (D8s_v5): $140/month  # No GPU needed!
  PostgreSQL: $50/month
  Redis: $50/month
  Storage: $20/month
  Total: $260/month

Usage Costs (estimated):
  GPT-4: ~$100-300/month
  GPT-3.5: ~$20-50/month
  Embeddings: ~$10/month
  Total: $390-590/month
```

### Option C: Hybrid (GPU for Images Only)
```yaml
Infrastructure:
  GPU VM (on-demand): ~$50/month (10 hours/month)
  Core VM: $140/month
  Managed Services: $120/month
  Total: $310/month + Azure OpenAI usage
```

## 📊 Cost Benefits of Azure OpenAI

1. **No GPU VM Required** - Save $150/month
2. **Better Performance** - GPT-4 > Llama/Qwen
3. **No Maintenance** - Managed service
4. **Pay Per Use** - Scale with demand
5. **Lower Latency** - Optimized infrastructure

## 🎯 Recommended Architecture

**Go with Option B: Azure OpenAI Only**
- Total Cost: ~$400-500/month
- Performance: Superior
- Maintenance: Minimal
- Scalability: Unlimited

## Usage Estimates

### Light Usage (3-5 users)
```
Daily: 100 requests
GPT-4: 50 requests × $0.03 = $1.50/day = $45/month
GPT-3.5: 50 requests × $0.002 = $0.10/day = $3/month
Total: ~$50/month
```

### Medium Usage (10 users)
```
Daily: 500 requests
GPT-4: 200 requests × $0.03 = $6/day = $180/month
GPT-3.5: 300 requests × $0.002 = $0.60/day = $18/month
Total: ~$200/month
```

### Heavy Usage (20+ users)
```
Daily: 2000 requests
GPT-4: 500 requests × $0.03 = $15/day = $450/month
GPT-3.5: 1500 requests × $0.002 = $3/day = $90/month
Total: ~$540/month
```

## 🚀 Migration Plan

1. **Phase 1**: Configure all services for Azure OpenAI
2. **Phase 2**: Test without GPU VM
3. **Phase 3**: Deallocate GPU VM (save $150/month)
4. **Phase 4**: Monitor usage and optimize

## ⚡ Performance Comparison

| Metric | Ollama (Llama 7B) | Azure GPT-3.5 | Azure GPT-4 |
|--------|-------------------|---------------|-------------|
| Latency | 500-2000ms | 50-200ms | 100-500ms |
| Quality | Good | Better | Best |
| Context | 4K tokens | 16K tokens | 128K tokens |
| Cost | $150/mo (VM) | $0.002/1K | $0.03/1K |
EOF
    
    print_success "Cost analysis created"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "🚀 Azure OpenAI Configuration"
    
    echo -e "${MAGENTA}This will configure all services to use Azure OpenAI${NC}"
    echo -e "${MAGENTA}GPU VM will become optional (only needed for ComfyUI)${NC}"
    echo ""
    
    # Run configuration steps
    update_env_file
    configure_open_webui
    configure_deep_researcher
    configure_n8n
    create_optimized_compose
    create_cost_analysis
    
    print_header "✅ Azure OpenAI Configuration Complete!"
    
    echo -e "\n${GREEN}What's Changed:${NC}"
    echo "✅ Open-WebUI → Azure OpenAI (GPT-4/GPT-3.5)"
    echo "✅ Deep Researcher → Azure OpenAI"
    echo "✅ n8n → Azure OpenAI nodes"
    echo "✅ Weaviate → Azure OpenAI embeddings"
    echo "✅ Backend → Azure OpenAI API"
    
    echo -e "\n${YELLOW}Cost Savings:${NC}"
    echo "• GPU VM no longer required (-$150/month)"
    echo "• Better performance than Ollama"
    echo "• Pay only for what you use"
    
    echo -e "\n${BLUE}New Architecture:${NC}"
    echo "• Core VM: All services (no GPU needed)"
    echo "• Azure OpenAI: All LLM operations"
    echo "• Optional: GPU only for ComfyUI images"
    
    echo -e "\n${MAGENTA}To deploy without GPU:${NC}"
    echo "1. Use: docker-compose.azure-optimized.yml"
    echo "2. Skip GPU VM creation in deployment"
    echo "3. Save $150/month!"
    
    echo -e "\n${GREEN}Deployment command:${NC}"
    echo "docker-compose -f docker-compose.azure-optimized.yml up -d"
}

main "$@"
