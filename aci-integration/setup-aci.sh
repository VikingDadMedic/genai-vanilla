#!/bin/bash

# Setup script for self-hosted ACI integration with GenAI Vanilla Stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACI_DIR="$SCRIPT_DIR"

echo -e "${BLUE}🚀 Setting up Self-Hosted ACI Integration${NC}"
echo "================================================"

# Function to check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker found${NC}"
    
    # Check Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Git found${NC}"
    
    # Check if GenAI stack is running
    if ! docker ps | grep -q "genai-supabase-db"; then
        echo -e "${RED}❌ GenAI stack is not running. Please run ./start.sh first${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ GenAI stack is running${NC}"
}

# Function to clone ACI repository
clone_aci_repo() {
    echo -e "\n${YELLOW}Cloning ACI repository...${NC}"
    
    if [ -d "$ACI_DIR/aci-source" ]; then
        echo -e "${YELLOW}ACI repository already exists, updating...${NC}"
        cd "$ACI_DIR/aci-source"
        git pull
    else
        git clone https://github.com/aipotheosis-labs/aci.git "$ACI_DIR/aci-source"
    fi
    echo -e "${GREEN}✅ ACI repository ready${NC}"
}

# Function to prepare backend
prepare_backend() {
    echo -e "\n${YELLOW}Preparing ACI backend...${NC}"
    
    # Create backend directory
    mkdir -p "$ACI_DIR/aci-backend"
    
    # Copy backend files
    cp -r "$ACI_DIR/aci-source/backend/aci" "$ACI_DIR/aci-backend/"
    cp -r "$ACI_DIR/aci-source/backend/apps" "$ACI_DIR/aci-backend/"
    cp "$ACI_DIR/aci-source/backend/alembic.ini" "$ACI_DIR/aci-backend/"
    cp "$ACI_DIR/aci-source/backend/pyproject.toml" "$ACI_DIR/aci-backend/"
    
    # Create Dockerfile for backend
    cat > "$ACI_DIR/aci-backend/Dockerfile" << 'EOF'
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY pyproject.toml ./

# Install Python dependencies
RUN pip install --no-cache-dir uv && \
    uv pip install --system -r pyproject.toml

# Copy application code
COPY aci /app/aci
COPY apps /app/apps
COPY alembic.ini /app/

# Create Supabase auth adapter
RUN mkdir -p /app/aci/server/auth
COPY auth_adapter.py /app/aci/server/auth/

EXPOSE 8000

CMD ["uvicorn", "aci.server.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Create auth adapter for Supabase
    cat > "$ACI_DIR/aci-backend/auth_adapter.py" << 'EOF'
"""
Supabase Auth Adapter for ACI
Adapts Supabase authentication to work with ACI's auth system
"""

import os
import jwt
from typing import Optional, Dict, Any
from fastapi import HTTPException, Request
from supabase import create_client, Client

class SupabaseAuthAdapter:
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        self.jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
        self.client: Client = create_client(self.supabase_url, self.supabase_key)
    
    async def validate_token(self, token: str) -> Dict[str, Any]:
        """Validate Supabase JWT token"""
        try:
            # Decode and verify JWT
            payload = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=["HS256"],
                audience="authenticated"
            )
            
            # Get user details from Supabase
            user = self.client.auth.admin.get_user_by_id(payload["sub"])
            
            # Map Supabase user to ACI format
            return {
                "user_id": user.id,
                "email": user.email,
                "org_id": user.user_metadata.get("org_id", "default"),
                "metadata": user.user_metadata
            }
        except Exception as e:
            raise HTTPException(status_code=401, detail=str(e))
    
    async def get_current_user(self, request: Request) -> Optional[Dict[str, Any]]:
        """Extract and validate user from request"""
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return None
        
        token = auth_header.replace("Bearer ", "")
        return await self.validate_token(token)

# Export singleton instance
auth_adapter = SupabaseAuthAdapter()
EOF

    echo -e "${GREEN}✅ Backend prepared${NC}"
}

# Function to prepare frontend
prepare_frontend() {
    echo -e "\n${YELLOW}Preparing ACI frontend...${NC}"
    
    # Create frontend directory
    mkdir -p "$ACI_DIR/aci-frontend"
    
    # Copy frontend files
    cp -r "$ACI_DIR/aci-source/frontend/." "$ACI_DIR/aci-frontend/"
    
    # Create Dockerfile for frontend
    cat > "$ACI_DIR/aci-frontend/Dockerfile" << 'EOF'
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production image
FROM node:20-alpine

WORKDIR /app

# Copy built application
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./

# Install production dependencies
RUN npm ci --production

EXPOSE 3000

CMD ["npm", "start"]
EOF

    echo -e "${GREEN}✅ Frontend prepared${NC}"
}

# Function to prepare MCP servers
prepare_mcp() {
    echo -e "\n${YELLOW}Preparing MCP servers...${NC}"
    
    # Create MCP directory
    mkdir -p "$ACI_DIR/aci-mcp"
    
    # Clone aci-mcp repository
    if [ ! -d "$ACI_DIR/aci-mcp-source" ]; then
        git clone https://github.com/aipotheosis-labs/aci-mcp.git "$ACI_DIR/aci-mcp-source"
    fi
    
    # Copy MCP files
    cp -r "$ACI_DIR/aci-mcp-source/src" "$ACI_DIR/aci-mcp/"
    cp "$ACI_DIR/aci-mcp-source/pyproject.toml" "$ACI_DIR/aci-mcp/"
    
    # Create Dockerfile for MCP
    cat > "$ACI_DIR/aci-mcp/Dockerfile" << 'EOF'
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir uv && \
    uv pip install --system -e .

# Copy source code
COPY src /app/src

# Create wrapper for self-hosted backend
RUN echo '#!/usr/bin/env python' > /app/run_server.py && \
    echo 'import sys' >> /app/run_server.py && \
    echo 'from src.aci_mcp import main' >> /app/run_server.py && \
    echo 'if __name__ == "__main__":' >> /app/run_server.py && \
    echo '    main()' >> /app/run_server.py

EXPOSE 8100 8101

ENTRYPOINT ["python", "/app/run_server.py"]
EOF

    echo -e "${GREEN}✅ MCP servers prepared${NC}"
}

# Function to create database setup scripts
create_db_scripts() {
    echo -e "\n${YELLOW}Creating database setup scripts...${NC}"
    
    mkdir -p "$ACI_DIR/scripts"
    
    # Create database initialization script
    cat > "$ACI_DIR/scripts/init-aci-db.sql" << 'EOF'
-- Create ACI schema in Supabase
CREATE SCHEMA IF NOT EXISTS aci;

-- Set search path
SET search_path TO aci, public;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Grant permissions to app user
GRANT ALL ON SCHEMA aci TO app_user;
GRANT ALL ON ALL TABLES IN SCHEMA aci TO app_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA aci TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA aci GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA aci GRANT ALL ON SEQUENCES TO app_user;

-- Create initial tables will be handled by Alembic migrations
EOF

    # Create KMS key creation script for LocalStack
    cat > "$ACI_DIR/scripts/create-kms-key.sh" << 'EOF'
#!/bin/bash
echo "Creating KMS encryption key for ACI..."
awslocal kms create-key \
    --description "ACI encryption key" \
    --key-usage ENCRYPT_DECRYPT \
    --origin AWS_KMS \
    --key-spec SYMMETRIC_DEFAULT

awslocal kms create-alias \
    --alias-name alias/aci-encryption \
    --target-key-id arn:aws:kms:us-east-1:000000000000:key/aci-encryption

echo "KMS key created successfully"
EOF
    chmod +x "$ACI_DIR/scripts/create-kms-key.sh"
    
    echo -e "${GREEN}✅ Database scripts created${NC}"
}

# Function to update environment variables
update_env() {
    echo -e "\n${YELLOW}Updating environment variables...${NC}"
    
    ENV_FILE="$PROJECT_ROOT/.env"
    
    # Check if .env exists
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}❌ .env file not found${NC}"
        exit 1
    fi
    
    # Add ACI configuration to .env
    cat >> "$ENV_FILE" << 'EOF'

# ============================================
# ACI SELF-HOSTED CONFIGURATION
# ============================================

# ACI Backend Service
ACI_BACKEND_SOURCE=container
ACI_BACKEND_PORT=63026
ACI_BACKEND_SCALE=1

# ACI Frontend Portal
ACI_FRONTEND_SOURCE=container
ACI_FRONTEND_PORT=63027
ACI_FRONTEND_SCALE=1

# ACI MCP Servers
ACI_MCP_APPS_PORT=63028
ACI_MCP_APPS_SCALE=1
ACI_MCP_UNIFIED_PORT=63029
ACI_MCP_UNIFIED_SCALE=1
ACI_MCP_APPS=GITHUB,GITLAB,VERCEL,SUPABASE,CLOUDFLARE,DOCKER,SLACK,GOOGLE_CALENDAR,GMAIL

# LocalStack KMS
LOCALSTACK_PORT=63030
LOCALSTACK_SCALE=1

# ACI Configuration
ACI_API_KEY_SECRET=5ef74d594f5edf1f98219ddfeb79056cb9ab8198d11820791c407befc5075166
ACI_MIGRATOR_SCALE=0  # Set to 1 for initial database setup
EOF
    
    echo -e "${GREEN}✅ Environment variables updated${NC}"
}

# Function to initialize database
init_database() {
    echo -e "\n${YELLOW}Initializing ACI database...${NC}"
    
    # Run SQL script
    docker exec -i genai-supabase-db psql -U supabase_admin -d postgres < "$ACI_DIR/scripts/init-aci-db.sql"
    
    echo -e "${GREEN}✅ Database initialized${NC}"
}

# Main execution
main() {
    check_prerequisites
    clone_aci_repo
    prepare_backend
    prepare_frontend
    prepare_mcp
    create_db_scripts
    update_env
    init_database
    
    echo -e "\n${GREEN}✨ ACI setup complete!${NC}"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Run database migrations:"
    echo "   ${YELLOW}docker compose -f aci-integration/docker-compose.aci.yml run --rm aci-db-migrator${NC}"
    echo ""
    echo "2. Start ACI services:"
    echo "   ${YELLOW}docker compose -f docker-compose.yml -f aci-integration/docker-compose.aci.yml up -d${NC}"
    echo ""
    echo "3. Access ACI Portal:"
    echo "   ${YELLOW}http://localhost:63027${NC}"
    echo ""
    echo "4. Configure your first tool integration"
    echo ""
    echo -e "${GREEN}Happy tool-calling! 🚀${NC}"
}

# Run main function
main "$@"
