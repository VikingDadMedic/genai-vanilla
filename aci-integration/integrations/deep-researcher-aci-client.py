"""
ACI Integration for Deep Researcher
Extends Deep Researcher with 600+ tool capabilities
"""

import os
import httpx
import asyncio
from typing import Dict, Any, List, Optional
from datetime import datetime
import json


class ACIResearcherClient:
    """
    Client for integrating ACI tools with Deep Researcher
    Enables saving research to various platforms and enhanced data gathering
    """
    
    def __init__(self):
        self.aci_backend_url = os.getenv("ACI_BACKEND_URL", "http://aci-backend:8000")
        self.client = httpx.AsyncClient(timeout=30)
        
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def save_research_to_notion(
        self,
        research_data: Dict[str, Any],
        workspace_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Save research results to Notion"""
        try:
            # Format research for Notion
            notion_page = {
                "title": research_data.get("query", "Research Results"),
                "content": research_data.get("result", ""),
                "metadata": {
                    "timestamp": datetime.now().isoformat(),
                    "sources": research_data.get("sources", []),
                    "model": research_data.get("model", "unknown")
                }
            }
            
            # Execute Notion create page function
            response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "notion",
                    "function_name": "create_page",
                    "parameters": {
                        "workspace_id": workspace_id,
                        "page_data": notion_page
                    }
                }
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            return {"error": f"Failed to save to Notion: {str(e)}"}
    
    async def save_research_to_google_docs(
        self,
        research_data: Dict[str, Any],
        folder_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Save research results to Google Docs"""
        try:
            # Format research for Google Docs
            doc_content = f"""
# {research_data.get("query", "Research Results")}

Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

## Summary
{research_data.get("result", "")}

## Sources
{json.dumps(research_data.get("sources", []), indent=2)}
            """
            
            # Execute Google Docs create document function
            response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "google_docs",
                    "function_name": "create_document",
                    "parameters": {
                        "title": f"Research: {research_data.get('query', 'Untitled')}",
                        "content": doc_content,
                        "folder_id": folder_id
                    }
                }
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            return {"error": f"Failed to save to Google Docs: {str(e)}"}
    
    async def gather_github_context(
        self,
        repo_name: str,
        query: str
    ) -> Dict[str, Any]:
        """Gather context from GitHub repositories"""
        try:
            results = {}
            
            # Search issues
            issues_response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "github",
                    "function_name": "search_issues",
                    "parameters": {
                        "repo": repo_name,
                        "query": query
                    }
                }
            )
            if issues_response.status_code == 200:
                results["issues"] = issues_response.json()
            
            # Search code
            code_response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "github",
                    "function_name": "search_code",
                    "parameters": {
                        "repo": repo_name,
                        "query": query
                    }
                }
            )
            if code_response.status_code == 200:
                results["code"] = code_response.json()
            
            # Get recent commits
            commits_response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "github",
                    "function_name": "list_commits",
                    "parameters": {
                        "repo": repo_name,
                        "limit": 10
                    }
                }
            )
            if commits_response.status_code == 200:
                results["recent_commits"] = commits_response.json()
            
            return results
            
        except Exception as e:
            return {"error": f"Failed to gather GitHub context: {str(e)}"}
    
    async def notify_slack(
        self,
        channel: str,
        research_summary: str,
        research_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """Send research notification to Slack"""
        try:
            message = f"📚 New Research Completed\n\n{research_summary}"
            if research_url:
                message += f"\n\n🔗 View full results: {research_url}"
            
            response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "slack",
                    "function_name": "send_message",
                    "parameters": {
                        "channel": channel,
                        "text": message
                    }
                }
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            return {"error": f"Failed to notify Slack: {str(e)}"}
    
    async def create_jira_ticket(
        self,
        project_key: str,
        research_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Create a Jira ticket from research findings"""
        try:
            response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "jira",
                    "function_name": "create_issue",
                    "parameters": {
                        "project_key": project_key,
                        "summary": f"Research: {research_data.get('query', 'Research Task')}",
                        "description": research_data.get("result", ""),
                        "issue_type": "Task"
                    }
                }
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            return {"error": f"Failed to create Jira ticket: {str(e)}"}
    
    async def search_confluence(
        self,
        query: str
    ) -> Dict[str, Any]:
        """Search Confluence for related documentation"""
        try:
            response = await self.client.post(
                f"{self.aci_backend_url}/v1/functions/execute",
                json={
                    "app_name": "confluence",
                    "function_name": "search_content",
                    "parameters": {
                        "query": query,
                        "limit": 10
                    }
                }
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            return {"error": f"Failed to search Confluence: {str(e)}"}


# Integration with Deep Researcher's main flow
class EnhancedDeepResearcher:
    """
    Enhanced Deep Researcher with ACI tool integration
    """
    
    def __init__(self, base_researcher):
        self.base_researcher = base_researcher
        self.aci_client = ACIResearcherClient()
        self.save_to_platforms = os.getenv("RESEARCHER_SAVE_PLATFORMS", "notion,google_docs").split(",")
        self.notify_channels = os.getenv("RESEARCHER_NOTIFY_CHANNELS", "").split(",")
    
    async def research_with_tools(
        self,
        query: str,
        save_results: bool = True,
        notify: bool = True,
        gather_github: bool = False,
        github_repo: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Perform research with enhanced tool capabilities
        """
        # Run base research
        research_result = await self.base_researcher.research(query)
        
        # Enhance with GitHub context if requested
        if gather_github and github_repo:
            github_context = await self.aci_client.gather_github_context(
                github_repo, query
            )
            research_result["github_context"] = github_context
        
        # Save to configured platforms
        if save_results:
            save_results = {}
            
            if "notion" in self.save_to_platforms:
                save_results["notion"] = await self.aci_client.save_research_to_notion(
                    research_result
                )
            
            if "google_docs" in self.save_to_platforms:
                save_results["google_docs"] = await self.aci_client.save_research_to_google_docs(
                    research_result
                )
            
            research_result["saved_to"] = save_results
        
        # Send notifications
        if notify and self.notify_channels:
            notifications = {}
            for channel in self.notify_channels:
                if channel:
                    notifications[channel] = await self.aci_client.notify_slack(
                        channel,
                        f"Research on '{query}' completed",
                        save_results.get("notion", {}).get("url")
                    )
            research_result["notifications"] = notifications
        
        return research_result
