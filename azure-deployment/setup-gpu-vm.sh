#!/bin/bash

# Setup script for GPU VM (NC8as_T4_v3)
# Runs AI workloads: Ollama, ComfyUI, Deep Researcher, Weaviate

set -e

echo "🚀 Setting up GPU VM for AI workloads..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Mount data disk
sudo mkfs -t ext4 /dev/sdc
sudo mkdir /data
sudo mount /dev/sdc /data
echo '/dev/sdc /data ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab

# Create directories
sudo mkdir -p /data/models
sudo mkdir -p /data/comfyui
sudo mkdir -p /data/research
sudo mkdir -p /data/weaviate
sudo mkdir -p /data/ollama
sudo chown -R $USER:$USER /data

# Clone GenAI stack
cd /home/$USER
git clone https://github.com/yourusername/genai-vanilla.git
cd genai-vanilla

# Copy Azure config
cp /tmp/.env.azure .env

# Create GPU-specific docker-compose
cat > docker-compose.gpu.yml << 'EOF'
version: '3.8'

services:
  # Ollama with GPU support
  ollama:
    image: ollama/ollama:latest
    container_name: genai-ollama
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    volumes:
      - /data/ollama:/root/.ollama
    ports:
      - "11434:11434"
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # ComfyUI with GPU
  comfyui:
    image: ghcr.io/ai-dock/comfyui:v2-cuda-12.1.0-base-22.04-v0.2.7
    container_name: genai-comfyui
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - COMFYUI_ARGS=--listen --port 18188
    volumes:
      - /data/comfyui/models:/opt/ComfyUI/models
      - /data/comfyui/output:/opt/ComfyUI/output
      - /data/comfyui/input:/opt/ComfyUI/input
    ports:
      - "63018:18188"
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # Weaviate with GPU vectorization
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
      - ENABLE_MODULES=text2vec-transformers,text2vec-openai
      - TRANSFORMERS_INFERENCE_API=http://t2v-transformers:8080
    volumes:
      - /data/weaviate:/var/lib/weaviate
    ports:
      - "63019:8080"
      - "63020:50051"
    restart: unless-stopped
    depends_on:
      - t2v-transformers
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # Transformers model for Weaviate
  t2v-transformers:
    image: semitechnologies/transformers-inference:sentence-transformers-multi-qa-MiniLM-L6-cos-v1
    container_name: genai-t2v-transformers
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

  # Deep Researcher (enhanced)
  local-deep-researcher:
    build: ./local-deep-researcher
    container_name: genai-deep-researcher
    environment:
      - LLM_PROVIDER_BASE_URL=http://ollama:11434
      - SEARXNG_URL=http://${CORE_VM_IP}:63014
      - USE_GPU=true
    volumes:
      - /data/research:/app/research
    ports:
      - "63013:8000"
    restart: unless-stopped
    depends_on:
      - ollama

networks:
  default:
    name: genai-gpu-network
    driver: bridge
EOF

# Download essential models for Ollama
echo "Downloading AI models..."
docker run --rm -v /data/ollama:/root/.ollama ollama/ollama pull llama3.2:latest
docker run --rm -v /data/ollama:/root/.ollama ollama/ollama pull nomic-embed-text
docker run --rm -v /data/ollama:/root/.ollama ollama/ollama pull qwen2.5:7b-instruct-q4_K_M

# Download ComfyUI models
echo "Downloading ComfyUI models..."
mkdir -p /data/comfyui/models/checkpoints
cd /data/comfyui/models/checkpoints
wget -c https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Start GPU services
cd /home/$USER/genai-vanilla
docker-compose -f docker-compose.gpu.yml up -d

# Setup health check script
cat > /home/$USER/check-gpu.sh << 'EOF'
#!/bin/bash
echo "🔍 GPU Status:"
nvidia-smi
echo ""
echo "🐳 Docker GPU Containers:"
docker ps --filter "label=com.nvidia.gpu=true"
echo ""
echo "📊 Service Health:"
curl -s http://localhost:11434/api/tags | jq '.models[].name' 2>/dev/null || echo "Ollama: Checking..."
curl -s http://localhost:63019/v1/schema | jq '.classes | length' 2>/dev/null || echo "Weaviate: Checking..."
EOF
chmod +x /home/$USER/check-gpu.sh

echo "✅ GPU VM setup complete!"
echo "Run './check-gpu.sh' to verify GPU services"
