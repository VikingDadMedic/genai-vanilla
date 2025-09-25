"""
title: ACI Self-Hosted Bridge 🏠
author: GenAI Stack
version: 1.0.0
description: Bridge to self-hosted ACI platform for 600+ tool integrations
"""

import httpx
import json
import asyncio
from typing import AsyncGenerator, Dict, Any, List, Optional
from pydantic import BaseModel, Field
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Pipe:
    """
    Self-Hosted ACI Bridge for Open WebUI
    Provides access to 600+ tools through self-hosted ACI platform
    """
    
    def __init__(self):
        self.name = "ACI Self-Hosted Bridge 🏠"
        self.valves = self.Valves()
        self.client = None
        self.available_tools = []
        
    class Valves(BaseModel):
        aci_backend_url: str = Field(
            default="http://aci-backend:8000",
            description="Self-hosted ACI backend URL (internal Docker URL)"
        )
        aci_mcp_unified_url: str = Field(
            default="http://aci-mcp-unified:8101",
            description="ACI MCP Unified server URL for tool discovery"
        )
        aci_mcp_apps_url: str = Field(
            default="http://aci-mcp-apps:8100",
            description="ACI MCP Apps server URL for direct tool access"
        )
        use_mcp_unified: bool = Field(
            default=True,
            description="Use MCP Unified server for dynamic tool discovery"
        )
        max_tools_per_search: int = Field(
            default=5,
            description="Maximum number of tools to return in search"
        )
        timeout: int = Field(
            default=30,
            description="Request timeout in seconds"
        )
        enable_pipe: bool = Field(
            default=True,
            description="Enable or disable the ACI bridge"
        )
        auto_discover_tools: bool = Field(
            default=True,
            description="Automatically discover available tools on startup"
        )
        priority_apps: str = Field(
            default="GITHUB,GITLAB,VERCEL,SUPABASE,CLOUDFLARE,DOCKER",
            description="Comma-separated list of priority apps to load"
        )

    async def on_chat_start(self):
        """Initialize client and discover available tools"""
        if not self.valves.enable_pipe:
            return
            
        self.client = httpx.AsyncClient(timeout=self.valves.timeout)
        
        if self.valves.auto_discover_tools:
            await self.discover_tools()

    async def on_chat_end(self):
        """Clean up client connection"""
        if self.client:
            await self.client.aclose()

    async def discover_tools(self) -> List[Dict[str, Any]]:
        """Discover available tools from ACI backend"""
        try:
            # Get list of available apps
            response = await self.client.get(
                f"{self.valves.aci_backend_url}/v1/apps"
            )
            response.raise_for_status()
            apps = response.json()
            
            self.available_tools = []
            
            # Get functions for priority apps
            priority_apps = self.valves.priority_apps.split(",")
            for app in apps:
                if app["name"].upper() in priority_apps:
                    func_response = await self.client.get(
                        f"{self.valves.aci_backend_url}/v1/functions",
                        params={"app_name": app["name"]}
                    )
                    if func_response.status_code == 200:
                        functions = func_response.json()
                        for func in functions[:3]:  # Limit functions per app
                            self.available_tools.append({
                                "app": app["name"],
                                "function": func["name"],
                                "description": func.get("description", ""),
                                "id": func["id"]
                            })
            
            return self.available_tools
            
        except Exception as e:
            logger.error(f"Failed to discover tools: {e}")
            return []

    async def search_tools(self, query: str) -> List[Dict[str, Any]]:
        """Search for relevant tools based on query"""
        if self.valves.use_mcp_unified:
            return await self.search_tools_mcp(query)
        else:
            return await self.search_tools_direct(query)

    async def search_tools_mcp(self, query: str) -> List[Dict[str, Any]]:
        """Search tools using MCP Unified server"""
        try:
            response = await self.client.post(
                f"{self.valves.aci_mcp_unified_url}/search",
                json={
                    "query": query,
                    "limit": self.valves.max_tools_per_search
                }
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"MCP search failed: {e}")
            return []

    async def search_tools_direct(self, query: str) -> List[Dict[str, Any]]:
        """Search tools directly from ACI backend"""
        try:
            response = await self.client.post(
                f"{self.valves.aci_backend_url}/v1/functions/search",
                json={
                    "query": query,
                    "limit": self.valves.max_tools_per_search
                }
            )
            response.raise_for_status()
            results = response.json()
            
            return [{
                "app": r["app_name"],
                "function": r["function_name"],
                "description": r.get("description", ""),
                "score": r.get("score", 0)
            } for r in results]
            
        except Exception as e:
            logger.error(f"Direct search failed: {e}")
            return []

    async def execute_tool(
        self,
        app_name: str,
        function_name: str,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute a specific tool"""
        try:
            # Execute through ACI backend
            response = await self.client.post(
                f"{self.valves.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": app_name,
                    "function_name": function_name,
                    "parameters": parameters
                }
            )
            response.raise_for_status()
            return response.json()
            
        except httpx.HTTPStatusError as e:
            logger.error(f"Tool execution failed: {e.response.text}")
            return {
                "error": f"Execution failed: {e.response.status_code}",
                "details": e.response.text
            }
        except Exception as e:
            logger.error(f"Tool execution error: {e}")
            return {"error": str(e)}

    async def __call__(
        self,
        query: str,
        history: list[dict],
        **kwargs
    ) -> AsyncGenerator[str, None]:
        """
        Process user query with ACI tools
        """
        if not self.valves.enable_pipe:
            yield "ACI Self-Hosted Bridge is disabled."
            return

        yield "🔍 Searching for relevant tools in self-hosted ACI...\n\n"
        
        try:
            # Search for relevant tools
            tools = await self.search_tools(query)
            
            if not tools:
                yield "No relevant tools found for your query.\n"
                yield "Available apps: " + self.valves.priority_apps
                return
            
            # Display found tools
            yield f"Found {len(tools)} relevant tools:\n"
            for i, tool in enumerate(tools, 1):
                yield f"{i}. **{tool['app']}** - {tool['function']}\n"
                if tool.get('description'):
                    yield f"   _{tool['description']}_\n"
            yield "\n"
            
            # Analyze query to determine if we should execute a tool
            if any(action in query.lower() for action in [
                'create', 'update', 'delete', 'deploy', 'run', 
                'execute', 'list', 'get', 'fetch', 'send'
            ]):
                # Execute the most relevant tool
                best_tool = tools[0]
                yield f"🔧 Executing **{best_tool['function']}** from {best_tool['app']}...\n\n"
                
                # Parse parameters from query (simplified)
                parameters = self.extract_parameters(query, best_tool)
                
                # Execute tool
                result = await self.execute_tool(
                    best_tool['app'],
                    best_tool['function'],
                    parameters
                )
                
                if "error" in result:
                    yield f"❌ Error: {result['error']}\n"
                    if "details" in result:
                        yield f"Details: {result['details']}\n"
                else:
                    yield "✅ Tool executed successfully!\n\n"
                    yield "**Result:**\n"
                    yield f"```json\n{json.dumps(result, indent=2)}\n```\n"
            else:
                yield "\n💡 To execute a tool, please be more specific about what action you'd like to take.\n"
                yield "For example: 'Create a new GitHub repository', 'Deploy to Vercel', etc.\n"
                
        except Exception as e:
            yield f"❌ An error occurred: {str(e)}\n"
            logger.error(f"Pipeline error: {e}", exc_info=True)

    def extract_parameters(self, query: str, tool: Dict[str, Any]) -> Dict[str, Any]:
        """
        Extract parameters from query for tool execution
        This is a simplified version - in production, you'd use LLM or more sophisticated parsing
        """
        parameters = {}
        
        # Basic parameter extraction based on common patterns
        if "github" in tool['app'].lower():
            if "repository" in query.lower() or "repo" in query.lower():
                # Extract repo name from query
                words = query.split()
                for i, word in enumerate(words):
                    if word.lower() in ['repository', 'repo'] and i + 1 < len(words):
                        parameters['name'] = words[i + 1].strip('",.')
                        break
                
                # Default parameters for repo creation
                if 'create' in query.lower():
                    parameters.setdefault('name', f'test-repo-{datetime.now().strftime("%Y%m%d%H%M%S")}')
                    parameters['private'] = 'private' in query.lower()
                    parameters['description'] = 'Created via ACI Self-Hosted Bridge'
        
        elif "vercel" in tool['app'].lower():
            if "deploy" in query.lower():
                parameters['project_name'] = 'my-app'
                parameters['framework'] = 'nextjs'
        
        elif "supabase" in tool['app'].lower():
            if "table" in query.lower():
                words = query.split()
                for i, word in enumerate(words):
                    if word.lower() == 'table' and i + 1 < len(words):
                        parameters['table_name'] = words[i + 1].strip('",.')
                        break
        
        return parameters

    async def get_available_apps(self) -> List[str]:
        """Get list of available apps"""
        try:
            response = await self.client.get(
                f"{self.valves.aci_backend_url}/v1/apps"
            )
            response.raise_for_status()
            apps = response.json()
            return [app["name"] for app in apps]
        except Exception as e:
            logger.error(f"Failed to get apps: {e}")
            return []

    async def get_app_functions(self, app_name: str) -> List[Dict[str, Any]]:
        """Get functions for a specific app"""
        try:
            response = await self.client.get(
                f"{self.valves.aci_backend_url}/v1/functions",
                params={"app_name": app_name}
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to get functions for {app_name}: {e}")
            return []
