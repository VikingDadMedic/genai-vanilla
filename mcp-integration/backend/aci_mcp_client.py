"""
ACI.dev MCP Client for GenAI Vanilla Stack
Provides integration with ACI.dev's Apps and Unified MCP servers
"""

import httpx
import asyncio
import json
import os
from typing import Dict, Any, List, Optional, Union
from datetime import datetime, timedelta
from functools import lru_cache
import logging

logger = logging.getLogger(__name__)


class ACIMCPClient:
    """Client for interacting with ACI.dev MCP servers"""
    
    def __init__(self):
        """Initialize ACI MCP client with configuration from environment"""
        self.apps_server_url = os.getenv("ACI_MCP_APPS_URL", "http://aci-mcp-gateway:8100")
        self.unified_server_url = os.getenv("ACI_MCP_UNIFIED_URL", "http://aci-mcp-unified:8101")
        self.api_key = os.getenv("ACI_API_KEY")
        self.linked_account_id = os.getenv("ACI_LINKED_ACCOUNT_ID", "default")
        self.enabled_apps = os.getenv("ACI_ENABLED_APPS", "").split(",")
        
        # Caching configuration
        self.cache_enabled = os.getenv("ENABLE_MCP_CACHING", "true").lower() == "true"
        self.cache_ttl = int(os.getenv("MCP_CACHE_TTL", "300"))  # 5 minutes default
        self._tool_cache = {}
        self._cache_timestamps = {}
        
        if not self.api_key:
            logger.warning("ACI_API_KEY not set - MCP functionality will be limited")
    
    def _is_cache_valid(self, cache_key: str) -> bool:
        """Check if cached data is still valid"""
        if not self.cache_enabled or cache_key not in self._cache_timestamps:
            return False
        
        timestamp = self._cache_timestamps[cache_key]
        return datetime.now() - timestamp < timedelta(seconds=self.cache_ttl)
    
    async def search_functions(
        self, 
        intent: str, 
        limit: int = 10,
        use_cache: bool = True
    ) -> List[Dict]:
        """
        Search for available functions using Unified MCP Server
        
        Args:
            intent: Natural language description of what you want to do
            limit: Maximum number of results to return
            use_cache: Whether to use cached results if available
            
        Returns:
            List of function definitions matching the intent
        """
        cache_key = f"search:{intent}:{limit}"
        
        if use_cache and self._is_cache_valid(cache_key):
            logger.debug(f"Using cached results for: {intent}")
            return self._tool_cache[cache_key]
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.unified_server_url}/mcp/v1/tools/call",
                    json={
                        "name": "ACI_SEARCH_FUNCTIONS",
                        "arguments": {
                            "intent": intent,
                            "limit": limit
                        }
                    },
                    headers={
                        "X-API-KEY": self.api_key,
                        "X-Linked-Account-Owner-Id": self.linked_account_id
                    },
                    timeout=30.0
                )
                response.raise_for_status()
                
                results = response.json()
                
                # Cache results
                if self.cache_enabled:
                    self._tool_cache[cache_key] = results
                    self._cache_timestamps[cache_key] = datetime.now()
                
                return results
                
        except httpx.HTTPError as e:
            logger.error(f"Error searching functions: {e}")
            return []
    
    async def execute_function(
        self, 
        function_name: str, 
        arguments: Dict[str, Any],
        timeout: int = 60
    ) -> Dict:
        """
        Execute a function using Unified MCP Server
        
        Args:
            function_name: Name of the function (e.g., "GITHUB__CREATE_ISSUE")
            arguments: Function arguments as dictionary
            timeout: Request timeout in seconds
            
        Returns:
            Execution result from the function
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.unified_server_url}/mcp/v1/tools/call",
                    json={
                        "name": "ACI_EXECUTE_FUNCTION",
                        "arguments": {
                            "function_name": function_name,
                            "function_arguments": arguments
                        }
                    },
                    headers={
                        "X-API-KEY": self.api_key,
                        "X-Linked-Account-Owner-Id": self.linked_account_id
                    },
                    timeout=timeout
                )
                response.raise_for_status()
                
                result = response.json()
                logger.info(f"Successfully executed {function_name}")
                return result
                
        except httpx.TimeoutException:
            logger.error(f"Timeout executing {function_name}")
            return {"error": "Function execution timeout", "success": False}
        except httpx.HTTPError as e:
            logger.error(f"Error executing {function_name}: {e}")
            return {"error": str(e), "success": False}
    
    async def call_app_function(
        self, 
        app: str, 
        function: str, 
        arguments: Dict[str, Any]
    ) -> Dict:
        """
        Direct function call via Apps MCP Server
        
        Args:
            app: App name (e.g., "GITHUB")
            function: Function name (e.g., "CREATE_ISSUE")
            arguments: Function arguments
            
        Returns:
            Function execution result
        """
        if app not in self.enabled_apps:
            logger.warning(f"App {app} not in enabled apps: {self.enabled_apps}")
            return {"error": f"App {app} not enabled", "success": False}
        
        function_full_name = f"{app}__{function}"
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.apps_server_url}/mcp/v1/tools/call",
                    json={
                        "name": function_full_name,
                        "arguments": arguments
                    },
                    headers={
                        "X-API-KEY": self.api_key,
                        "X-Linked-Account-Owner-Id": self.linked_account_id
                    },
                    timeout=60.0
                )
                response.raise_for_status()
                return response.json()
                
        except httpx.HTTPError as e:
            logger.error(f"Error calling {function_full_name}: {e}")
            return {"error": str(e), "success": False}
    
    async def list_available_tools(self, app_filter: Optional[str] = None) -> List[Dict]:
        """
        List all available tools from configured apps
        
        Args:
            app_filter: Optional app name to filter results
            
        Returns:
            List of available tool definitions
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.apps_server_url}/mcp/v1/tools",
                    headers={
                        "X-API-KEY": self.api_key
                    },
                    timeout=30.0
                )
                response.raise_for_status()
                
                tools = response.json()
                
                if app_filter:
                    tools = [t for t in tools if t.get("name", "").startswith(f"{app_filter}__")]
                
                return tools
                
        except httpx.HTTPError as e:
            logger.error(f"Error listing tools: {e}")
            return []
    
    async def get_tool_definition(self, tool_name: str) -> Optional[Dict]:
        """
        Get detailed definition for a specific tool
        
        Args:
            tool_name: Full tool name (e.g., "GITHUB__CREATE_ISSUE")
            
        Returns:
            Tool definition or None if not found
        """
        tools = await self.list_available_tools()
        for tool in tools:
            if tool.get("name") == tool_name:
                return tool
        return None
    
    async def batch_execute(
        self, 
        executions: List[Dict[str, Any]],
        parallel: bool = True
    ) -> List[Dict]:
        """
        Execute multiple functions in batch
        
        Args:
            executions: List of {"function_name": str, "arguments": dict}
            parallel: Whether to execute in parallel or sequentially
            
        Returns:
            List of execution results
        """
        if parallel:
            tasks = [
                self.execute_function(ex["function_name"], ex["arguments"])
                for ex in executions
            ]
            return await asyncio.gather(*tasks)
        else:
            results = []
            for ex in executions:
                result = await self.execute_function(
                    ex["function_name"], 
                    ex["arguments"]
                )
                results.append(result)
            return results
    
    def clear_cache(self):
        """Clear all cached tool data"""
        self._tool_cache.clear()
        self._cache_timestamps.clear()
        logger.info("MCP cache cleared")


class ACIMCPRouter:
    """Router for intelligent MCP request handling"""
    
    def __init__(self, client: ACIMCPClient):
        self.client = client
        self.routing_rules = self._load_routing_rules()
    
    def _load_routing_rules(self) -> Dict:
        """Load routing rules for different tool categories"""
        return {
            "communication": ["GMAIL", "SLACK", "DISCORD"],
            "development": ["GITHUB", "GITLAB", "BITBUCKET"],
            "search": ["BRAVE_SEARCH", "GOOGLE", "DUCKDUCKGO"],
            "productivity": ["NOTION", "TODOIST", "CALENDAR"],
            "ai": ["OPENAI", "ANTHROPIC", "HUGGINGFACE"]
        }
    
    async def route_request(
        self, 
        intent: str,
        context: Optional[Dict] = None
    ) -> Dict:
        """
        Route a request to the appropriate MCP function
        
        Args:
            intent: What the user wants to do
            context: Optional context for routing decision
            
        Returns:
            Routing decision with selected function and arguments
        """
        # Search for relevant functions
        functions = await self.client.search_functions(intent, limit=5)
        
        if not functions:
            return {
                "success": False,
                "error": "No suitable functions found",
                "intent": intent
            }
        
        # Select best function based on context
        selected = functions[0]  # Simple selection - could be enhanced with ML
        
        return {
            "success": True,
            "selected_function": selected,
            "alternatives": functions[1:],
            "intent": intent,
            "context": context
        }
    
    async def execute_routed_request(
        self,
        intent: str,
        context: Optional[Dict] = None,
        auto_execute: bool = False
    ) -> Dict:
        """
        Route and optionally execute a request
        
        Args:
            intent: What the user wants to do
            context: Optional context
            auto_execute: Whether to automatically execute the selected function
            
        Returns:
            Routing result and execution result if auto_execute is True
        """
        routing = await self.route_request(intent, context)
        
        if not routing["success"]:
            return routing
        
        if auto_execute and context and "arguments" in context:
            function_name = routing["selected_function"]["name"]
            result = await self.client.execute_function(
                function_name,
                context["arguments"]
            )
            routing["execution_result"] = result
        
        return routing


# Singleton instance for easy import
_client_instance: Optional[ACIMCPClient] = None

def get_mcp_client() -> ACIMCPClient:
    """Get or create singleton MCP client instance"""
    global _client_instance
    if _client_instance is None:
        _client_instance = ACIMCPClient()
    return _client_instance


# Example usage
if __name__ == "__main__":
    async def main():
        client = get_mcp_client()
        
        # Search for email tools
        print("Searching for email tools...")
        tools = await client.search_functions("send email", limit=3)
        for tool in tools:
            print(f"  - {tool.get('name')}: {tool.get('description')}")
        
        # Execute a function (example)
        # result = await client.execute_function(
        #     "GMAIL__SEND_EMAIL",
        #     {
        #         "to": "test@example.com",
        #         "subject": "Test",
        #         "body": "This is a test email"
        #     }
        # )
        # print(f"Execution result: {result}")
    
    asyncio.run(main())
