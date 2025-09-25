#!/bin/bash

# Setup script for both Azure VMs after deployment
# Configures GPU VM and Core VM with all services

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

# Check if .env.azure.prod exists
if [ ! -f ".env.azure.prod" ]; then
    echo -e "${RED}Error: .env.azure.prod not found. Run azure-prod-deployment.sh first.${NC}"
    exit 1
fi

# Source the environment
source .env.azure.prod

print_header "🚀 Setting up Azure VMs for Production"

# =============================================================================
# GPU VM SETUP
# =============================================================================

setup_gpu_vm() {
    print_header "Setting up GPU VM: $AZURE_GPU_VM_NAME"
    
    echo -e "${YELLOW}Connecting to GPU VM at $AZURE_GPU_VM_IP...${NC}"
    
    # Copy necessary files
    echo -e "${YELLOW}Copying configuration files...${NC}"
    scp .env.azure.prod $AZURE_SSH_USER@$AZURE_GPU_VM_IP:/tmp/
    scp -r azure-deployment/gpu-vm-setup $AZURE_SSH_USER@$AZURE_GPU_VM_IP:/tmp/
    
    # Run setup on GPU VM
    ssh $AZURE_SSH_USER@$AZURE_GPU_VM_IP << 'ENDSSH'
#!/bin/bash
set -e

echo "📦 Installing Docker and NVIDIA drivers..."

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install NVIDIA drivers and container toolkit
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers autoinstall

# NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Mount data disk
if [ -e /dev/sdc ]; then
    sudo mkfs -t ext4 /dev/sdc 2>/dev/null || true
    sudo mkdir -p /data
    sudo mount /dev/sdc /data 2>/dev/null || true
    echo '/dev/sdc /data ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab
    sudo chown -R $USER:$USER /data
fi

# Create directories
mkdir -p ~/genai
mkdir -p /data/{models,ollama,comfyui,weaviate,research}

# Clone repository
cd ~/genai
git clone https://github.com/yourusername/genai-vanilla.git . 2>/dev/null || git pull

# Copy environment
cp /tmp/.env.azure.prod .env

# Create GPU services compose file
cat > docker-compose.gpu.yml << 'EOF'
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: genai-ollama
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    volumes:
      - /data/ollama:/root/.ollama
      - ./models:/models
    ports:
      - "11434:11434"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  comfyui:
    image: ghcr.io/ai-dock/comfyui:v2-cuda-12.1.0-base-22.04
    container_name: genai-comfyui
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - WORKSPACE=/workspace
      - COMFYUI_ARGS=--listen 0.0.0.0 --port 8188
    volumes:
      - /data/comfyui:/workspace
      - /data/models:/workspace/ComfyUI/models
    ports:
      - "63018:8188"
      - "7222:22"  # SSH for debugging
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  weaviate:
    image: cr.weaviate.io/semitechnologies/weaviate:latest
    container_name: genai-weaviate
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - ENABLE_CUDA=1
      - QUERY_DEFAULTS_LIMIT=25
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=true
      - PERSISTENCE_DATA_PATH=/var/lib/weaviate
      - DEFAULT_VECTORIZER_MODULE=text2vec-transformers
      - ENABLE_MODULES=text2vec-transformers,text2vec-openai,generative-openai
      - TRANSFORMERS_INFERENCE_API=http://t2v-transformers:8080
      - OPENAI_APIKEY=${AZURE_OPENAI_KEY}
      - OPENAI_BASEURL=${AZURE_OPENAI_ENDPOINT}
    volumes:
      - /data/weaviate:/var/lib/weaviate
    ports:
      - "63019:8080"
      - "50051:50051"
    restart: unless-stopped
    depends_on:
      - t2v-transformers

  t2v-transformers:
    image: semitechnologies/transformers-inference:sentence-transformers-multi-qa-MiniLM-L6-cos-v1
    container_name: genai-t2v
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - ENABLE_CUDA=1
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  deep-researcher:
    build:
      context: ./local-deep-researcher
      dockerfile: Dockerfile
    container_name: genai-researcher
    environment:
      - LLM_PROVIDER_BASE_URL=http://ollama:11434
      - SEARXNG_URL=${SEARXNG_URL}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - USE_GPU=true
    volumes:
      - /data/research:/app/research
      - ./local-deep-researcher/config:/app/config
    ports:
      - "63013:8000"
    restart: unless-stopped
    depends_on:
      - ollama

networks:
  default:
    name: genai-network
    driver: bridge
EOF

echo "🚀 Starting GPU services..."
docker-compose -f docker-compose.gpu.yml up -d

echo "📥 Pulling essential models..."
docker exec genai-ollama ollama pull llama3.2:latest
docker exec genai-ollama ollama pull qwen2.5:7b-instruct-q4_K_M
docker exec genai-ollama ollama pull nomic-embed-text

echo "✅ GPU VM setup complete!"
ENDSSH

    echo -e "${GREEN}✓ GPU VM configured successfully${NC}"
}

# =============================================================================
# CORE VM SETUP
# =============================================================================

setup_core_vm() {
    print_header "Setting up Core VM: $AZURE_CORE_VM_NAME"
    
    echo -e "${YELLOW}Connecting to Core VM at $AZURE_CORE_VM_IP...${NC}"
    
    # Copy necessary files
    echo -e "${YELLOW}Copying configuration files...${NC}"
    scp .env.azure.prod $AZURE_SSH_USER@$AZURE_CORE_VM_IP:/tmp/
    scp -r azure-deployment/core-vm-setup $AZURE_SSH_USER@$AZURE_CORE_VM_IP:/tmp/
    
    # Run setup on Core VM
    ssh $AZURE_SSH_USER@$AZURE_CORE_VM_IP << 'ENDSSH'
#!/bin/bash
set -e

echo "📦 Installing Docker..."

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install additional tools
sudo apt-get install -y git curl wget jq postgresql-client redis-tools

# Mount data disk
if [ -e /dev/sdc ]; then
    sudo mkfs -t ext4 /dev/sdc 2>/dev/null || true
    sudo mkdir -p /data
    sudo mount /dev/sdc /data 2>/dev/null || true
    echo '/dev/sdc /data ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab
    sudo chown -R $USER:$USER /data
fi

# Create directories
mkdir -p ~/genai
mkdir -p /data/{uploads,backups,logs}

# Clone repository
cd ~/genai
git clone https://github.com/yourusername/genai-vanilla.git . 2>/dev/null || git pull

# Copy environment
cp /tmp/.env.azure.prod .env

# Create core services compose file
cat > docker-compose.core.yml << 'EOF'
version: '3.8'

services:
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
      - OLLAMA_ENDPOINT=${OLLAMA_ENDPOINT}
      - WEAVIATE_ENDPOINT=${WEAVIATE_ENDPOINT}
      - COMFYUI_ENDPOINT=${COMFYUI_URL}
    volumes:
      - ./backend/app:/app
      - /data/uploads:/app/uploads
    ports:
      - "63016:8000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: genai-open-webui
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - OPENAI_API_BASE_URL=${AZURE_OPENAI_ENDPOINT}
      - OPENAI_API_KEY=${AZURE_OPENAI_KEY}
      - OLLAMA_BASE_URL=${OLLAMA_ENDPOINT}
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)}
      - ENABLE_OAUTH_SIGNUP=true
    volumes:
      - open-webui-data:/app/backend/data
      - ./open-webui/tools:/app/backend/data/tools
      - ./open-webui/functions:/app/backend/data/functions
    ports:
      - "63015:8080"
    restart: unless-stopped

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
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://${AZURE_CORE_VM_IP}:63017
    volumes:
      - n8n-data:/home/node/.n8n
      - ./n8n/workflows:/home/node/workflows
    ports:
      - "63017:5678"
    restart: unless-stopped

  searxng:
    image: searxng/searxng:latest
    container_name: genai-searxng
    environment:
      - SEARXNG_BASE_URL=http://${AZURE_CORE_VM_IP}:63014/
      - SEARXNG_SECRET_KEY=${SEARXNG_SECRET_KEY:-$(openssl rand -hex 32)}
    volumes:
      - ./searxng/config:/etc/searxng
    ports:
      - "63014:8080"
    restart: unless-stopped

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
      - SERVER_REDIRECT_URI_BASE=http://${AZURE_CORE_VM_IP}:63027
      - COMMON_AWS_ENDPOINT_URL=http://localhost:4566
    ports:
      - "63026:8000"
    restart: unless-stopped
    depends_on:
      - localstack

  aci-frontend:
    build:
      context: ./aci-integration/aci-opensource/frontend
      dockerfile: Dockerfile
    container_name: genai-aci-frontend
    environment:
      - NEXT_PUBLIC_BACKEND_URL=http://${AZURE_CORE_VM_IP}:63026
    ports:
      - "63027:3000"
    restart: unless-stopped
    depends_on:
      - aci-backend

  localstack:
    image: localstack/localstack:latest
    container_name: genai-localstack
    environment:
      - SERVICES=kms
      - DEBUG=0
    ports:
      - "4566:4566"
    restart: unless-stopped

volumes:
  open-webui-data:
  n8n-data:

networks:
  default:
    name: genai-network
    driver: bridge
EOF

echo "🚀 Starting core services..."
docker-compose -f docker-compose.core.yml up -d

echo "✅ Core VM setup complete!"
ENDSSH

    echo -e "${GREEN}✓ Core VM configured successfully${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "🔧 Azure VM Setup Process"
    
    echo -e "${YELLOW}This will configure both VMs with all necessary services.${NC}"
    echo -e "${YELLOW}Make sure you have SSH access to both VMs.${NC}"
    echo ""
    
    # Setup VMs
    setup_gpu_vm
    setup_core_vm
    
    # Create health check script
    cat > azure-deployment/check-production.sh << 'EOF'
#!/bin/bash

# Health check for production deployment

source .env.azure.prod

echo "🔍 Checking Production Services..."
echo "=================================="

# Core services
echo -n "Open-WebUI: "
curl -s -o /dev/null -w "%{http_code}" http://$AZURE_CORE_VM_IP:63015 || echo "Down"

echo -n "n8n: "
curl -s -o /dev/null -w "%{http_code}" http://$AZURE_CORE_VM_IP:63017 || echo "Down"

echo -n "Backend API: "
curl -s -o /dev/null -w "%{http_code}" http://$AZURE_CORE_VM_IP:63016/health || echo "Down"

echo -n "SearxNG: "
curl -s -o /dev/null -w "%{http_code}" http://$AZURE_CORE_VM_IP:63014 || echo "Down"

# GPU services
echo -n "ComfyUI: "
curl -s -o /dev/null -w "%{http_code}" http://$AZURE_GPU_VM_IP:63018 || echo "Down"

echo -n "Ollama: "
curl -s http://$AZURE_GPU_VM_IP:11434/api/tags | jq -r '.models[0].name' 2>/dev/null || echo "No models"

echo -n "Weaviate: "
curl -s http://$AZURE_GPU_VM_IP:63019/v1/schema | jq '.classes | length' 2>/dev/null || echo "Down"

echo ""
echo "✅ Health check complete"
EOF
    chmod +x azure-deployment/check-production.sh
    
    print_header "✅ VM Setup Complete!"
    
    echo -e "\n${GREEN}All services have been deployed!${NC}"
    echo -e "\n${YELLOW}Service URLs:${NC}"
    echo "• Open-WebUI: http://$AZURE_CORE_VM_IP:63015"
    echo "• n8n: http://$AZURE_CORE_VM_IP:63017"
    echo "• Backend API: http://$AZURE_CORE_VM_IP:63016/docs"
    echo "• ComfyUI: http://$AZURE_GPU_VM_IP:63018"
    echo "• ACI Portal: http://$AZURE_CORE_VM_IP:63027"
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Run: ./azure-deployment/check-production.sh"
    echo "2. Set up dev/prod sync: ./azure-deployment/setup-sync.sh"
    echo "3. Configure monitoring"
}

main "$@"
