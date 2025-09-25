# MCP Integration Implementation Guide

## Quick Start

This directory contains the implementation files for integrating MCP (Model Context Protocol) servers into the GenAI Vanilla Stack.

## Directory Structure

```
mcp-integration/
├── README.md                  # This file
├── docker/
│   ├── aci-mcp.dockerfile    # ACI MCP server wrapper
│   └── openwebui-mcp.dockerfile
├── config/
│   ├── aci-config.json       # ACI MCP configuration
│   └── mcp-routes.yml        # Kong routing config
├── backend/
│   ├── aci_mcp_client.py     # ACI MCP client
│   └── mcp_router.py         # MCP routing service
├── open-webui/
│   ├── functions/
│   │   └── mcp_bridge.py     # Open WebUI MCP bridge
│   └── tools/
│       └── aci_tool.py       # ACI tool wrapper
└── scripts/
    ├── setup.sh              # Setup script
    └── test_integration.py   # Integration tests
```

## Setup Instructions

### 1. Prerequisites

- ACI.dev account with API key
- Docker and Docker Compose installed
- Python 3.10+ for local development

### 2. Configuration

Create `.env.mcp` file:
```bash
# ACI.dev Configuration
ACI_API_KEY=your_aci_api_key_here
ACI_LINKED_ACCOUNT_ID=default_user
ACI_ENABLED_APPS=GITHUB,GMAIL,BRAVE_SEARCH,SLACK,DISCORD

# MCP Server Configuration
MCP_TRANSPORT=sse
MCP_BASE_PORT=63022
ACI_MCP_SCALE=1
OPEN_WEBUI_MCP_SCALE=1

# Feature Flags
ENABLE_MCP_DISCOVERY=true
ENABLE_MCP_CACHING=true
MCP_CACHE_TTL=300
```

### 3. Installation

Run the setup script:
```bash
cd mcp-integration
chmod +x scripts/setup.sh
./scripts/setup.sh
```

## Implementation Components

### ACI MCP Client (Backend)

The ACI MCP client provides a Python interface to interact with ACI.dev MCP servers:

```python
from backend.aci_mcp_client import ACIMCPClient

# Initialize client
client = ACIMCPClient()

# Search for tools
tools = await client.search_functions("send email")

# Execute a function
result = await client.execute_function(
    "GMAIL__SEND_EMAIL",
    {
        "to": "user@example.com",
        "subject": "Test",
        "body": "Hello from MCP!"
    }
)
```

### Open WebUI Integration

The MCP Bridge function allows Open WebUI to access MCP tools:

```python
# Automatically loaded when placed in open-webui/functions/
# Provides dynamic tool discovery and execution
# Accessible as "MCP Bridge 🌉" in model selection
```

### Docker Services

Add to your `docker-compose.yml`:

```yaml
include:
  - path: ./mcp-integration/docker/docker-compose.mcp.yml
```

## Usage Examples

### 1. In Open WebUI

Select "MCP Bridge 🌉" as your model and ask:
- "Search GitHub for repositories about machine learning"
- "Send an email to team@company.com about the meeting"
- "Find the latest news about AI"

### 2. Via Backend API

```python
# backend/app/main.py
from mcp_integration.backend.aci_mcp_client import ACIMCPClient

@app.post("/api/mcp/search")
async def search_tools(query: str):
    client = ACIMCPClient()
    return await client.search_functions(query)

@app.post("/api/mcp/execute")
async def execute_tool(tool_name: str, arguments: dict):
    client = ACIMCPClient()
    return await client.execute_function(tool_name, arguments)
```

### 3. In n8n Workflows

Use the HTTP Request node to call MCP endpoints:
```json
{
  "method": "POST",
  "url": "http://kong:8000/mcp/unified/search",
  "body": {
    "intent": "find GitHub issues",
    "limit": 10
  }
}
```

## Testing

Run integration tests:
```bash
python scripts/test_integration.py
```

Check service health:
```bash
curl http://localhost:63022/health  # ACI MCP
curl http://localhost:63024/health  # Open WebUI MCP
```

## Troubleshooting

### Common Issues

1. **"ACI API key not found"**
   - Ensure ACI_API_KEY is set in .env.mcp
   - Check if .env.mcp is loaded: `source .env.mcp`

2. **"Cannot connect to MCP server"**
   - Verify services are running: `docker compose ps | grep mcp`
   - Check logs: `docker compose logs aci-mcp-gateway`

3. **"No tools found"**
   - Verify ACI_ENABLED_APPS includes desired apps
   - Check linked account setup on platform.aci.dev

### Debug Mode

Enable debug logging:
```bash
export MCP_DEBUG=true
docker compose up -d aci-mcp-gateway
```

## API Reference

### ACI MCP Endpoints

- `GET /mcp/v1/tools` - List available tools
- `POST /mcp/v1/tools/call` - Execute a tool
- `GET /mcp/v1/health` - Health check

### Tool Naming Convention

ACI tools follow the format: `APP_NAME__FUNCTION_NAME`

Examples:
- `GITHUB__CREATE_ISSUE`
- `GMAIL__SEND_EMAIL`
- `SLACK__POST_MESSAGE`

## Contributing

To add new MCP integrations:

1. Create client in `backend/`
2. Add Docker service configuration
3. Update Kong routes in `config/`
4. Add tests in `scripts/`
5. Document in this README

## Resources

- [ACI.dev Platform](https://platform.aci.dev)
- [ACI MCP Documentation](https://www.aci.dev/docs/mcp-servers/introduction)
- [MCP Specification](https://modelcontextprotocol.io)
- [Open WebUI Functions](https://docs.openwebui.com/tutorial/functions)

## License

This integration follows the GenAI Vanilla Stack MIT license.
