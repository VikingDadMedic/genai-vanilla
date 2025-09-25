"""
title: n8n Workflow Trigger
author: GenAI Stack
version: 0.1.0
description: Trigger n8n workflows from Open-WebUI chat interface
"""

import requests
import json
import time
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class Tools:
    def __init__(self):
        self.valves = self.Valves()

    class Valves(BaseModel):
        n8n_url: str = Field(
            default="http://n8n:5678",
            description="n8n service URL (internal Docker URL)"
        )
        n8n_external_url: str = Field(
            default="http://localhost:63017",
            description="n8n external URL for webhook construction"
        )
        timeout: int = Field(
            default=60,
            description="Maximum time to wait for workflow completion (seconds)"
        )
        enable_tool: bool = Field(
            default=True,
            description="Enable or disable this tool"
        )

    def trigger_research_workflow(
        self,
        query: str,
        wait_for_completion: bool = True
    ) -> str:
        """
        Trigger the research workflow in n8n with a search query.
        
        Args:
            query: The research query to process
            wait_for_completion: Whether to wait for the workflow to complete
            
        Returns:
            The research results or workflow status
        """
        if not self.valves.enable_tool:
            return "n8n integration is currently disabled."
        
        try:
            # Construct webhook URL
            webhook_url = f"{self.valves.n8n_external_url}/webhook/research"
            
            # Prepare payload
            payload = {
                "query": query,
                "timestamp": time.time(),
                "source": "open-webui"
            }
            
            # Trigger webhook
            response = requests.post(
                webhook_url,
                json=payload,
                timeout=self.valves.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                if "summary" in result:
                    return f"## Research Results\n\n{result.get('summary', 'No summary available')}\n\n### Sources\n{result.get('sources', 'No sources found')}"
                else:
                    return f"Workflow triggered successfully. Response: {json.dumps(result, indent=2)}"
            elif response.status_code == 404:
                return "❌ Workflow not found. Please ensure the research workflow is imported and activated in n8n."
            else:
                return f"❌ Failed to trigger workflow. Status: {response.status_code}"
                
        except requests.exceptions.ConnectionError:
            return "❌ Cannot connect to n8n. Please ensure n8n is running and the webhook is configured."
        except requests.exceptions.Timeout:
            return f"⏱️ Workflow execution timed out after {self.valves.timeout} seconds."
        except Exception as e:
            return f"❌ Error triggering workflow: {str(e)}"

    def trigger_comfyui_workflow(
        self,
        prompt: str,
        negative_prompt: str = "",
        workflow_name: str = "default"
    ) -> str:
        """
        Trigger a ComfyUI image generation workflow via n8n.
        
        Args:
            prompt: The positive prompt for image generation
            negative_prompt: The negative prompt (what to avoid)
            workflow_name: The name of the ComfyUI workflow to use
            
        Returns:
            Status of the workflow trigger or generated image information
        """
        if not self.valves.enable_tool:
            return "n8n integration is currently disabled."
        
        try:
            # Construct webhook URL
            webhook_url = f"{self.valves.n8n_external_url}/webhook/comfyui-generate"
            
            # Prepare payload
            payload = {
                "prompt": prompt,
                "negative_prompt": negative_prompt,
                "workflow": workflow_name,
                "timestamp": time.time(),
                "source": "open-webui"
            }
            
            # Trigger webhook
            response = requests.post(
                webhook_url,
                json=payload,
                timeout=self.valves.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                if "image_url" in result:
                    return f"✅ Image generated successfully!\n\n![Generated Image]({result['image_url']})\n\nPrompt: {prompt}"
                else:
                    return f"Workflow triggered. Response: {json.dumps(result, indent=2)}"
            elif response.status_code == 404:
                return "❌ ComfyUI workflow not found. Please ensure the workflow is imported and activated in n8n."
            else:
                return f"❌ Failed to trigger workflow. Status: {response.status_code}"
                
        except requests.exceptions.ConnectionError:
            return "❌ Cannot connect to n8n. Please ensure n8n is running and the webhook is configured."
        except Exception as e:
            return f"❌ Error triggering workflow: {str(e)}"

    def list_available_workflows(self) -> str:
        """
        List all available n8n workflows that can be triggered.
        
        Returns:
            A formatted list of available workflows
        """
        if not self.valves.enable_tool:
            return "n8n integration is currently disabled."
        
        # This is a static list - in a real implementation, you might query n8n's API
        workflows = [
            {
                "name": "Research Workflow",
                "webhook": "/webhook/research",
                "description": "Perform web research using SearxNG and AI summarization",
                "trigger": "trigger_research_workflow(query)"
            },
            {
                "name": "ComfyUI Generation",
                "webhook": "/webhook/comfyui-generate",
                "description": "Generate images using ComfyUI",
                "trigger": "trigger_comfyui_workflow(prompt, negative_prompt)"
            },
            {
                "name": "Batch Research",
                "webhook": "/webhook/batch-research",
                "description": "Process multiple research queries",
                "status": "Not yet implemented"
            }
        ]
        
        output = "## Available n8n Workflows\n\n"
        for wf in workflows:
            output += f"### {wf['name']}\n"
            output += f"- **Webhook**: `{wf['webhook']}`\n"
            output += f"- **Description**: {wf['description']}\n"
            if "trigger" in wf:
                output += f"- **Usage**: `{wf['trigger']}`\n"
            if "status" in wf:
                output += f"- **Status**: {wf['status']}\n"
            output += "\n"
        
        return output

    def check_n8n_status(self) -> str:
        """
        Check if n8n is accessible and running.
        
        Returns:
            Status information about n8n service
        """
        if not self.valves.enable_tool:
            return "n8n integration is currently disabled."
        
        try:
            # Try to access n8n health endpoint
            response = requests.get(
                f"{self.valves.n8n_url}/healthz",
                timeout=5
            )
            
            if response.status_code == 200:
                return f"✅ n8n is running and accessible\n- Internal URL: {self.valves.n8n_url}\n- External URL: {self.valves.n8n_external_url}"
            else:
                return f"⚠️ n8n responded with status code: {response.status_code}"
                
        except requests.exceptions.ConnectionError:
            return f"❌ Cannot connect to n8n at {self.valves.n8n_url}\n\nPlease ensure:\n1. n8n service is running\n2. URL is correct\n3. Network connectivity exists"
        except Exception as e:
            return f"❌ Error checking n8n status: {str(e)}"
