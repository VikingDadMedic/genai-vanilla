# MCP Configuration Guide for GenAI Stack

## Overview

Model Context Protocol (MCP) servers connect Cursor to external tools and data sources, enhancing development workflow for the GenAI Vanilla Stack project.

## Configuration Setup

### Global MCP Configuration
Located at `~/.cursor/mcp.json`, contains commonly used MCP servers across all projects.

### Project-Specific Configuration
Located at `.cursor/mcp.json`, contains MCP servers specific to this GenAI project:

- **Azure DevOps**: For managing Azure deployment tasks, pipelines, and work items
- **Docker**: For container management during development
- **PostgreSQL**: For database operations

## Azure DevOps MCP Integration

The Azure DevOps MCP server is configured with selected domains to avoid tool overload:

```json
{
  "azure-devops-genai": {
    "type": "stdio",
    "command": "npx",
    "args": [
      "-y",
      "@azure-devops/mcp",
      "${input:ado_org}",
      "-d",
      "core",        // Project management
      "work",        // Iterations and sprints
      "work-items",  // Task tracking
      "repositories",// Code management
      "pipelines",   // CI/CD
      "wiki"         // Documentation
    ]
  }
}
```

### Key Features for GenAI Development

1. **Pipeline Management**
   - Monitor deployment pipelines
   - Trigger Azure deployments
   - Check build statuses

2. **Work Item Tracking**
   - Create tasks for Azure configuration
   - Track deployment issues
   - Manage feature requests

3. **Repository Integration**
   - Create PRs for configuration changes
   - Review deployment scripts
   - Manage branches for environments

4. **Wiki Documentation**
   - Update deployment guides
   - Document Azure configurations
   - Maintain architecture docs

## Best Practices

### 1. Tool Organization (Order Matters!)
The order of MCP servers in configuration affects:
- Loading priority
- UI display order
- Tool discovery by AI

**Recommended Order:**
1. Project-critical tools (Azure DevOps for deployment)
2. Development tools (Docker, databases)
3. Code analysis tools (repomix, kit-mcp)
4. Productivity tools (memory, task management)
5. Optional/experimental tools

### 2. Managing the 40-Tool Limit
Cursor has a soft limit of ~40 active tools to maintain performance:

**Strategies:**
- Use domain filtering (like we do with Azure DevOps)
- Toggle off unused servers in Settings
- Create task-specific configurations
- Rotate tools based on current work

### 3. Security Considerations
- Never commit API keys to repositories
- Use environment variables for sensitive data
- Regularly rotate credentials
- Review MCP server permissions

### 4. Performance Optimization
- Disable MCP servers not in active use
- Use `stdio` transport for local tools (faster)
- Limit Docker-based servers (resource intensive)
- Clear MCP cache if experiencing issues

## Usage Examples for GenAI Stack

### Azure Deployment Tasks
```
"List ADO pipelines for genai-prod deployment"
"Create work item for Azure OpenAI integration"
"Check status of GPU VM deployment pipeline"
"Update wiki page for Azure deployment guide"
```

### Docker Management
```
"Show running containers for GenAI stack"
"Check docker compose service status"
"View logs for open-webui container"
```

### Database Operations
```
"Query Supabase tables for user configurations"
"Check Deep Researcher database entries"
"View n8n workflow execution history"
```

## Troubleshooting

### Common Issues

1. **MCP Server Not Loading**
   - Check Output panel → MCP Logs
   - Verify Azure CLI is logged in: `az login`
   - Restart Cursor after config changes

2. **Too Many Tools Error**
   - Disable unused servers in Settings
   - Use domain filtering for Azure DevOps
   - Create separate configs for different tasks

3. **Authentication Failures**
   - Refresh Azure token: `az account get-access-token`
   - Check environment variables
   - Verify organization name is correct

### Debug Commands
```bash
# Check Azure login status
az account show

# Test Azure DevOps access
az devops project list --organization YOUR_ORG

# View MCP logs location
echo ~/.cursor/logs/
```

## Integration with GenAI Workflow

### Development Phase
Enable: repomix, kit-mcp, docker, postgres

### Deployment Phase
Enable: azure-devops, docker

### Documentation Phase
Enable: azure-devops (wiki), memory

### Monitoring Phase
Enable: azure-devops (pipelines), docker

## Updating MCP Servers

```bash
# Clear npm cache for updates
npm cache clean --force

# Update specific server (remove and re-add in Settings)
# Or for project config, update version in args
"@azure-devops/mcp@next"  # For latest features
```

## Tips for GenAI Stack Development

1. **Use project-specific config** for Azure deployment tools
2. **Keep global config** for general development tools
3. **Create aliases** in chat for common Azure operations
4. **Document tool usage** in team wiki
5. **Share configurations** via Azure DevOps repo

## Related Documentation

- [Azure Deployment Guide](../azure-deployment/AZURE_DEPLOYMENT_GUIDE.md)
- [Azure OpenAI Integration](../azure-deployment/AZURE_OPENAI_INTEGRATION_GUIDE.md)
- [Stack Architecture](./ARCHITECTURE_GUIDE.md)

