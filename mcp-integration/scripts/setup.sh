#!/bin/bash

# MCP Integration Setup Script for GenAI Vanilla Stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MCP_DIR="$PROJECT_ROOT/mcp-integration"

echo -e "${BLUE}🚀 GenAI Vanilla Stack - MCP Integration Setup${NC}"
echo "================================================"

# Check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker found${NC}"
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker Compose found${NC}"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}⚠️  Python 3 not found (optional for testing)${NC}"
    else
        echo -e "${GREEN}✅ Python 3 found${NC}"
    fi
}

# Setup environment variables
setup_environment() {
    echo -e "\n${YELLOW}Setting up environment variables...${NC}"
    
    ENV_FILE="$PROJECT_ROOT/.env.mcp"
    ENV_TEMPLATE="$MCP_DIR/config/.env.mcp.template"
    
    # Create template if it doesn't exist
    if [ ! -f "$ENV_TEMPLATE" ]; then
        cat > "$ENV_TEMPLATE" << 'EOF'
# ACI.dev Configuration
ACI_API_KEY=your_aci_api_key_here
ACI_LINKED_ACCOUNT_ID=default_user
ACI_ENABLED_APPS=GITHUB,GMAIL,BRAVE_SEARCH,SLACK,DISCORD

# MCP Server Configuration
MCP_TRANSPORT=sse
MCP_BASE_PORT=63022
ACI_MCP_PORT=63022
ACI_MCP_UNIFIED_PORT=63023
OPEN_WEBUI_MCP_PORT=63024
MCP_ROUTER_PORT=63025
ACI_MCP_SCALE=1
ACI_MCP_UNIFIED_SCALE=1
OPEN_WEBUI_MCP_SCALE=1
MCP_ROUTER_SCALE=1

# Feature Flags
ENABLE_MCP_DISCOVERY=true
ENABLE_MCP_CACHING=true
MCP_CACHE_TTL=300
MCP_LOG_LEVEL=INFO

# Redis Configuration (if not already set)
REDIS_PASSWORD=redis_password
EOF
        echo -e "${GREEN}✅ Created environment template${NC}"
    fi
    
    # Copy template to .env.mcp if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        cp "$ENV_TEMPLATE" "$ENV_FILE"
        echo -e "${GREEN}✅ Created .env.mcp - Please configure your ACI_API_KEY${NC}"
        echo -e "${YELLOW}   Edit $ENV_FILE and add your ACI.dev API key${NC}"
    else
        echo -e "${GREEN}✅ .env.mcp already exists${NC}"
    fi
    
    # Source the environment file
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
    
    # Check for API key
    if [ "$ACI_API_KEY" = "your_aci_api_key_here" ] || [ -z "$ACI_API_KEY" ]; then
        echo -e "${RED}⚠️  ACI_API_KEY not configured!${NC}"
        echo -e "${YELLOW}   Please edit $ENV_FILE and add your ACI.dev API key${NC}"
        echo -e "${YELLOW}   Get your API key from: https://platform.aci.dev/project-setting${NC}"
    else
        echo -e "${GREEN}✅ ACI_API_KEY configured${NC}"
    fi
}

# Create directory structure
create_directories() {
    echo -e "\n${YELLOW}Creating directory structure...${NC}"
    
    mkdir -p "$MCP_DIR/docker"
    mkdir -p "$MCP_DIR/config"
    mkdir -p "$MCP_DIR/backend"
    mkdir -p "$MCP_DIR/open-webui/functions"
    mkdir -p "$MCP_DIR/open-webui/tools"
    mkdir -p "$MCP_DIR/scripts"
    mkdir -p "$MCP_DIR/logs"
    
    echo -e "${GREEN}✅ Directory structure created${NC}"
}

# Create Docker files
create_docker_files() {
    echo -e "\n${YELLOW}Creating Docker configuration files...${NC}"
    
    # Create mcp-router Dockerfile
    cat > "$MCP_DIR/docker/mcp-router.dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    httpx \
    redis \
    python-multipart \
    pydantic

# Copy application files
COPY ../backend/mcp_router.py /app/
COPY ../backend/aci_mcp_client.py /app/

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "mcp_router:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
    
    # Create openwebui-mcp Dockerfile
    cat > "$MCP_DIR/docker/openwebui-mcp.dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install MCP SDK and dependencies
RUN pip install --no-cache-dir \
    mcp \
    httpx \
    fastapi \
    uvicorn \
    redis \
    pydantic

# Copy application files
COPY ../open-webui/mcp_server.py /app/

# Expose port
EXPOSE 8200

# Run the MCP server
CMD ["python", "mcp_server.py"]
EOF
    
    echo -e "${GREEN}✅ Docker files created${NC}"
}

# Create MCP router service
create_mcp_router() {
    echo -e "\n${YELLOW}Creating MCP router service...${NC}"
    
    cat > "$MCP_DIR/backend/mcp_router.py" << 'EOF'
"""
MCP Router Service
Routes requests between different MCP servers and provides caching
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
import httpx
import os
import redis
import json
import logging
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

app = FastAPI(title="MCP Router", version="1.0.0")

# Redis client for caching
redis_url = os.getenv("REDIS_URL", "redis://redis:6379/2")
try:
    redis_client = redis.from_url(redis_url, decode_responses=True)
    logger.info("Connected to Redis for caching")
except Exception as e:
    logger.warning(f"Redis not available: {e}")
    redis_client = None

# Service URLs
ACI_APPS_URL = os.getenv("ACI_MCP_APPS_URL", "http://aci-mcp-gateway:8100")
ACI_UNIFIED_URL = os.getenv("ACI_MCP_UNIFIED_URL", "http://aci-mcp-unified:8101")
BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:8000")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "mcp-router"}

@app.post("/mcp/route")
async def route_mcp_request(request: Request):
    """
    Route MCP requests to appropriate server based on content
    """
    body = await request.json()
    tool_name = body.get("name", "")
    
    # Determine routing
    if tool_name.startswith("ACI_"):
        # Route to unified server
        target_url = f"{ACI_UNIFIED_URL}/mcp/v1/tools/call"
    elif "__" in tool_name:
        # Route to apps server (app-specific functions)
        target_url = f"{ACI_APPS_URL}/mcp/v1/tools/call"
    else:
        # Route to backend for custom tools
        target_url = f"{BACKEND_URL}/api/tools/{tool_name}"
    
    # Forward request
    async with httpx.AsyncClient() as client:
        response = await client.post(
            target_url,
            json=body,
            headers=request.headers,
            timeout=60.0
        )
        return JSONResponse(content=response.json(), status_code=response.status_code)

@app.get("/mcp/tools")
async def list_all_tools():
    """
    Aggregate tools from all MCP servers
    """
    tools = []
    
    # Get tools from ACI Apps server
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{ACI_APPS_URL}/mcp/v1/tools")
            if response.status_code == 200:
                tools.extend(response.json())
    except Exception as e:
        logger.error(f"Error fetching ACI apps tools: {e}")
    
    # Get meta tools from unified server
    tools.extend([
        {
            "name": "ACI_SEARCH_FUNCTIONS",
            "description": "Search for available functions"
        },
        {
            "name": "ACI_EXECUTE_FUNCTION", 
            "description": "Execute a discovered function"
        }
    ])
    
    return {"tools": tools, "count": len(tools)}

@app.post("/mcp/cache/clear")
async def clear_cache():
    """Clear MCP cache"""
    if redis_client:
        redis_client.flushdb()
        return {"status": "cache_cleared"}
    return {"status": "no_cache"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
    
    echo -e "${GREEN}✅ MCP router service created${NC}"
}

# Update main docker-compose.yml
update_docker_compose() {
    echo -e "\n${YELLOW}Updating Docker Compose configuration...${NC}"
    
    COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
    MCP_INCLUDE="  - path: ./mcp-integration/docker/docker-compose.mcp.yml"
    
    # Check if include section exists
    if grep -q "^include:" "$COMPOSE_FILE"; then
        # Check if MCP include already exists
        if ! grep -q "docker-compose.mcp.yml" "$COMPOSE_FILE"; then
            # Add MCP include after the include: line
            sed -i "/^include:/a\\$MCP_INCLUDE" "$COMPOSE_FILE"
            echo -e "${GREEN}✅ Added MCP services to docker-compose.yml${NC}"
        else
            echo -e "${GREEN}✅ MCP services already in docker-compose.yml${NC}"
        fi
    else
        # Add include section at the beginning of the file
        echo -e "include:\n$MCP_INCLUDE\n\n$(cat $COMPOSE_FILE)" > "$COMPOSE_FILE"
        echo -e "${GREEN}✅ Added include section with MCP services${NC}"
    fi
}

# Update bootstrapper configuration
update_bootstrapper() {
    echo -e "\n${YELLOW}Updating bootstrapper configuration...${NC}"
    
    SERVICE_CONFIG="$PROJECT_ROOT/bootstrapper/service-configs.yml"
    
    # Check if MCP services are already configured
    if ! grep -q "aci-mcp:" "$SERVICE_CONFIG"; then
        cat >> "$SERVICE_CONFIG" << 'EOF'

# MCP Services
aci-mcp:
  source_options:
    - container
    - localhost
    - disabled
  source_configs:
    container:
      scale: 1
      dependencies:
        - backend
    localhost:
      scale: 0
      external_url_required: true
      host_port: 8100
    disabled:
      scale: 0

aci-mcp-unified:
  source_options:
    - container
    - disabled
  source_configs:
    container:
      scale: 1
      dependencies:
        - backend
    disabled:
      scale: 0

open-webui-mcp:
  source_options:
    - container
    - disabled
  source_configs:
    container:
      scale: 1
      dependencies:
        - open-web-ui
        - backend
    disabled:
      scale: 0

mcp-router:
  source_options:
    - container
    - disabled
  source_configs:
    container:
      scale: 1
      dependencies:
        - aci-mcp
        - aci-mcp-unified
        - redis
    disabled:
      scale: 0
EOF
        echo -e "${GREEN}✅ Added MCP services to bootstrapper config${NC}"
    else
        echo -e "${GREEN}✅ MCP services already in bootstrapper config${NC}"
    fi
}

# Test MCP integration
test_integration() {
    echo -e "\n${YELLOW}Testing MCP integration...${NC}"
    
    # Create test script
    cat > "$MCP_DIR/scripts/test_integration.py" << 'EOF'
#!/usr/bin/env python3
"""
MCP Integration Tests
"""

import asyncio
import httpx
import os
import sys

async def test_mcp_health():
    """Test MCP service health endpoints"""
    services = [
        ("ACI MCP Gateway", "http://localhost:63022/health"),
        ("ACI MCP Unified", "http://localhost:63023/health"),
        ("Open WebUI MCP", "http://localhost:63024/health"),
        ("MCP Router", "http://localhost:63025/health")
    ]
    
    print("Testing MCP service health...")
    for name, url in services:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, timeout=5.0)
                if response.status_code == 200:
                    print(f"✅ {name}: Healthy")
                else:
                    print(f"❌ {name}: Unhealthy (status: {response.status_code})")
        except Exception as e:
            print(f"❌ {name}: Not accessible ({str(e)})")

async def test_tool_listing():
    """Test listing available tools"""
    print("\nTesting tool listing...")
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("http://localhost:63025/mcp/tools")
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Found {data['count']} tools")
                for tool in data['tools'][:5]:  # Show first 5
                    print(f"   - {tool['name']}")
            else:
                print(f"❌ Failed to list tools")
    except Exception as e:
        print(f"❌ Error listing tools: {e}")

if __name__ == "__main__":
    asyncio.run(test_mcp_health())
    asyncio.run(test_tool_listing())
EOF
    
    chmod +x "$MCP_DIR/scripts/test_integration.py"
    echo -e "${GREEN}✅ Test script created${NC}"
}

# Start MCP services
start_services() {
    echo -e "\n${YELLOW}Starting MCP services...${NC}"
    
    # Load environment variables
    if [ -f "$PROJECT_ROOT/.env.mcp" ]; then
        export $(grep -v '^#' "$PROJECT_ROOT/.env.mcp" | xargs)
    fi
    
    # Check if API key is configured
    if [ "$ACI_API_KEY" = "your_aci_api_key_here" ] || [ -z "$ACI_API_KEY" ]; then
        echo -e "${RED}⚠️  Cannot start services - ACI_API_KEY not configured${NC}"
        echo -e "${YELLOW}   Please configure your API key first${NC}"
        return
    fi
    
    # Pull ACI MCP image
    echo -e "${BLUE}Pulling ACI MCP image...${NC}"
    docker pull ghcr.io/aipotheosis-labs/aci-mcp:latest || true
    
    # Build custom images
    echo -e "${BLUE}Building custom MCP images...${NC}"
    docker compose -f "$MCP_DIR/docker/docker-compose.mcp.yml" build
    
    # Start services
    echo -e "${BLUE}Starting MCP services...${NC}"
    docker compose -f "$MCP_DIR/docker/docker-compose.mcp.yml" up -d
    
    # Wait for services to be ready
    echo -e "${BLUE}Waiting for services to be ready...${NC}"
    sleep 10
    
    # Check service status
    docker compose -f "$MCP_DIR/docker/docker-compose.mcp.yml" ps
}

# Main setup flow
main() {
    echo -e "${BLUE}Starting MCP Integration Setup...${NC}\n"
    
    check_prerequisites
    create_directories
    setup_environment
    create_docker_files
    create_mcp_router
    update_docker_compose
    update_bootstrapper
    test_integration
    
    echo -e "\n${GREEN}🎉 MCP Integration setup complete!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Configure your ACI.dev API key in .env.mcp"
    echo "2. Sign up at https://platform.aci.dev if you haven't already"
    echo "3. Configure your apps and link accounts on the platform"
    echo "4. Run: docker compose -f mcp-integration/docker/docker-compose.mcp.yml up -d"
    echo "5. Test with: python3 mcp-integration/scripts/test_integration.py"
    
    # Ask if user wants to start services
    echo -e "\n${YELLOW}Do you want to start MCP services now? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        start_services
    fi
}

# Run main function
main
