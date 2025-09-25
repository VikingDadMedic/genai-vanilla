# Self-Hosted ACI Integration for GenAI Vanilla Stack

## 🎯 Overview

This document outlines the integration of the open-source ACI platform (Agent Computer Infrastructure) into the GenAI Vanilla Stack, providing self-hosted access to 600+ tool integrations without external dependencies.

## 📊 Architecture Integration

### ACI Components to Integrate

1. **ACI Backend** (FastAPI)
   - Tool execution engine
   - OAuth management
   - API key management
   - Function discovery and search
   - Multi-tenant authentication

2. **ACI Frontend** (Next.js)
   - Tool management portal
   - Authentication configuration
   - Agent management
   - Usage analytics

3. **ACI Database** (PostgreSQL + pgvector)
   - Tool definitions
   - Authentication credentials
   - Usage tracking
   - Embeddings for semantic search

4. **MCP Servers** (aci-mcp)
   - Apps server for direct tool access
   - Unified server for dynamic discovery

## 🔧 Integration Strategy

### Phase 1: Infrastructure Setup

#### Database Integration
- **Use existing Supabase PostgreSQL** instead of separate DB
- Enable pgvector extension in Supabase
- Run ACI migrations in separate schema (`aci`)
- Share authentication with existing Supabase auth

#### Service Configuration
```yaml
Services to Add:
- aci-backend (port 63026)
- aci-frontend (port 63027)
- aci-mcp-apps (port 63028)
- aci-mcp-unified (port 63029)
- localstack-kms (port 63030) # For encryption
```

### Phase 2: Adaptation Requirements

#### Authentication Strategy
- Replace PropelAuth with Supabase Auth
- Create auth adapter layer
- Use Supabase JWT tokens
- Map Supabase users to ACI organizations

#### Network Integration
- Add to `backend-bridge-network`
- Configure Kong Gateway routes
- Enable service-to-service communication

#### Environment Variables Mapping
```env
# ACI Backend Configuration
ACI_BACKEND_SOURCE=container
ACI_BACKEND_PORT=63026
ACI_DB_HOST=supabase-db
ACI_DB_PORT=5432
ACI_DB_NAME=postgres
ACI_DB_SCHEMA=aci
ACI_DB_USER=${SUPABASE_DB_APP_USER}
ACI_DB_PASSWORD=${SUPABASE_DB_APP_PASSWORD}
ACI_JWT_SECRET=${SUPABASE_JWT_SECRET}
ACI_OPENAI_API_KEY=${OPENAI_API_KEY}
ACI_REDIRECT_URI_BASE=http://localhost:63026
```

### Phase 3: Service Integration

#### 1. Backend API Integration
- Mount ACI tools directory
- Configure OAuth providers
- Set up encryption keys
- Initialize tool database

#### 2. Frontend Portal Integration
- Configure Next.js to use Supabase Auth
- Update API endpoints to local backend
- Add to services dashboard
- Configure CORS for local development

#### 3. MCP Server Configuration
- Point to local ACI backend
- Configure tool discovery
- Set up authentication flow
- Enable in Open WebUI

### Phase 4: Tool Migration

#### Pre-installed Tools
```
Priority Tools to Configure:
1. GitHub - Code repository management
2. Vercel - Deployment automation
3. Supabase - Database operations (meta!)
4. Cloudflare - DNS and CDN
5. Docker - Container management
6. Slack/Discord - Communications
7. Google Suite - Calendar, Docs, Sheets
8. OpenAI/Anthropic - AI services
```

## 🚀 Implementation Steps

### Step 1: Database Setup
```sql
-- Create ACI schema in Supabase
CREATE SCHEMA IF NOT EXISTS aci;

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant permissions
GRANT ALL ON SCHEMA aci TO app_user;
```

### Step 2: Docker Services
```yaml
# Add to docker-compose.yml
aci-backend:
  build: ./aci-integration/backend
  environment:
    - DATABASE_URL=postgresql://...
    - USE_SUPABASE_AUTH=true
  ports:
    - "63026:8000"
  networks:
    - backend-bridge-network

aci-frontend:
  build: ./aci-integration/frontend
  environment:
    - NEXT_PUBLIC_API_URL=http://localhost:63026
    - NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL}
  ports:
    - "63027:3000"
  networks:
    - backend-bridge-network
```

### Step 3: Authentication Adapter
Create Supabase-to-ACI auth adapter to handle:
- User authentication
- Organization management
- API key generation
- OAuth token storage

### Step 4: Tool Configuration
1. Import tool definitions from ACI
2. Configure OAuth apps for each service
3. Store credentials securely
4. Test tool execution

### Step 5: MCP Integration
1. Install aci-mcp package
2. Configure to use local backend
3. Add to Open WebUI functions
4. Test tool discovery and execution

## 📈 Benefits of Self-Hosting

1. **Complete Control** - No external dependencies
2. **Data Privacy** - All credentials stored locally
3. **Customization** - Modify tools and add custom integrations
4. **Cost Savings** - No API usage fees
5. **Performance** - Lower latency for tool calls
6. **Integration** - Deep integration with existing stack

## 🔐 Security Considerations

1. **Encryption** - Use KMS for credential encryption
2. **Network Isolation** - Keep services on internal network
3. **Access Control** - Implement RBAC for tool access
4. **Audit Logging** - Track all tool executions
5. **Secret Management** - Use Supabase vault for secrets

## 📋 Migration Checklist

- [ ] Clone ACI repository
- [ ] Set up database schema
- [ ] Create Docker images
- [ ] Configure authentication
- [ ] Import tool definitions
- [ ] Set up OAuth providers
- [ ] Test tool execution
- [ ] Configure MCP servers
- [ ] Integrate with Open WebUI
- [ ] Update documentation
- [ ] Test end-to-end flow

## 🎯 Success Criteria

1. All ACI services running locally
2. Authentication working with Supabase
3. Tools accessible via API
4. MCP servers functional
5. Open WebUI can discover and execute tools
6. No external API dependencies
7. All credentials stored securely

## 📚 Next Steps

1. Begin with database schema setup
2. Create authentication adapter
3. Build Docker images
4. Configure first tool (GitHub)
5. Test with Open WebUI
6. Gradually add more tools
