"""
title: MCP Bridge 🌉
author: GenAI Stack
version: 0.3.0
description: Bridge between Open WebUI and MCP servers for dynamic tool discovery and execution
"""

import httpx
import json
import asyncio
import os
from typing import AsyncGenerator, Dict, Any, List, Optional
from pydantic import BaseModel, Field
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Pipe:
    """
    MCP Bridge for Open WebUI
    Provides access to 600+ tools through ACI.dev MCP servers
    """
    
    def __init__(self):
        self.name = "MCP Bridge 🌉"
        self.valves = self.Valves()
        self.last_discovered_tools = []
        
    class Valves(BaseModel):
        mcp_router_url: str = Field(
            default="http://mcp-router:8000",
            description="MCP Router service URL"
        )
        aci_unified_url: str = Field(
            default="http://aci-mcp-unified:8101",
            description="ACI Unified MCP server URL"
        )
        aci_apps_url: str = Field(
            default="http://aci-mcp-gateway:8100",
            description="ACI Apps MCP server URL"
        )
        enable_tool_discovery: bool = Field(
            default=True,
            description="Enable automatic tool discovery based on user intent"
        )
        max_tools_to_show: int = Field(
            default=5,
            description="Maximum number of discovered tools to show"
        )
        auto_execute: bool = Field(
            default=False,
            description="Automatically execute the best matching tool"
        )
        api_key: str = Field(
            default="",
            description="ACI API key (if not set in environment)"
        )
        linked_account_id: str = Field(
            default="default",
            description="Linked account owner ID for tool execution"
        )
        timeout: int = Field(
            default=60,
            description="Request timeout in seconds"
        )
        enable_caching: bool = Field(
            default=True,
            description="Enable caching of tool discoveries"
        )
        debug_mode: bool = Field(
            default=False,
            description="Enable debug logging"
        )
    
    async def pipe(self, body: dict) -> AsyncGenerator[str, None]:
        """
        Main pipeline function for MCP Bridge
        Processes user messages and provides tool discovery/execution
        """
        if self.valves.debug_mode:
            logger.setLevel(logging.DEBUG)
        
        # Extract user message
        messages = body.get("messages", [])
        if not messages:
            yield "❌ No messages found in request"
            return
        
        user_message = messages[-1].get("content", "")
        if not user_message:
            yield "❌ Empty message received"
            return
        
        # Log the request
        logger.info(f"Processing MCP request: {user_message[:100]}...")
        
        try:
            # Step 1: Tool Discovery
            if self.valves.enable_tool_discovery:
                yield "🔍 **Discovering relevant tools...**\n\n"
                
                discovered_tools = await self.discover_tools(user_message)
                
                if discovered_tools:
                    yield f"✅ Found {len(discovered_tools)} relevant tools:\n\n"
                    
                    # Display discovered tools
                    for i, tool in enumerate(discovered_tools[:self.valves.max_tools_to_show], 1):
                        tool_name = tool.get("name", "Unknown")
                        tool_desc = tool.get("description", "No description")
                        yield f"{i}. **{tool_name}**\n   {tool_desc}\n\n"
                    
                    self.last_discovered_tools = discovered_tools
                    
                    # Auto-execute if enabled
                    if self.valves.auto_execute and discovered_tools:
                        yield "\n🚀 **Executing most relevant tool...**\n\n"
                        result = await self.execute_best_tool(
                            discovered_tools[0], 
                            user_message
                        )
                        yield f"**Result:**\n```json\n{json.dumps(result, indent=2)}\n```\n"
                else:
                    yield "❌ No relevant tools found for your request.\n\n"
            
            # Step 2: Check for explicit tool execution
            if user_message.lower().startswith("execute:") or user_message.lower().startswith("run:"):
                yield "\n⚡ **Executing specified tool...**\n\n"
                result = await self.execute_from_message(user_message)
                yield f"**Result:**\n```json\n{json.dumps(result, indent=2)}\n```\n"
            
            # Step 3: Provide guidance
            elif not self.valves.auto_execute and discovered_tools:
                yield "\n💡 **How to use these tools:**\n"
                yield "- To execute a tool, type: `execute: TOOL_NAME {arguments}`\n"
                yield "- Example: `execute: GITHUB__CREATE_ISSUE {\"title\": \"Bug report\", \"body\": \"Description\"}`\n"
                yield "- Or enable auto-execute in settings for automatic execution\n"
        
        except Exception as e:
            logger.error(f"Error in MCP Bridge: {str(e)}")
            yield f"\n❌ **Error:** {str(e)}\n"
            if self.valves.debug_mode:
                import traceback
                yield f"\n**Debug trace:**\n```\n{traceback.format_exc()}\n```\n"
    
    async def discover_tools(self, intent: str) -> List[Dict]:
        """
        Discover relevant tools based on user intent
        """
        try:
            headers = self._get_headers()
            
            async with httpx.AsyncClient() as client:
                # Use ACI Unified MCP for tool discovery
                response = await client.post(
                    f"{self.valves.aci_unified_url}/mcp/v1/tools/call",
                    json={
                        "name": "ACI_SEARCH_FUNCTIONS",
                        "arguments": {
                            "intent": intent,
                            "limit": self.valves.max_tools_to_show * 2  # Get extra for filtering
                        }
                    },
                    headers=headers,
                    timeout=self.valves.timeout
                )
                
                if response.status_code == 200:
                    result = response.json()
                    
                    # Extract tools from result
                    if isinstance(result, dict) and "data" in result:
                        return result["data"]
                    elif isinstance(result, list):
                        return result
                    else:
                        logger.warning(f"Unexpected response format: {result}")
                        return []
                else:
                    logger.error(f"Tool discovery failed: {response.status_code}")
                    return []
                    
        except Exception as e:
            logger.error(f"Error discovering tools: {str(e)}")
            return []
    
    async def execute_best_tool(self, tool: Dict, context: str) -> Dict:
        """
        Execute the best matching tool with inferred arguments
        """
        try:
            tool_name = tool.get("name", "")
            
            # Parse arguments from context (simplified - could use LLM for better parsing)
            arguments = self._parse_arguments_from_context(tool_name, context)
            
            return await self.execute_tool(tool_name, arguments)
            
        except Exception as e:
            logger.error(f"Error executing tool {tool_name}: {str(e)}")
            return {"error": str(e), "success": False}
    
    async def execute_tool(self, tool_name: str, arguments: Dict) -> Dict:
        """
        Execute a specific tool with given arguments
        """
        try:
            headers = self._get_headers()
            
            async with httpx.AsyncClient() as client:
                # Use ACI Unified MCP for execution
                response = await client.post(
                    f"{self.valves.aci_unified_url}/mcp/v1/tools/call",
                    json={
                        "name": "ACI_EXECUTE_FUNCTION",
                        "arguments": {
                            "function_name": tool_name,
                            "function_arguments": arguments
                        }
                    },
                    headers=headers,
                    timeout=self.valves.timeout
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    return {
                        "error": f"Execution failed with status {response.status_code}",
                        "success": False
                    }
                    
        except Exception as e:
            logger.error(f"Error executing tool {tool_name}: {str(e)}")
            return {"error": str(e), "success": False}
    
    async def execute_from_message(self, message: str) -> Dict:
        """
        Parse and execute tool from message format:
        execute: TOOL_NAME {arguments}
        """
        try:
            # Remove prefix
            if message.lower().startswith("execute:"):
                message = message[8:].strip()
            elif message.lower().startswith("run:"):
                message = message[4:].strip()
            
            # Parse tool name and arguments
            parts = message.split("{", 1)
            if len(parts) != 2:
                return {"error": "Invalid format. Use: execute: TOOL_NAME {arguments}", "success": False}
            
            tool_name = parts[0].strip()
            arguments_str = "{" + parts[1]
            
            # Parse JSON arguments
            try:
                arguments = json.loads(arguments_str)
            except json.JSONDecodeError as e:
                return {"error": f"Invalid JSON arguments: {str(e)}", "success": False}
            
            # Execute the tool
            return await self.execute_tool(tool_name, arguments)
            
        except Exception as e:
            logger.error(f"Error parsing execution message: {str(e)}")
            return {"error": str(e), "success": False}
    
    def _get_headers(self) -> Dict[str, str]:
        """
        Get headers for API requests
        """
        headers = {
            "Content-Type": "application/json"
        }
        
        # Add API key if configured
        api_key = self.valves.api_key or os.getenv("ACI_API_KEY")
        if api_key:
            headers["X-API-KEY"] = api_key
        
        # Add linked account ID
        headers["X-Linked-Account-Owner-Id"] = self.valves.linked_account_id
        
        return headers
    
    def _parse_arguments_from_context(self, tool_name: str, context: str) -> Dict:
        """
        Parse arguments from context for a given tool
        This is a simplified version - in production, use an LLM for better parsing
        """
        # Default empty arguments
        arguments = {}
        
        # Tool-specific parsing (examples)
        if "GITHUB__CREATE_ISSUE" in tool_name:
            # Extract title and body from context
            if "title:" in context.lower():
                # Simple extraction logic
                arguments["title"] = "Issue from MCP Bridge"
                arguments["body"] = context
        
        elif "GMAIL__SEND_EMAIL" in tool_name:
            # Extract email details
            arguments["subject"] = "Email from MCP Bridge"
            arguments["body"] = context
            # Would need to extract "to" address from context
        
        elif "BRAVE_SEARCH__WEB_SEARCH" in tool_name:
            # Use entire context as search query
            arguments["query"] = context
        
        # Add more tool-specific parsing as needed
        
        return arguments
    
    async def list_all_tools(self) -> List[Dict]:
        """
        List all available tools from all MCP servers
        """
        try:
            all_tools = []
            
            # Get tools from router
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.valves.mcp_router_url}/mcp/tools",
                    timeout=self.valves.timeout
                )
                
                if response.status_code == 200:
                    data = response.json()
                    all_tools = data.get("tools", [])
            
            return all_tools
            
        except Exception as e:
            logger.error(f"Error listing tools: {str(e)}")
            return []


# Optional: Standalone execution for testing
if __name__ == "__main__":
    async def test():
        pipe = Pipe()
        
        # Test tool discovery
        test_body = {
            "messages": [
                {"role": "user", "content": "Find information about artificial intelligence"}
            ]
        }
        
        async for chunk in pipe.pipe(test_body):
            print(chunk, end="")
    
    asyncio.run(test())
