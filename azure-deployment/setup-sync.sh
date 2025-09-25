#!/bin/bash

# Dev/Prod Sync Setup for GenAI Stack
# Syncs development (local Mac) with production (Azure)

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

# Check for environment file
if [ ! -f ".env.azure.sync" ]; then
    echo -e "${RED}Error: .env.azure.sync not found. Run azure-prod-deployment.sh first.${NC}"
    exit 1
fi

source .env.azure.sync
source .env.azure.prod

print_header "🔄 Setting up Dev/Prod Sync"

# =============================================================================
# INSTALL AZURE STORAGE TOOLS
# =============================================================================

install_tools() {
    print_header "Installing Azure Storage Tools"
    
    # Check if azcopy is installed
    if ! command -v azcopy &> /dev/null; then
        echo -e "${YELLOW}Installing azcopy...${NC}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            brew install azcopy 2>/dev/null || {
                curl -L https://aka.ms/downloadazcopy-v10-mac -o azcopy.tar.gz
                tar -xzf azcopy.tar.gz
                sudo mv azcopy_*/azcopy /usr/local/bin/
                rm -rf azcopy*
            }
        else
            # Linux
            wget https://aka.ms/downloadazcopy-v10-linux -O azcopy.tar.gz
            tar -xzf azcopy.tar.gz
            sudo mv azcopy_*/azcopy /usr/local/bin/
            rm -rf azcopy*
        fi
    fi
    echo -e "${GREEN}✓ azcopy installed${NC}"
    
    # Install fswatch for auto-sync (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v fswatch &> /dev/null; then
            echo -e "${YELLOW}Installing fswatch for auto-sync...${NC}"
            brew install fswatch
        fi
        echo -e "${GREEN}✓ fswatch installed${NC}"
    fi
}

# =============================================================================
# CREATE SYNC SCRIPTS
# =============================================================================

create_sync_scripts() {
    print_header "Creating Sync Scripts"
    
    # Create push script (dev to prod)
    cat > sync-to-prod.sh << 'EOF'
#!/bin/bash

# Sync local development to Azure production

source .env.azure.sync

echo "🚀 Syncing to production..."

# Directories to sync
SYNC_DIRS=(
    "open-webui/functions"
    "open-webui/tools"
    "n8n/workflows"
    "aci-integration/integrations"
    "custom-pages"
    "docs"
    "backend/app"
)

# Create SAS token for secure upload
END_DATE=$(date -u -d "1 day" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+1d '+%Y-%m-%dT%H:%MZ')
SAS_TOKEN=$(az storage container generate-sas \
    --account-name $SYNC_STORAGE_ACCOUNT \
    --account-key $SYNC_STORAGE_KEY \
    --name genai-sync \
    --permissions rwl \
    --expiry $END_DATE \
    --output tsv)

# Sync each directory
for DIR in "${SYNC_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        echo "Syncing $DIR..."
        azcopy sync "$DIR" "https://$SYNC_STORAGE_ACCOUNT.blob.core.windows.net/genai-sync/$DIR?$SAS_TOKEN" \
            --recursive \
            --delete-destination=true \
            --exclude-pattern="*.pyc;__pycache__;.git;.env*;node_modules;*.log"
    fi
done

echo "✅ Sync complete!"

# Trigger production reload
echo "🔄 Reloading production services..."
ssh $AZURE_SSH_USER@$AZURE_CORE_VM_IP "cd ~/genai && docker-compose -f docker-compose.core.yml restart backend open-webui n8n"
ssh $AZURE_SSH_USER@$AZURE_GPU_VM_IP "cd ~/genai && docker-compose -f docker-compose.gpu.yml restart deep-researcher"

echo "✅ Production services reloaded!"
EOF
    chmod +x sync-to-prod.sh
    
    # Create pull script (prod to dev)
    cat > sync-from-prod.sh << 'EOF'
#!/bin/bash

# Sync production data back to local development

source .env.azure.sync

echo "📥 Syncing from production..."

# Create SAS token
END_DATE=$(date -u -d "1 day" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+1d '+%Y-%m-%dT%H:%MZ')
SAS_TOKEN=$(az storage container generate-sas \
    --account-name $SYNC_STORAGE_ACCOUNT \
    --account-key $SYNC_STORAGE_KEY \
    --name research \
    --permissions rl \
    --expiry $END_DATE \
    --output tsv)

# Sync research data
echo "Downloading research data..."
azcopy sync "https://$SYNC_STORAGE_ACCOUNT.blob.core.windows.net/research?$SAS_TOKEN" "./research-prod" \
    --recursive

# Sync ComfyUI outputs
echo "Downloading ComfyUI outputs..."
azcopy sync "https://$SYNC_STORAGE_ACCOUNT.blob.core.windows.net/comfyui-outputs?$SAS_TOKEN" "./comfyui-outputs-prod" \
    --recursive

echo "✅ Download complete!"
EOF
    chmod +x sync-from-prod.sh
    
    # Create auto-sync watcher (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cat > watch-and-sync.sh << 'EOF'
#!/bin/bash

# Auto-sync development changes to production

source .env.azure.sync

echo "👁️ Watching for changes..."
echo "Press Ctrl+C to stop"

# Watch directories for changes
fswatch -o \
    open-webui/functions \
    open-webui/tools \
    n8n/workflows \
    aci-integration/integrations \
    custom-pages \
    backend/app | while read num
do
    echo "📝 Change detected, syncing..."
    ./sync-to-prod.sh
    echo "⏳ Waiting for more changes..."
done
EOF
        chmod +x watch-and-sync.sh
    fi
    
    echo -e "${GREEN}✓ Sync scripts created${NC}"
}

# =============================================================================
# CONFIGURE PRODUCTION VMS FOR SYNC
# =============================================================================

configure_production_sync() {
    print_header "Configuring Production VMs for Sync"
    
    # Configure Core VM
    echo -e "${YELLOW}Configuring Core VM...${NC}"
    ssh $AZURE_SSH_USER@$AZURE_CORE_VM_IP << ENDSSH
#!/bin/bash

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create sync directory
mkdir -p ~/genai-sync

# Create mount script
cat > ~/mount-azure-files.sh << 'EOFMOUNT'
#!/bin/bash

# Mount Azure Files share
sudo mkdir -p /mnt/genai-sync
sudo mount -t cifs //$SYNC_STORAGE_ACCOUNT.file.core.windows.net/$SYNC_FILE_SHARE /mnt/genai-sync \
    -o vers=3.0,username=$SYNC_STORAGE_ACCOUNT,password=$SYNC_STORAGE_KEY,dir_mode=0777,file_mode=0777,serverino

# Create symbolic links
ln -sf /mnt/genai-sync/open-webui ~/genai/open-webui
ln -sf /mnt/genai-sync/n8n ~/genai/n8n
ln -sf /mnt/genai-sync/docs ~/genai/docs
EOFMOUNT
chmod +x ~/mount-azure-files.sh

# Add to crontab for auto-mount on reboot
(crontab -l 2>/dev/null; echo "@reboot ~/mount-azure-files.sh") | crontab -

echo "✅ Core VM configured for sync"
ENDSSH
    
    # Configure GPU VM
    echo -e "${YELLOW}Configuring GPU VM...${NC}"
    ssh $AZURE_SSH_USER@$AZURE_GPU_VM_IP << ENDSSH
#!/bin/bash

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create sync directory
mkdir -p ~/genai-sync

# Create sync pull script
cat > ~/pull-updates.sh << 'EOFPULL'
#!/bin/bash

# Pull latest updates from Azure Storage
az storage blob download-batch \
    --account-name $SYNC_STORAGE_ACCOUNT \
    --account-key $SYNC_STORAGE_KEY \
    --source genai-sync \
    --destination ~/genai \
    --pattern "*.py;*.json;*.yaml;*.yml"

# Restart affected services
docker-compose -f docker-compose.gpu.yml restart deep-researcher
EOFPULL
chmod +x ~/pull-updates.sh

# Add to crontab for periodic sync (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/pull-updates.sh") | crontab -

echo "✅ GPU VM configured for sync"
ENDSSH
    
    echo -e "${GREEN}✓ Production VMs configured${NC}"
}

# =============================================================================
# CREATE GIT HOOKS FOR AUTO-SYNC
# =============================================================================

create_git_hooks() {
    print_header "Creating Git Hooks"
    
    # Create post-commit hook
    cat > .git/hooks/post-commit << 'EOF'
#!/bin/bash

# Auto-sync to production after commit

echo "🔄 Syncing to production after commit..."
./sync-to-prod.sh &
EOF
    chmod +x .git/hooks/post-commit
    
    # Create post-merge hook
    cat > .git/hooks/post-merge << 'EOF'
#!/bin/bash

# Auto-sync to production after pull

echo "🔄 Syncing to production after merge..."
./sync-to-prod.sh &
EOF
    chmod +x .git/hooks/post-merge
    
    echo -e "${GREEN}✓ Git hooks created${NC}"
}

# =============================================================================
# CREATE DEVELOPMENT ENVIRONMENT FILE
# =============================================================================

create_dev_env() {
    print_header "Creating Development Environment"
    
    cat > .env.dev << EOF
# ============================================
# LOCAL DEVELOPMENT CONFIGURATION
# ============================================

# Environment
ENVIRONMENT=development
PROJECT_NAME=genai-dev

# Local services (running on Mac)
DATABASE_URL=postgresql://postgres:password@localhost:5432/genaidb
REDIS_URL=redis://localhost:6379/0
OLLAMA_ENDPOINT=http://localhost:11434

# Production endpoints for testing
PROD_OPEN_WEBUI=$PROD_OPEN_WEBUI
PROD_N8N=$PROD_N8N
PROD_BACKEND=$PROD_BACKEND
PROD_COMFYUI=$PROD_COMFYUI

# Azure services (shared with prod)
AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_KEY=$AZURE_OPENAI_KEY
AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY

# Development flags
DEBUG=true
HOT_RELOAD=true
AUTO_SYNC=true
EOF
    
    echo -e "${GREEN}✓ Development environment created${NC}"
}

# =============================================================================
# CREATE SYNC DASHBOARD
# =============================================================================

create_sync_dashboard() {
    print_header "Creating Sync Dashboard"
    
    cat > custom-pages/sync-dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dev/Prod Sync Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .sync-status {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        .env-card {
            padding: 20px;
            border-radius: 10px;
            background: #f8f9fa;
        }
        .env-card h2 {
            color: #495057;
            margin-bottom: 15px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #dee2e6;
        }
        .status-indicator {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 5px;
        }
        .status-indicator.online { background: #28a745; }
        .status-indicator.offline { background: #dc3545; }
        .status-indicator.syncing { background: #ffc107; animation: pulse 1s infinite; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .sync-controls {
            display: flex;
            gap: 10px;
            margin-top: 20px;
        }
        button {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            background: #007bff;
            color: white;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.3s;
        }
        button:hover { background: #0056b3; }
        button.danger { background: #dc3545; }
        button.danger:hover { background: #c82333; }
        .log-viewer {
            margin-top: 30px;
            padding: 20px;
            background: #2d2d2d;
            color: #f8f9fa;
            border-radius: 10px;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 12px;
            max-height: 300px;
            overflow-y: auto;
        }
        .file-list {
            margin-top: 15px;
            max-height: 200px;
            overflow-y: auto;
        }
        .file-item {
            padding: 5px 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #f0f0f0;
        }
        .file-item:hover { background: #f8f9fa; }
        .file-modified { color: #28a745; }
        .file-deleted { color: #dc3545; text-decoration: line-through; }
        .file-new { color: #007bff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔄 Dev/Prod Sync Dashboard</h1>
        
        <div class="sync-status">
            <div class="env-card">
                <h2>📱 Local Development</h2>
                <div class="status-item">
                    <span>Environment</span>
                    <span><span class="status-indicator online"></span>MacOS</span>
                </div>
                <div class="status-item">
                    <span>Branch</span>
                    <span id="git-branch">main</span>
                </div>
                <div class="status-item">
                    <span>Last Commit</span>
                    <span id="last-commit">Loading...</span>
                </div>
                <div class="status-item">
                    <span>Changed Files</span>
                    <span id="changed-files">0</span>
                </div>
            </div>
            
            <div class="env-card">
                <h2>☁️ Azure Production</h2>
                <div class="status-item">
                    <span>Core VM</span>
                    <span id="core-vm-status"><span class="status-indicator online"></span>Online</span>
                </div>
                <div class="status-item">
                    <span>GPU VM</span>
                    <span id="gpu-vm-status"><span class="status-indicator online"></span>Online</span>
                </div>
                <div class="status-item">
                    <span>Last Sync</span>
                    <span id="last-sync">Never</span>
                </div>
                <div class="status-item">
                    <span>Sync Status</span>
                    <span id="sync-status"><span class="status-indicator offline"></span>Idle</span>
                </div>
            </div>
        </div>
        
        <div class="sync-controls">
            <button onclick="syncToProd()">🚀 Sync to Production</button>
            <button onclick="syncFromProd()">📥 Pull from Production</button>
            <button onclick="startAutoSync()">🔄 Start Auto-Sync</button>
            <button onclick="stopAutoSync()" class="danger">⏹ Stop Auto-Sync</button>
        </div>
        
        <div class="file-list" id="file-list">
            <h3>📁 Pending Changes</h3>
            <div id="pending-files"></div>
        </div>
        
        <div class="log-viewer" id="log-viewer">
            <div>🖥️ Sync Console</div>
            <div id="logs">Waiting for sync operations...</div>
        </div>
    </div>
    
    <script>
        let autoSyncInterval = null;
        let ws = null;
        
        // Initialize WebSocket for real-time updates
        function initWebSocket() {
            ws = new WebSocket('ws://localhost:8765');
            ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                updateStatus(data);
            };
        }
        
        function updateStatus(data) {
            if (data.gitBranch) document.getElementById('git-branch').textContent = data.gitBranch;
            if (data.lastCommit) document.getElementById('last-commit').textContent = data.lastCommit;
            if (data.changedFiles) document.getElementById('changed-files').textContent = data.changedFiles;
            if (data.lastSync) document.getElementById('last-sync').textContent = data.lastSync;
            if (data.logs) addLog(data.logs);
        }
        
        function addLog(message) {
            const logs = document.getElementById('logs');
            const timestamp = new Date().toLocaleTimeString();
            logs.innerHTML += `\n[${timestamp}] ${message}`;
            logs.scrollTop = logs.scrollHeight;
        }
        
        function syncToProd() {
            addLog('🚀 Starting sync to production...');
            fetch('/api/sync/to-prod', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    addLog(data.message);
                    document.getElementById('last-sync').textContent = new Date().toLocaleString();
                })
                .catch(err => addLog('❌ Sync failed: ' + err));
        }
        
        function syncFromProd() {
            addLog('📥 Pulling from production...');
            fetch('/api/sync/from-prod', { method: 'POST' })
                .then(response => response.json())
                .then(data => addLog(data.message))
                .catch(err => addLog('❌ Pull failed: ' + err));
        }
        
        function startAutoSync() {
            if (autoSyncInterval) return;
            addLog('🔄 Auto-sync started (every 5 minutes)');
            autoSyncInterval = setInterval(syncToProd, 300000);
            document.getElementById('sync-status').innerHTML = '<span class="status-indicator syncing"></span>Auto-Syncing';
        }
        
        function stopAutoSync() {
            if (autoSyncInterval) {
                clearInterval(autoSyncInterval);
                autoSyncInterval = null;
                addLog('⏹ Auto-sync stopped');
                document.getElementById('sync-status').innerHTML = '<span class="status-indicator offline"></span>Idle';
            }
        }
        
        // Check production status
        function checkProductionStatus() {
            fetch('/api/status/production')
                .then(response => response.json())
                .then(data => {
                    const coreStatus = data.coreVM ? 'online' : 'offline';
                    const gpuStatus = data.gpuVM ? 'online' : 'offline';
                    
                    document.getElementById('core-vm-status').innerHTML = 
                        `<span class="status-indicator ${coreStatus}"></span>${coreStatus === 'online' ? 'Online' : 'Offline'}`;
                    document.getElementById('gpu-vm-status').innerHTML = 
                        `<span class="status-indicator ${gpuStatus}"></span>${gpuStatus === 'online' ? 'Online' : 'Offline'}`;
                })
                .catch(err => console.error('Status check failed:', err));
        }
        
        // Initialize on load
        window.onload = () => {
            initWebSocket();
            checkProductionStatus();
            setInterval(checkProductionStatus, 30000); // Check every 30 seconds
        };
    </script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✓ Sync dashboard created${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "🚀 Dev/Prod Sync Setup"
    
    echo -e "${YELLOW}This will set up bidirectional sync between local development and Azure production.${NC}"
    echo ""
    
    # Run setup steps
    install_tools
    create_sync_scripts
    configure_production_sync
    create_git_hooks
    create_dev_env
    create_sync_dashboard
    
    print_header "✅ Sync Setup Complete!"
    
    echo -e "\n${GREEN}Sync tools installed:${NC}"
    echo "• sync-to-prod.sh - Push changes to production"
    echo "• sync-from-prod.sh - Pull data from production"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "• watch-and-sync.sh - Auto-sync on file changes"
    fi
    echo "• Git hooks for auto-sync on commit/merge"
    echo "• Sync dashboard at custom-pages/sync-dashboard.html"
    
    echo -e "\n${YELLOW}Quick start:${NC}"
    echo "1. Make changes locally"
    echo "2. Run: ./sync-to-prod.sh"
    echo "3. Or use auto-sync: ./watch-and-sync.sh"
    
    echo -e "\n${BLUE}Development workflow:${NC}"
    echo "1. Work locally on Mac with .env.dev"
    echo "2. Changes auto-sync to Azure on commit"
    echo "3. Production data syncs back on demand"
    echo "4. Monitor via sync dashboard"
}

main "$@"
