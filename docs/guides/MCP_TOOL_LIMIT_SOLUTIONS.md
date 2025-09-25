# MCP Tool Limit Solutions Guide

## 🚨 The Problem: 293 Tools Active!

You're experiencing **severe tool overload** with 293 tools active, which causes:
- **Performance degradation** - Cursor becomes slow and unresponsive
- **Model confusion** - AI models can't effectively use >80 tools
- **Context pollution** - Too many tools dilute the model's focus
- **Memory issues** - Each MCP server consumes resources

### The Critical Offenders:
1. **GitHub MCP**: 90 tools (31% of total!)
2. **Azure DevOps**: 48 tools × 2 instances = 96 tools
3. **Taskmaster-AI**: 36 tools
4. **Taskflow**: 24 tools

## 🎯 Immediate Solutions

### Solution 1: Disable Duplicate Servers
You have Azure DevOps loaded twice (global + project). Choose ONE:

**Option A: Keep Project-Specific Only** (Recommended)
```bash
# Comment out or remove azure-devops from global config
# Keep only azure-devops-genai in project config
```

**Option B: Use Global for All Projects**
```bash
# Remove from project .cursor/mcp.json
# Keep in ~/.cursor/mcp.json
```

### Solution 2: Filter GitHub Tools
The GitHub MCP server is overwhelming with 90 tools. Add filtering:

```json
{
  "GitHub": {
    "command": "docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server",
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token",
      "GITHUB_TOOL_FILTER": "issues,pulls,repos"  // Only enable essential tools
    }
  }
}
```

### Solution 3: Create Task-Specific Profiles

#### Profile 1: Development Mode
```json
// ~/.cursor/mcp-dev.json
{
  "mcpServers": {
    "repomix": {...},
    "kit-mcp": {...},
    "memory": {...},
    "docker-genai": {...}
  }
}
```

#### Profile 2: Deployment Mode
```json
// ~/.cursor/mcp-deploy.json
{
  "mcpServers": {
    "azure-devops": {...},
    "docker-genai": {...},
    "postgres-genai": {...}
  }
}
```

#### Profile 3: Task Management Mode
```json
// ~/.cursor/mcp-tasks.json
{
  "mcpServers": {
    "taskmaster-ai": {...},
    "GitHub": {...},  // With filtered tools
    "azure-devops": {...}  // With filtered domains
  }
}
```

## 🏗️ Architecture: Source of Truth Strategy

### Recommended Structure:

```
~/.cursor/
├── mcp-base.json          # Minimal always-on tools (memory, repomix)
├── mcp-profiles/
│   ├── dev.json           # Development tools
│   ├── deploy.json        # Deployment tools
│   ├── tasks.json         # Task management
│   └── ai.json            # AI/LLM tools
└── mcp.json              # Symlink to active profile

.cursor/ (project-specific)
├── mcp.json              # Project-specific overrides only
└── mcp-disabled.json     # Backup of disabled configs
```

### The 80/20 Rule for MCP Tools:

**Core Tools (Always On - Max 20)**
- memory (9 tools)
- repomix (7 tools)
- Essential project tool (varies)

**Secondary Tools (Toggle as Needed - Max 60)**
- GitHub (filtered to ~20 tools)
- Azure DevOps (filtered to ~20 tools)
- Docker/Database tools (~20 tools)

## 🛠️ Implementation Steps

### Step 1: Backup Current Config
```bash
cp ~/.cursor/mcp.json ~/.cursor/mcp-backup-$(date +%Y%m%d).json
```

### Step 2: Create Minimal Base Config
```json
// ~/.cursor/mcp-base.json
{
  "mcpServers": {
    "memory": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-v", "cursor-memory:/app/dist", "mcp/memory"]
    },
    "repomix": {
      "command": "npx",
      "args": ["-y", "repomix", "--mcp"]
    }
  }
}
```

### Step 3: Create Profile Switcher Script
```bash
#!/bin/bash
# ~/.cursor/switch-mcp-profile.sh

PROFILE=$1
MCP_DIR=~/.cursor

if [ -z "$PROFILE" ]; then
  echo "Usage: switch-mcp-profile.sh [base|dev|deploy|tasks]"
  exit 1
fi

if [ -f "$MCP_DIR/mcp-profiles/$PROFILE.json" ]; then
  ln -sf "$MCP_DIR/mcp-profiles/$PROFILE.json" "$MCP_DIR/mcp.json"
  echo "Switched to $PROFILE profile"
else
  echo "Profile $PROFILE not found"
fi
```

## 🎮 Toggle Strategy

### In Cursor UI:
1. **Disable unused servers** without removing them
2. **Click server names** to expand and see tool counts
3. **Toggle off** high-tool-count servers when not needed

### Quick Toggle Groups:
- **Code Work**: repomix, kit-mcp, memory
- **Azure Work**: azure-devops, docker
- **GitHub Work**: GitHub (filtered), memory
- **AI Work**: sequential-thinking, context7

## 📊 Tool Count Management

### Target Limits:
- **Optimal**: 40-60 tools active
- **Maximum**: 80 tools (hard limit for model effectiveness)
- **Per Server**: Try to keep under 20 tools each

### Priority Order (First In, Best Served):
1. **Memory** (persistent context)
2. **Project-critical** (varies by current task)
3. **Code analysis** (repomix, kit-mcp)
4. **Version control** (GitHub/Azure DevOps)
5. **Infrastructure** (Docker, databases)
6. **Nice-to-have** (UI tools, experimental)

## 🔧 Advanced Optimizations

### 1. Custom Tool Filters for GitHub
Create a wrapper script that filters GitHub tools:
```bash
#!/bin/bash
# ~/.cursor/github-mcp-filtered.sh
docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN \
  -e TOOL_FILTER="create_issue,create_pull_request,get_issue,get_pull_request" \
  ghcr.io/github/github-mcp-server
```

### 2. Lazy Loading with Aliases
Create command aliases that load MCP servers on-demand:
```bash
alias mcp-github='cursor --mcp-server GitHub'
alias mcp-azure='cursor --mcp-server azure-devops'
```

### 3. Time-Based Profiles
Use cron to switch profiles based on time of day:
```cron
# Development mode during work hours
0 9 * * 1-5 ~/.cursor/switch-mcp-profile.sh dev
# Task management at day end
0 17 * * 1-5 ~/.cursor/switch-mcp-profile.sh tasks
```

## 🚀 Quick Fix Now

For immediate relief, disable these servers in Cursor Settings:
1. **MCP_DOCKER** (not providing tools)
2. **cognee** (7 tools, project-specific)
3. **context7** (2 tools, minimal value)
4. **One of the Azure DevOps instances**
5. **@magicuidesign/mcp** (8 tools, optional)

This will drop you from 293 to ~200 tools immediately.

## 📝 Best Practices

1. **One source of truth**: Project config should only ADD tools, not duplicate
2. **Domain filtering**: Always use for large servers (GitHub, Azure DevOps)
3. **Regular audits**: Review tool usage weekly
4. **Document purpose**: Comment why each server is needed
5. **Test profiles**: Verify each profile works before relying on it

## 🎯 Final Recommendation

**Your Optimal Setup:**
- **Global**: Minimal tools (memory, repomix) - 16 tools
- **Project**: Azure-specific tools (filtered) - 20 tools  
- **On-Demand**: GitHub (heavily filtered) - 20 tools
- **Total Active**: ~56 tools (well under limit!)

Remember: **Less is more** with MCP tools. Quality over quantity!
