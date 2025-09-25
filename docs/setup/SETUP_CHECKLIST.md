# GenAI Vanilla Stack - Setup Checklist

## ✅ Completed Setup
- [x] Docker services started
- [x] Supabase JWT keys generated
- [x] OpenAI API key configured
- [x] Services dashboard created
- [x] Basic .env configuration

## 🔧 Required Setup Tasks

### 1. **n8n Workflow Platform** (Priority: HIGH)
**Status**: Running but needs initial configuration

```bash
# Access n8n
open http://localhost:63017

# Setup Steps:
1. Create your admin account (email + password)
2. Complete initial setup wizard
3. Go to Credentials → Add PostgreSQL credential:
   - Host: supabase-db
   - Port: 5432
   - Database: postgres
   - User: supabase_admin
   - Password: password
4. Import workflows from n8n/workflows/:
   - Go to Workflows → Import from File
   - Upload each .json file
   - Configure and activate workflows
```

### 2. **ComfyUI Models** (Priority: MEDIUM)
**Status**: Running, models will download on first use

```bash
# Access ComfyUI
open http://localhost:63018

# First-time setup:
1. Click "Queue Prompt" on any workflow
2. Models will auto-download (10-20 minutes)
3. Check progress in terminal:
   docker logs genai-comfyui-init -f
```

### 3. **Weaviate Vector Database** (Priority: MEDIUM)
**Status**: Running, needs collections

```bash
# Create your first collection
curl -X POST http://localhost:63019/v1/schema \
  -H "Content-Type: application/json" \
  -d '{
    "class": "Document",
    "vectorizer": "text2vec-ollama",
    "moduleConfig": {
      "text2vec-ollama": {
        "model": "mxbai-embed-large",
        "apiEndpoint": "http://ollama:11434"
      }
    },
    "properties": [
      {
        "name": "title",
        "dataType": ["text"]
      },
      {
        "name": "content",
        "dataType": ["text"]
      }
    ]
  }'
```

### 4. **Neo4j Graph Database** (Priority: LOW)
**Status**: Running with default credentials

```bash
# Access Neo4j Browser
open http://localhost:63011

# Login:
- URL: bolt://localhost:63010
- Username: neo4j
- Password: neo4j_password

# First time: Change password
:param newPassword => 'your-secure-password'
CALL dbms.security.changePassword($newPassword)
```

### 5. **Open-WebUI Configuration** (Priority: HIGH)
**Status**: Running, needs user account

```bash
# Access Open-WebUI
open http://localhost:63015

# Setup:
1. Create admin account (first user becomes admin)
2. Go to Settings → Connections
3. Verify OpenAI is connected (should show green status)
4. Test with a simple query
```

## 📊 Service Health Check

Run this command to check all services:

```bash
# Check service status
docker ps --format "table {{.Names}}\t{{.Status}}" | column -t

# Check specific service logs if needed
docker logs genai-[service-name] --tail 50
```

## 🚀 Quick Test Commands

### Test OpenAI Integration
```bash
curl -X POST http://localhost:63016/health
```

### Test Weaviate
```bash
curl http://localhost:63019/v1/.well-known/ready
```

### Test Neo4j
```bash
echo "MATCH (n) RETURN count(n)" | \
  docker exec -i genai-neo4j-graph-db cypher-shell \
  -u neo4j -p neo4j_password
```

### Test SearxNG
```bash
curl "http://localhost:63014/search?q=test&format=json" | jq .
```

## 📝 Optional Optimizations

### 1. **Increase Docker Resources**
```bash
# Docker Desktop → Settings → Resources
# Recommended: 12GB RAM, 6 CPUs
```

### 2. **Pull Additional Models**
```bash
# For better performance
docker exec genai-ollama ollama pull llama3.2:3b
docker exec genai-ollama ollama pull nomic-embed-text
```

### 3. **Configure Backup**
```bash
# Backup databases
docker exec genai-supabase-db pg_dump -U supabase_admin postgres > backup.sql
docker exec genai-neo4j-graph-db /usr/local/bin/backup.sh
```

## 🎯 Next Steps

After completing the setup:

1. **Explore Services**: Use the dashboard at `custom-pages/services-dashboard.html`
2. **Test Integrations**: Try the research features in Open-WebUI
3. **Create Workflows**: Build automation in n8n
4. **Import Data**: Start populating your vector database
5. **Monitor Performance**: Check Docker stats and logs

## 🆘 Troubleshooting

If any service is unhealthy:

```bash
# Restart specific service
docker compose restart [service-name]

# Check detailed logs
docker logs genai-[service-name] --tail 100

# Full restart if needed
./stop.sh
./start.sh
```

## 📚 Documentation

- Architecture Guide: `ARCHITECTURE_GUIDE.md`
- VM Deployment: `VM_DEPLOYMENT_GUIDE.md`
- Agent Guidelines: `AGENTS.md`
- Custom Pages: `custom-pages/README.md`

---

Last Updated: January 2025
