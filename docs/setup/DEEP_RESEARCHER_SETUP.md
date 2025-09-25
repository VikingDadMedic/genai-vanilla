# Deep Researcher Setup Guide

## Overview

The Deep Researcher is an AI-powered web research service that integrates with Open-WebUI as a "Pipe" (function). It appears as a selectable model in the Open-WebUI interface.

## Architecture

```
Open-WebUI (Port 63015)
    ↓ Selects "Deep Researcher 🔍" from model dropdown
    ↓ Sends query via Pipe function
Backend API (Port 63016)
    ↓ /research/* endpoints
Local Deep Researcher (Port 63013)
    ↓ LangGraph-based research service
    ↓ Queries database for LLM configuration
    ├── SearxNG (Port 63014) - Web search
    └── Ollama (Port 63012) - LLM for analysis
```

## Prerequisites

### 1. Volume Mounts (Required)
The `docker-compose.yml` must mount the functions directory:
```yaml
open-web-ui:
  volumes:
    - ./open-webui/tools:/app/backend/data/tools
    - ./open-webui/functions:/app/backend/data/functions  # ← This line is critical!
```

### 2. LLM Service (Required)
Deep Researcher needs an LLM to analyze search results. It reads the configuration from the database `llms` table.

**If using OpenAI API mode:**
- Deep Researcher still needs Ollama for its own operations
- Run: `./fix-deep-researcher.sh` to set this up

**If using Ollama mode:**
- Ensure the model specified in the database is pulled
- Default: `qwen3:latest`

## Setup Steps

### Step 1: Fix Docker Compose (if needed)
```bash
# Check if functions directory is mounted
grep "functions:/app/backend/data/functions" docker-compose.yml || echo "Missing!"

# If missing, the fix has been applied in docker-compose.yml
```

### Step 2: Ensure LLM Availability
```bash
# Option A: If using OpenAI API, enable Ollama for Deep Researcher
./fix-deep-researcher.sh

# Option B: If using Ollama, ensure model is pulled
docker exec genai-ollama ollama pull qwen3:latest
```

### Step 3: Restart Services
```bash
# Recreate Open-WebUI with proper mounts
docker compose down open-web-ui
docker compose up -d open-web-ui

# Restart Deep Researcher
docker compose restart local-deep-researcher
```

### Step 4: Verify Setup
```bash
# Check if Deep Researcher is running
docker ps | grep deep-researcher

# Check if API is accessible (may take 1-2 minutes to start)
curl http://localhost:63013/docs

# Check if Pipe is loaded in Open-WebUI
docker exec genai-open-web-ui ls /app/backend/data/functions/
```

## Using Deep Researcher

### In Open-WebUI

1. **Access Open-WebUI**: http://localhost:63015
2. **Select Model**: Click the model dropdown
3. **Choose Deep Researcher**: Look for "Deep Researcher 🔍"
4. **Ask Questions**: Type research queries like:
   - "What are the latest developments in quantum computing?"
   - "Compare AWS, Azure, and GCP for machine learning"
   - "Research the current state of renewable energy"

### Features

- **Real-time Progress**: Shows research loops and sources found
- **Source Citations**: Provides links to all sources
- **Structured Output**: Summary, key findings, and sources
- **Configurable Depth**: Adjust research iterations (default: 3)

## Troubleshooting

### Deep Researcher Not in Dropdown

1. **Check if Pipe is mounted:**
   ```bash
   docker exec genai-open-web-ui ls -la /app/backend/data/functions/
   # Should show: deep_researcher_pipe.py
   ```

2. **Restart Open-WebUI:**
   ```bash
   docker compose restart open-web-ui
   ```

3. **Check logs:**
   ```bash
   docker logs genai-open-web-ui | grep -i "pipe\|function"
   ```

### Deep Researcher Unhealthy

1. **Check service status:**
   ```bash
   docker ps | grep deep-researcher
   docker logs genai-local-deep-researcher --tail 50
   ```

2. **Common issue - Waiting for Ollama:**
   ```
   Local Deep Researcher: Waiting for Ollama API (attempt X/30)...
   ```
   **Solution**: Run `./fix-deep-researcher.sh` to enable Ollama

3. **Check database connection:**
   ```bash
   docker exec genai-local-deep-researcher cat /app/config/runtime_config.json
   ```

### Research Fails or Times Out

1. **Check SearxNG:**
   ```bash
   curl "http://localhost:63014/search?q=test&format=json"
   ```

2. **Check backend connection:**
   ```bash
   curl http://localhost:63016/research/health
   ```

3. **Verify LLM model:**
   ```bash
   docker exec -it genai-supabase-db psql -U supabase_admin -d postgres -c \
   "SELECT name, provider, active FROM public.llms WHERE content > 0;"
   ```

## Configuration

### Change Research Model

To use a different model for research:

```sql
-- Connect to database
docker exec -it genai-supabase-db psql -U supabase_admin -d postgres

-- Deactivate current model
UPDATE public.llms SET active = false WHERE name = 'qwen3:latest';

-- Activate different model
UPDATE public.llms SET active = true WHERE name = 'llama3.2:3b';
```

Then restart Deep Researcher:
```bash
docker compose restart local-deep-researcher
```

### Adjust Research Depth

Edit `.env`:
```bash
LOCAL_DEEP_RESEARCHER_LOOPS=5  # Increase for deeper research
```

## Architecture Details

### Database Configuration
The Deep Researcher queries the `llms` table:
```sql
SELECT provider, name FROM public.llms 
WHERE active = true AND content > 0 
ORDER BY content DESC, provider = 'ollama' DESC
LIMIT 1;
```

### Service Dependencies
```yaml
local-deep-researcher:
  depends_on:
    - supabase-db-init  # Database must be initialized
    - searxng          # Search service must be running
```

### Network Communication
- All services communicate via `backend-bridge-network`
- Internal URLs:
  - Ollama: `http://ollama:11434`
  - SearxNG: `http://searxng:8080`
  - Backend: `http://backend:8000`

## Advanced Configuration

### Using OpenAI for Research

If you want Deep Researcher to use OpenAI instead of Ollama:

1. **Update database:**
   ```sql
   INSERT INTO public.llms (name, provider, active, content, api_key, api_endpoint)
   VALUES ('gpt-4o-mini', 'openai', true, 10, 'your-api-key', 'https://api.openai.com/v1');
   ```

2. **Modify Deep Researcher** (requires code changes):
   - Update `/local-deep-researcher/scripts/init-config.py`
   - Add OpenAI client support

### Custom Search Engines

Edit `.env`:
```bash
LOCAL_DEEP_RESEARCHER_SEARCH_API=searxng  # or duckduckgo
SEARXNG_URL=http://searxng:8080
```

## Summary

The Deep Researcher is a powerful research tool that:
1. **Requires** proper volume mounts in docker-compose.yml
2. **Needs** an LLM service (Ollama by default)
3. **Appears** as a model option in Open-WebUI
4. **Performs** multi-step web research with citations
5. **Configures** itself from the database

For quick setup, run: `./fix-deep-researcher.sh`
