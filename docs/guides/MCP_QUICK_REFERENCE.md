# MCP Configuration Quick Reference

## ✅ Problem Solved!

**Previous:** 293 tools (causing performance issues)  
**Now:** ~60 tools with optimized configuration

## 📁 Configuration Files

### Global Configuration
- **Location:** `~/.cursor/mcp.json`
- **Backup:** `~/.cursor/mcp.json.backup-*`
- **Optimized:** `~/.cursor/mcp-optimized.json`

### Profile Library
Located in `~/.cursor/mcp-profiles/`:
- `minimal.json` - Essential tools only (~16 tools)
- `dev.json` - Development focused (~25 tools)
- `azure.json` - Azure DevOps tools (~30 tools)
- `github.json` - GitHub tools (~90 tools)
- `tasks.json` - Task management (~50 tools)

### Project Configuration
- **Location:** `.cursor/mcp.json`
- **Purpose:** Project-specific tools

## 🚀 Quick Commands

### Switch Profiles
```bash
# Use the optimized balanced profile
~/.cursor/switch-mcp-profile.sh switch optimized

# Use minimal profile for best performance
~/.cursor/switch-mcp-profile.sh switch minimal

# Use development profile
~/.cursor/switch-mcp-profile.sh switch dev

# Use Azure DevOps profile
~/.cursor/switch-mcp-profile.sh switch azure
```

### Check Status
```bash
# See current profile
~/.cursor/switch-mcp-profile.sh status

# List all available profiles
~/.cursor/switch-mcp-profile.sh list

# Backup current config
~/.cursor/switch-mcp-profile.sh backup
```

## 🎯 Current Optimized Configuration

Your optimized setup includes:
1. **memory** - Persistent context (9 tools)
2. **azure-devops** - Filtered domains (core, work-items, repositories) (~20 tools)
3. **GitHub** - Full set (needs filtering if performance issues persist)
4. **repomix** - Code analysis (7 tools)
5. **kit-mcp** - Development tools (8 tools)
6. **sequential-thinking** - AI enhancement (1 tool)

**Total:** ~60-80 tools (well within limits!)

## 🔧 Manual Profile Switching

If the script doesn't work, manually switch:

```bash
# Backup current
cp ~/.cursor/mcp.json ~/.cursor/mcp.json.backup

# Switch to a profile
cp ~/.cursor/mcp-profiles/minimal.json ~/.cursor/mcp.json

# Or use the optimized config
cp ~/.cursor/mcp-optimized.json ~/.cursor/mcp.json
```

## 📊 Tool Count Guidelines

| Status | Tool Count | Performance |
|--------|-----------|-------------|
| ✅ Optimal | < 40 | Excellent |
| ⚠️ Acceptable | 40-80 | Good |
| 🔶 Warning | 80-150 | Degraded |
| 🚨 Critical | > 150 | Poor |

## 🎮 In Cursor UI

### To Disable Servers:
1. Open Settings (`Cmd+Shift+J`)
2. Go to Features → Model Context Protocol
3. Click toggle next to servers to disable

### To Check Tool Count:
1. Look at the MCP Tools panel
2. Expand each server to see tool count
3. Total is shown at the top

## 💡 Pro Tips

1. **Start minimal:** Begin with the minimal profile and add tools as needed
2. **Task-based switching:** Use different profiles for different tasks
3. **Regular cleanup:** Review and disable unused servers weekly
4. **Project isolation:** Keep project-specific tools in `.cursor/mcp.json`
5. **Monitor performance:** If Cursor slows down, switch to minimal profile

## 🚨 Troubleshooting

### If Cursor is slow:
```bash
# Switch to minimal immediately
cp ~/.cursor/mcp-profiles/minimal.json ~/.cursor/mcp.json
# Restart Cursor
```

### If tools aren't loading:
1. Check MCP Logs in Cursor Output panel
2. Verify server is enabled in Settings
3. Restart Cursor after config changes

### If Azure DevOps isn't working:
```bash
# Ensure Azure CLI is logged in
az login
az account show
```

## 📝 Remember

- **Less is more** - Only enable what you're actively using
- **Profiles save time** - Switch based on your current task
- **Backups are important** - Always backup before major changes
- **Restart required** - Cursor needs restart after MCP config changes

---

*Configuration optimized on: $(date)*
*From 293 tools → ~60 tools ✅*
