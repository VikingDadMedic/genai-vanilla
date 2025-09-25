"""
title: Deep Researcher 🔍
author: GenAI Stack
version: 0.1.0
description: AI-powered web research using Local Deep Researcher service
"""

import asyncio
import json
import time
from typing import AsyncGenerator, Dict, Any, Optional
import httpx
from pydantic import BaseModel, Field


class Pipe:
    """
    Deep Researcher Pipe for Open-WebUI
    Provides AI-powered web research capabilities directly in the chat interface
    """
    
    def __init__(self):
        self.valves = self.Valves()
        self.client = None
        self.name = "Deep Researcher 🔍"

    class Valves(BaseModel):
        backend_url: str = Field(
            default="http://backend:8000",
            description="Backend service URL"
        )
        timeout: int = Field(
            default=300,
            description="Maximum time for research (seconds)"
        )
        max_loops: int = Field(
            default=3,
            description="Maximum research iterations"
        )
        show_status: bool = Field(
            default=True,
            description="Show research progress updates"
        )
        enable_pipe: bool = Field(
            default=True,
            description="Enable or disable this pipe"
        )

    async def pipe(
        self, 
        user_message: str, 
        model_id: str, 
        messages: list, 
        body: dict
    ) -> AsyncGenerator[str, None]:
        """
        Main pipe function that performs web research.
        
        Args:
            user_message: The user's research query
            model_id: The model ID (not used, as Deep Researcher uses its own model)
            messages: Conversation history
            body: Request body with additional parameters
            
        Yields:
            Research progress updates and final results
        """
        
        if not self.valves.enable_pipe:
            yield "❌ Deep Researcher is currently disabled."
            return
        
        try:
            # Initialize HTTP client
            async with httpx.AsyncClient(timeout=self.valves.timeout) as client:
                
                # Start research session
                if self.valves.show_status:
                    yield "🔍 Initiating research...\n\n"
                
                start_response = await client.post(
                    f"{self.valves.backend_url}/research/start",
                    json={
                        "query": user_message,
                        "max_loops": self.valves.max_loops,
                        "search_api": "duckduckgo"
                    }
                )
                
                if start_response.status_code != 200:
                    yield f"❌ Failed to start research: {start_response.text}"
                    return
                
                session_data = start_response.json()
                session_id = session_data.get("session_id")
                
                if not session_id:
                    yield "❌ No session ID received from research service"
                    return
                
                # Poll for results
                start_time = time.time()
                last_status = ""
                
                while (time.time() - start_time) < self.valves.timeout:
                    # Check status
                    status_response = await client.get(
                        f"{self.valves.backend_url}/research/{session_id}/status"
                    )
                    
                    if status_response.status_code != 200:
                        yield f"❌ Failed to check status: {status_response.text}"
                        return
                    
                    status_data = status_response.json()
                    status = status_data.get("status", "unknown")
                    
                    # Show progress updates
                    if self.valves.show_status and status == "in_progress":
                        current_loop = status_data.get("current_loop", 0)
                        sources_found = status_data.get("sources_found", 0)
                        status_msg = f"🔄 Researching... Loop {current_loop}/{self.valves.max_loops} | Sources found: {sources_found}"
                        
                        if status_msg != last_status:
                            yield f"\r{status_msg}"
                            last_status = status_msg
                    
                    # Check if completed
                    if status == "completed":
                        # Get full results
                        result_response = await client.get(
                            f"{self.valves.backend_url}/research/{session_id}/result"
                        )
                        
                        if result_response.status_code != 200:
                            yield f"❌ Failed to get results: {result_response.text}"
                            return
                        
                        result_data = result_response.json()
                        
                        # Format and return results
                        yield "\n\n" + self._format_research_results(result_data)
                        return
                    
                    elif status == "failed":
                        error = status_data.get("error", "Unknown error")
                        yield f"\n\n❌ Research failed: {error}"
                        return
                    
                    # Wait before next poll
                    await asyncio.sleep(2)
                
                # Timeout reached
                yield f"\n\n⏱️ Research timed out after {self.valves.timeout} seconds"
                
        except httpx.ConnectError:
            yield "❌ Cannot connect to research service. Please ensure the backend is running."
        except Exception as e:
            yield f"❌ Error during research: {str(e)}"

    def _format_research_results(self, data: Dict[str, Any]) -> str:
        """
        Format research results for display in chat.
        
        Args:
            data: Research result data
            
        Returns:
            Formatted markdown string
        """
        output = "## 🔍 Research Results\n\n"
        
        # Add summary
        if data.get("summary"):
            output += "### Summary\n"
            output += f"{data['summary']}\n\n"
        
        # Add detailed findings
        if data.get("findings"):
            output += "### Key Findings\n"
            for i, finding in enumerate(data['findings'], 1):
                output += f"{i}. {finding}\n"
            output += "\n"
        
        # Add sources
        if data.get("sources"):
            output += "### Sources\n"
            for source in data['sources']:
                if isinstance(source, dict):
                    title = source.get('title', 'Untitled')
                    url = source.get('url', '#')
                    output += f"- [{title}]({url})\n"
                else:
                    output += f"- {source}\n"
            output += "\n"
        
        # Add metadata
        output += "---\n"
        output += f"*Research completed in {data.get('duration', 'N/A')} seconds*\n"
        output += f"*Model: {data.get('model', 'Default research model')}*\n"
        output += f"*Loops: {data.get('loops_completed', 'N/A')}*\n"
        
        return output

    async def on_startup(self):
        """
        Called when the pipe is loaded.
        Can be used for initialization tasks.
        """
        print(f"Deep Researcher Pipe initialized with backend: {self.valves.backend_url}")

    async def on_shutdown(self):
        """
        Called when the pipe is unloaded.
        Can be used for cleanup tasks.
        """
        if self.client:
            await self.client.aclose()
        print("Deep Researcher Pipe shutdown")

    async def on_valves_updated(self):
        """
        Called when valve settings are updated.
        Can be used to reinitialize connections.
        """
        print(f"Deep Researcher settings updated: backend={self.valves.backend_url}, timeout={self.valves.timeout}s")
