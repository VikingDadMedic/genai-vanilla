# 🏠 Self-Hosted ACI Integration

## Overview

This directory contains the **self-hosted open-source ACI platform** integration for the GenAI Vanilla Stack, providing access to **600+ tool integrations** without any external dependencies or API keys.

## 🎯 What's Included

### Core Components
- **ACI Backend** - FastAPI server managing tool execution
- **ACI Frontend** - Next.js portal for tool management  
- **ACI Database** - PostgreSQL schema in Supabase
- **MCP Servers** - Apps and Unified servers for tool access
- **LocalStack KMS** - Encryption for credentials
- **Open WebUI Bridge** - Integration with chat interface

### Key Features
- ✅ **100% Self-Hosted** - No external API dependencies
- ✅ **600+ Pre-built Tools** - GitHub, Vercel, Supabase, Slack, and more
- ✅ **Supabase Integration** - Uses existing auth and database
- ✅ **MCP Support** - Compatible with Claude and other MCP clients
- ✅ **Secure Credentials** - Encrypted storage with KMS
- ✅ **Multi-tenant** - Support for multiple users and organizations

## 🚀 Quick Start

### Prerequisites
- GenAI Vanilla Stack running (`./start.sh`)
- Docker and Docker Compose installed
- Git installed

### Installation

1. **Run the setup script:**
```bash
cd aci-integration
./setup-aci.sh
```

This will:
- Clone the ACI repository
- Prepare backend and frontend
- Configure database
- Set up MCP servers
- Update environment variables

2. **Run database migrations:**
```bash
docker compose -f docker-compose.aci.yml run --rm aci-db-migrator
```

3. **Start ACI services:**
```bash
docker compose -f docker-compose.yml -f aci-integration/docker-compose.aci.yml up -d
```

4. **Verify services are running:**
```bash
docker compose ps | grep aci
```

## 🌐 Access Points

| Service | URL | Description |
|---------|-----|-------------|
| ACI Backend API | http://localhost:63026 | Tool execution API |
| ACI Frontend Portal | http://localhost:63027 | Management interface |
| MCP Apps Server | http://localhost:63028 | Direct tool access |
| MCP Unified Server | http://localhost:63029 | Dynamic discovery |
| LocalStack KMS | http://localhost:63030 | Encryption service |

## 🔧 Configuration

### Environment Variables
All ACI configuration is in your `.env` file:

```env
# ACI Backend
ACI_BACKEND_PORT=63026
ACI_BACKEND_SCALE=1

# ACI Frontend  
ACI_FRONTEND_PORT=63027
ACI_FRONTEND_SCALE=1

# MCP Servers
ACI_MCP_APPS_PORT=63028
ACI_MCP_UNIFIED_PORT=63029
ACI_MCP_APPS=GITHUB,GITLAB,VERCEL,SUPABASE,CLOUDFLARE,DOCKER

# Database (uses existing Supabase)
# Automatically configured
```

### Priority Tools
Configure which tools to load by default:
```env
ACI_MCP_APPS=GITHUB,GITLAB,VERCEL,SUPABASE,CLOUDFLARE,DOCKER,SLACK,GOOGLE_CALENDAR
```

## 🔌 Open WebUI Integration

The ACI Self-Hosted Bridge is automatically available in Open WebUI:

1. Go to Open WebUI (http://localhost:63015)
2. Navigate to Workspace → Functions
3. Find "ACI Self-Hosted Bridge 🏠"
4. Enable the function
5. Start using 600+ tools in your chats!

### Example Commands
- "Search GitHub for repositories about AI"
- "Create a new Vercel deployment"
- "List my Supabase tables"
- "Send a Slack message to #general"

## 🛠️ Tool Configuration

### Adding OAuth Credentials

1. **Access ACI Portal:**
   ```
   http://localhost:63027
   ```

2. **Navigate to Apps**

3. **Select an app (e.g., GitHub)**

4. **Add OAuth credentials:**
   - Client ID
   - Client Secret
   - Redirect URI: `http://localhost:63026/oauth/callback`

5. **Save and test**

### Creating API Keys

Some tools use API keys instead of OAuth:

1. Go to the app's configuration
2. Select "API Key" authentication
3. Enter your API key
4. Test the connection

## 📁 Directory Structure

```
aci-integration/
├── README.md                 # This file
├── ACI_INTEGRATION_PLAN.md   # Detailed integration plan
├── docker-compose.aci.yml    # Docker services
├── setup-aci.sh              # Setup script
├── aci-backend/              # Backend service
│   ├── Dockerfile
│   ├── aci/                 # Core application
│   ├── apps/                # Tool definitions
│   └── auth_adapter.py      # Supabase auth adapter
├── aci-frontend/             # Frontend portal
│   ├── Dockerfile
│   └── [Next.js files]
├── aci-mcp/                  # MCP servers
│   ├── Dockerfile
│   └── src/
└── scripts/                  # Setup scripts
    ├── init-aci-db.sql
    └── create-kms-key.sh
```

## 🔍 Available Tools

### Development & DevOps
- **GitHub** - Repository management
- **GitLab** - Alternative Git platform
- **Vercel** - Deployment platform
- **Netlify** - Static site hosting
- **Render** - Cloud platform
- **Docker** - Container management
- **Cloudflare** - CDN and DNS

### Databases & Backend
- **Supabase** - Database and auth
- **Neon** - Serverless Postgres
- **MongoDB** - NoSQL database
- **Redis** - Caching

### Communication
- **Slack** - Team chat
- **Discord** - Community chat
- **Gmail** - Email
- **SendGrid** - Email API
- **Twilio** - SMS/Voice

### Productivity
- **Google Calendar** - Scheduling
- **Google Docs** - Documents
- **Google Sheets** - Spreadsheets
- **Notion** - Knowledge base
- **Airtable** - Database/spreadsheet hybrid

### AI & ML
- **OpenAI** - GPT models
- **Anthropic** - Claude models
- **Replicate** - ML models
- **Hugging Face** - Model hub

### Monitoring & Analytics
- **Sentry** - Error tracking
- **PostHog** - Product analytics
- **Google Analytics** - Web analytics

And 550+ more tools!

## 🧪 Testing

### Test Tool Discovery
```bash
curl http://localhost:63026/v1/apps
```

### Test Tool Search
```bash
curl -X POST http://localhost:63026/v1/functions/search \
  -H "Content-Type: application/json" \
  -d '{"query": "github repository"}'
```

### Test MCP Server
```bash
curl http://localhost:63028/health
```

## 🐛 Troubleshooting

### Services not starting
```bash
# Check logs
docker compose logs aci-backend
docker compose logs aci-frontend

# Restart services
docker compose restart aci-backend aci-frontend
```

### Database connection issues
```bash
# Check Supabase is running
docker compose ps supabase-db

# Re-run migrations
docker compose -f docker-compose.aci.yml run --rm aci-db-migrator
```

### Authentication errors
- Ensure Supabase keys are set in `.env`
- Check JWT secret matches Supabase
- Verify auth adapter is loaded

### Tool execution failures
- Check tool credentials are configured
- Verify network connectivity
- Review backend logs for errors

## 🔄 Updating

To update ACI to the latest version:

```bash
cd aci-integration
git -C aci-source pull
./setup-aci.sh
docker compose -f docker-compose.aci.yml build --no-cache
docker compose -f docker-compose.aci.yml up -d
```

## 🤝 Contributing

To add custom tools:

1. Create tool definition in `aci-backend/apps/`
2. Add app.json and functions.json
3. Rebuild backend
4. Configure in portal

## 📚 Resources

- [ACI Documentation](https://aci.dev/docs)
- [MCP Protocol Spec](https://modelcontextprotocol.io)
- [Tool Catalog](https://aci.dev/tools)
- [GenAI Stack Docs](../README.md)

## 🎉 Success!

You now have a fully self-hosted ACI platform with 600+ tools available for your AI agents, completely independent of external services!

Access the portal at http://localhost:63027 to start configuring your tools.
