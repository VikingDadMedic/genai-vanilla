#!/bin/bash

echo "🔧 Fixing Deep Researcher Setup..."

# Check current LLM provider
LLM_SOURCE=$(grep "^LLM_PROVIDER_SOURCE=" .env | cut -d'=' -f2)
echo "Current LLM Provider: $LLM_SOURCE"

if [ "$LLM_SOURCE" = "api" ]; then
    echo "📦 You're using API mode. Deep Researcher needs Ollama for its own operations."
    echo ""
    echo "Choose an option:"
    echo "1) Run Ollama container alongside OpenAI (Recommended)"
    echo "2) Skip Deep Researcher setup"
    read -p "Enter choice (1 or 2): " choice
    
    if [ "$choice" = "1" ]; then
        echo "🚀 Enabling Ollama for Deep Researcher..."
        
        # Enable Ollama container
        sed -i.bak 's/OLLAMA_SCALE=0/OLLAMA_SCALE=1/' .env
        
        # Start Ollama
        docker compose up -d ollama
        
        # Wait for Ollama to be ready
        echo "⏳ Waiting for Ollama to start..."
        sleep 10
        
        # Pull the required model
        echo "📥 Pulling qwen3:latest model (this may take a few minutes)..."
        docker exec genai-ollama ollama pull qwen3:latest || {
            echo "⚠️  Failed to pull model. You may need to pull it manually:"
            echo "   docker exec genai-ollama ollama pull qwen3:latest"
        }
        
        # Restart Deep Researcher
        echo "🔄 Restarting Deep Researcher..."
        docker compose restart local-deep-researcher
        
        echo "✅ Deep Researcher should now be working!"
        
    else
        echo "⏸️  Skipping Deep Researcher setup."
        echo "   To disable it completely, run:"
        echo "   docker compose down local-deep-researcher"
        exit 0
    fi
else
    echo "✅ Ollama is already configured. Checking Deep Researcher..."
    docker compose restart local-deep-researcher
fi

# Wait a moment for services to start
echo "⏳ Waiting for services to initialize..."
sleep 20

# Check if Deep Researcher is running
echo ""
echo "🔍 Checking Deep Researcher status..."
if curl -s http://localhost:63013/docs > /dev/null 2>&1; then
    echo "✅ Deep Researcher API is accessible at http://localhost:63013/docs"
else
    echo "⚠️  Deep Researcher API not responding. Check logs with:"
    echo "   docker logs genai-local-deep-researcher"
fi

# Check if it's visible in Open-WebUI
echo ""
echo "📋 Next Steps:"
echo "1. Go to Open-WebUI: http://localhost:63015"
echo "2. Look for 'Deep Researcher 🔍' in the model dropdown"
echo "3. If not visible, try refreshing the page"
echo ""
echo "🎯 Test query: 'What are the latest AI breakthroughs in 2024?'"
echo ""
echo "📝 If Deep Researcher still doesn't appear:"
echo "   - Check logs: docker logs genai-open-web-ui | grep -i 'pipe'"
echo "   - Restart Open-WebUI: docker compose restart open-web-ui"
