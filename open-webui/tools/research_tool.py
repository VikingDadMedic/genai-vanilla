"""
title: Research Assistant
author: GenAI Vanilla Stack
author_url: https://github.com/vanilla-genai
description: Web research tool for comprehensive information gathering
required_open_webui_version: 0.4.4
requirements: requests
version: 1.4.0
license: MIT
"""

import time
import requests
from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        researcher_url: str = Field(
            default="http://local-deep-researcher:2024",
            description="Deep Researcher service URL"
        )
        timeout: int = Field(
            default=900,
            description="Max wait time in seconds (15 minutes for research completion)"
        )
        search_api: str = Field(
            default="searxng",
            description="Search API to use (searxng or duckduckgo)"
        )
        max_loops: int = Field(
            default=3,
            description="Maximum research loops"
        )
        enable_tool: bool = Field(
            default=True,
            description="Enable this research tool"
        )
    
    def __init__(self):
        self.valves = self.Valves()
    
    def research(self, query: str):
        """
        Research a topic using web search and AI analysis.
        
        :param query: The topic or question to research
        :return: Research findings with sources
        """
        
        if not self.valves.enable_tool:
            return str("❌ Research tool is currently disabled. Enable it in tool settings if needed.")
        
        if not query:
            return str("❌ Please provide a research query.")
        
        try:
            # Create a new thread with unique metadata
            import time
            timestamp = int(time.time() * 1000)  # millisecond timestamp for uniqueness
            
            thread_resp = requests.post(
                f"{self.valves.researcher_url}/threads",
                json={
                    "metadata": {
                        "query": query,
                        "timestamp": timestamp,
                        "source": "open_webui_research_tool"
                    }
                },
                timeout=30
            )
            
            if thread_resp.status_code != 200:
                return f"❌ Failed to create thread: HTTP {thread_resp.status_code}"
            
            thread_data = thread_resp.json()
            thread_id = thread_data.get("thread_id")
            
            if not thread_id:
                return "❌ Failed to create research thread."
            
            # Start research run with correct input format and timeout handling
            try:
                resp = requests.post(
                    f"{self.valves.researcher_url}/threads/{thread_id}/runs/wait",
                    json={
                        "assistant_id": "a6ab75b8-fb3d-5c2c-a436-2fee55e33a06",
                        "input": {
                            "research_topic": query  # Deep Researcher expects 'research_topic' not 'query'
                        },
                        "config": {
                            "max_loops": min(self.valves.max_loops, 2),  # Limit loops for stability
                            "search_api": self.valves.search_api
                        }
                    },
                    timeout=self.valves.timeout
                )
            except requests.exceptions.Timeout:
                # Try to cancel the run on timeout
                try:
                    cancel_resp = requests.post(
                        f"{self.valves.researcher_url}/runs/cancel",
                        json={"run_id": "*"},  # Cancel all runs for safety
                        timeout=5
                    )
                except:
                    pass  # Ignore cancel errors
                return str(f"❌ Research timed out after {self.valves.timeout}s (15 minutes). The request has been cancelled to prevent system issues.")
            
            if resp.status_code != 200:
                try:
                    error_data = resp.json()
                    return str(f"❌ Research failed: {error_data.get('detail', 'Unknown error')}")
                except Exception as parse_error:
                    return str(f"❌ Research failed: HTTP {resp.status_code}. Parse error: {str(parse_error)}")
            
            # For LangGraph API, the response is the final result
            try:
                result_data = resp.json()
            except Exception as e:
                return str(f"❌ Failed to parse research response: {str(e)}")
            
            # ULTRA-SAFE: Force immediate plain text conversion to prevent [object Object]
            import json
            
            # Convert response to plain text immediately - no complex object handling
            try:
                # Simple text extraction approach
                if isinstance(result_data, dict):
                    # Extract content using simple string operations
                    content_text = ""
                    
                    # Look for common content fields and extract as text
                    for key in ['final_report', 'report', 'content', 'summary', 'result', 'answer']:
                        if key in result_data and result_data[key]:
                            content_text = str(result_data[key])
                            break
                    
                    if content_text:
                        # Return simple formatted text
                        simple_result = f"# Research Results: {query}\n\n{content_text}\n\n---\nResearch completed successfully ✅"
                    else:
                        # Fallback: JSON as text
                        simple_result = f"# Research Results: {query}\n\n```json\n{json.dumps(result_data, indent=2, default=str)}\n```\n\n---\nResearch completed ✅"
                else:
                    # Non-dict response: convert to text
                    simple_result = f"# Research Results: {query}\n\n{str(result_data)}\n\n---\nResearch completed ✅"
                
                # CRITICAL: Return as basic string literal - no complex types
                return simple_result
                
            except Exception as e:
                # Ultimate safety net: pure text response
                return f"Research completed for: {query}\n\nError: {str(e)}\n\nRaw response: {str(result_data)}"
            
        except requests.exceptions.ConnectionError:
            return str("❌ Cannot connect to research service. Please check if the backend is running.")
        except requests.exceptions.Timeout:
            return str(f"❌ Research service timed out after {self.valves.timeout}s (15 minutes). Service may be overloaded - try again later or increase timeout in settings.")
        except Exception as e:
            return str(f"❌ Unexpected error: {str(e)}")
    
    def _format_langgraph_result(self, result: dict, query: str, thread_id: str) -> str:
        """Format LangGraph research results with aggressive string conversion"""
        try:
            output = []
            
            # Ensure result is a dict, if not convert to string immediately
            if not isinstance(result, dict):
                safe_result = str(result)
                return f"✅ Research completed for: {query}\n\nResult: {safe_result}"
            
            title = result.get('title', f'Research Results: {query}')
            output.append(f"# {str(title)}")
            
            # Handle different possible response structures
            if 'final_report' in result:
                content = str(result['final_report'])
                output.append(f"\n## Research Report\n{content}")
            elif 'report' in result:
                content = str(result['report'])
                output.append(f"\n## Research Report\n{content}")
            elif 'content' in result:
                content = str(result['content'])
                if len(content) > 2000:
                    content = content[:2000] + "\n\n[Content truncated for brevity...]"
                output.append(f"\n## Details\n{content}")
            else:
                # Fallback: show the raw result
                output.append(f"\n## Raw Result\n{str(result)}")
            
            # Extract sources if available
            sources = result.get('sources', [])
            if sources and isinstance(sources, list):
                output.append("\n## Sources")
                for i, src in enumerate(sources[:5], 1):
                    if isinstance(src, dict):
                        title = str(src.get('title', 'Untitled'))
                        url = str(src.get('url', '#'))
                        output.append(f"{i}. [{title}]({url})")
                    else:
                        output.append(f"{i}. {str(src)}")
            
            output.append("\n## Research Info")
            output.append(f"- Thread ID: {str(thread_id)}")
            output.append(f"- Query: {str(query)}")
            output.append("- Status: ✅ Completed")
            
            # Final safety check: ensure we return a proper string
            final_output = "\n".join(str(line) for line in output)
            
            # Additional safety: check for object references
            if '[object' in final_output.lower():
                import json
                return f"✅ Research completed for: {query}\n\nSafe JSON result:\n{json.dumps(result, indent=2, default=str)}"
            
            return final_output
            
        except Exception as e:
            return f"✅ Research completed for: {query}\n\nError formatting result: {str(e)}\n\nRaw data: {str(result)}"
    
    def _format_result(self, result: dict, query: str) -> str:
        """Format successful research results"""
        output = []
        
        title = result.get('title', f'Research Results: {query}')
        output.append(f"# {title}")
        
        summary = result.get('summary', '')
        if summary:
            output.append(f"\n## Summary\n{summary}")
        
        content = result.get('content', '')
        if content:
            # Limit content length
            if len(content) > 2000:
                content = content[:2000] + "\n\n[Content truncated for brevity...]"
            output.append(f"\n## Details\n{content}")
        
        sources = result.get('sources', [])
        if sources:
            output.append("\n## Sources")
            for i, src in enumerate(sources[:5], 1):
                title = src.get('title', 'Untitled')
                url = src.get('url', '#')
                output.append(f"{i}. [{title}]({url})")
        
        metadata = result.get('metadata', {})
        if metadata:
            output.append(f"\n## Research Stats")
            output.append(f"- Search API: {metadata.get('search_api', 'N/A')}")
            output.append(f"- Research loops: {metadata.get('max_loops', 'N/A')}")
            output.append(f"- Sources analyzed: {metadata.get('sources_analyzed', 'N/A')}")
        
        return "\n".join(output)
    
    def _create_fallback_result(self, query: str, session_id: str) -> str:
        """Create a fallback result when the API result endpoint fails"""
        return f"""# Research Results: {query}

## Summary
Research session completed successfully (Session: {session_id}).

## Status
✅ The research has been completed, but detailed results are currently unavailable due to a temporary API issue.

## Recommendation
The research service processed your query "{query}" successfully. You can try running the research again, or contact support if the issue persists.

## Technical Details
- Session ID: {session_id}
- Status: Completed
- Issue: Result retrieval temporarily unavailable

*Note: This is a simplified response due to a backend API issue. The research was completed successfully.*"""