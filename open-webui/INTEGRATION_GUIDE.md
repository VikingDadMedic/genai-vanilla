# Open-WebUI Integration Guide

## Overview

Open-WebUI can be extended with **Tools** and **Pipes (Functions)** to integrate with other services in the GenAI stack.

## Current Integration Status

| Integration Type | Status | Setup Required |
|-----------------|--------|----------------|
| **Deep Researcher (Tool)** | ✅ Available | Manual import |
| **Deep Researcher (Pipe)** | ✅ Available | Restart container |
| **ComfyUI (Tool)** | ✅ Available | Manual import |
| **n8n Webhooks (Tool)** | ✅ Available | Manual import + n8n setup |
| **n8n Workflows** | ⚠️ Partial | n8n workflow configuration |

## 🔧 Setup Instructions

### 1. Enable Pipes/Functions

Pipes are automatically loaded from the `functions/` directory when Open-WebUI starts.

```bash
# Restart Open-WebUI to load new pipes
docker compose restart open-web-ui

# Check logs to confirm loading
docker logs genai-open-web-ui | grep -i "pipe"
```

### 2. Import Tools

Tools must be manually imported through the Open-WebUI interface:

1. **Access Open-WebUI**: http://localhost:63015
2. **Login** with your admin account
3. **Navigate to**: Admin Panel → Tools
4. **Import each tool**:
   - Click "+" to add new tool
   - Copy the entire content of the tool file
   - Paste into the editor
   - Click "Save"

### 3. Configure n8n Workflows

For n8n integration to work, you need to:

1. **Setup n8n** (if not done):
   ```bash
   # Access n8n
   open http://localhost:63017
   
   # Create admin account
   # Import workflows from n8n/workflows/
   ```

2. **Create Required Webhooks**:
   - Research webhook: `/webhook/research`
   - ComfyUI webhook: `/webhook/comfyui-generate`
   - Batch research: `/webhook/batch-research`

3. **Test Connection**:
   - In Open-WebUI, use the n8n tool
   - Run: `check_n8n_status()`

## 📦 Available Integrations

### Deep Researcher Pipe (Function)

**Location**: `functions/deep_researcher_pipe.py`
**Type**: Pipe (appears as a model in dropdown)
**Features**:
- Real-time research with progress updates
- Automatic source citation
- Configurable research depth

**Usage**:
1. Select "Deep Researcher 🔍" from model dropdown
2. Type your research query
3. Watch real-time progress
4. Get formatted results with sources

### n8n Webhook Tool

**Location**: `tools/n8n_webhook_tool.py`
**Type**: Tool (AI-invoked or manual)
**Features**:
- Trigger n8n workflows
- Research automation
- ComfyUI image generation
- Workflow status checking

**Available Functions**:
- `trigger_research_workflow(query)` - Web research
- `trigger_comfyui_workflow(prompt, negative_prompt)` - Image generation
- `list_available_workflows()` - Show workflows
- `check_n8n_status()` - Test connection

### ComfyUI Image Generation Tool

**Location**: `tools/comfyui_image_generation_tool.py`
**Type**: Tool
**Features**:
- Direct ComfyUI integration
- Model selection
- Queue monitoring

### Research Tools

**Location**: `tools/research_tool.py`, `tools/research_streaming_tool.py`
**Type**: Tools
**Features**:
- Direct Deep Researcher integration
- Streaming updates
- Configurable search depth

## 🔄 How Services Connect

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│ Open-WebUI  │─────►│   Backend    │─────►│   Services  │
│             │      │   API        │      │  (Research, │
│   - Tools   │      │  /research/* │      │   ComfyUI)  │
│   - Pipes   │      │  /comfyui/*  │      └─────────────┘
└─────────────┘      └──────────────┘
       │                     
       │ Webhooks            
       ▼                     
┌─────────────┐             
│    n8n      │             
│  Workflows  │             
└─────────────┘             
```

## ⚙️ Configuration

### Pipe Configuration (Valves)

Access via: Admin Panel → Functions → [Pipe Name] → Settings

**Deep Researcher Pipe**:
- `backend_url`: Backend service URL (default: http://backend:8000)
- `timeout`: Max research time (default: 300s)
- `max_loops`: Research depth (default: 3)
- `show_status`: Progress updates (default: true)

### Tool Configuration

Access via: Admin Panel → Tools → [Tool Name] → Settings

**n8n Webhook Tool**:
- `n8n_url`: Internal URL (default: http://n8n:5678)
- `n8n_external_url`: External URL (default: http://localhost:63017)
- `timeout`: Request timeout (default: 60s)

## 🚨 Troubleshooting

### Pipes Not Loading

```bash
# Check if files are mounted
docker exec genai-open-web-ui ls -la /app/backend/data/functions/

# Check logs for errors
docker logs genai-open-web-ui | grep -i "error"

# Restart to reload
docker compose restart open-web-ui
```

### Tools Not Working

1. **Import Issues**:
   - Ensure Python syntax is valid
   - Check for missing dependencies
   - Verify tool metadata format

2. **Connection Issues**:
   - Test backend connectivity
   - Verify service URLs
   - Check network connectivity

### n8n Integration Issues

1. **Webhook Not Found**:
   - Import workflows to n8n
   - Activate workflows
   - Check webhook paths

2. **Connection Refused**:
   - Verify n8n is running
   - Check URL configuration
   - Test with `check_n8n_status()`

## 📈 Testing Integrations

### Test Deep Researcher

```python
# In Open-WebUI chat
# Select "Deep Researcher 🔍" model
"What are the latest developments in quantum computing?"
```

### Test n8n Connection

```python
# With n8n tool enabled
check_n8n_status()
list_available_workflows()
```

### Test Research Workflow

```python
# With n8n tool and workflows configured
trigger_research_workflow("artificial intelligence trends 2024")
```

## 🎯 Next Steps

1. **Complete n8n Setup**:
   - Create account at http://localhost:63017
   - Import workflows from `n8n/workflows/`
   - Configure database credentials

2. **Import All Tools**:
   - Import each tool file via Admin Panel
   - Configure tool settings
   - Enable for AI models

3. **Test Integrations**:
   - Try Deep Researcher for web research
   - Test n8n workflow triggers
   - Verify ComfyUI image generation

4. **Create Custom Integrations**:
   - Build custom tools for your needs
   - Create n8n workflows
   - Extend pipe functionality

## 📚 Resources

- [Open-WebUI Docs](https://docs.openwebui.com/)
- [n8n Workflow Docs](https://docs.n8n.io/)
- [Tool Development Guide](https://docs.openwebui.com/tutorial/tools/)
- [Pipe Development Guide](https://docs.openwebui.com/tutorial/functions/)

---

**Note**: After adding new pipes/functions, always restart Open-WebUI to ensure they're loaded properly.
