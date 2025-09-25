# Create a comprehensive overview structure for the Open WebUI plugins architecture
import json

# Define the architecture overview structure
architecture_overview = {
    "open_webui_architecture": {
        "core_components": {
            "frontend": {
                "technology": "SvelteKit",
                "description": "Progressive Web App interface",
                "location": "src/",
                "features": ["Responsive design", "PWA support", "Real-time communication"]
            },
            "backend": {
                "technology": "FastAPI",
                "description": "Asynchronous Python API server",
                "location": "backend/open_webui/",
                "features": ["REST API", "WebSocket support", "Authentication", "Role-based access"]
            },
            "database": {
                "primary": "SQLAlchemy ORM",
                "legacy": "Peewee ORM (being migrated)",
                "storage": "SQLite (default), PostgreSQL, MySQL supported",
                "migrations": "Alembic"
            },
            "real_time": {
                "technology": "Socket.IO",
                "purpose": "WebSocket communication for streaming",
                "features": ["Chat streaming", "Real-time notifications"]
            },
            "caching": {
                "technology": "Redis",
                "uses": ["Caching", "WebSocket session management", "Background tasks"]
            }
        },
        "plugin_system": {
            "functions": {
                "execution_location": "Open WebUI server (internal)",
                "performance": "Fast (no network overhead)",
                "complexity": "Limited by main server resources",
                "use_cases": ["Simple providers", "Basic filters", "Built-in functionality"]
            },
            "pipelines": {
                "execution_location": "Separate server (external)",
                "performance": "Slower (network calls)",
                "complexity": "High computational tasks supported",
                "use_cases": ["Heavy processing", "Complex workflows", "Scalable operations"]
            }
        }
    },
    "plugin_types": {
        "tools": {
            "definition": "Extend LLM capabilities with external data/actions",
            "execution": "Called by LLM during conversation",
            "modes": {
                "default": "Prompt-based tool triggering (compatible with any model)",
                "native": "Built-in function calling (requires model support)"
            },
            "examples": ["Weather API", "Web search", "Calculator", "Database queries"]
        },
        "functions": {
            "types": {
                "pipe_function": {
                    "purpose": "Create custom agents/models",
                    "appearance": "Shows as selectable model",
                    "capabilities": ["Multi-model workflows", "Custom logic", "Non-AI integrations"]
                },
                "filter_function": {
                    "purpose": "Modify inputs/outputs",
                    "hooks": ["inlet (pre-LLM)", "outlet (post-LLM)", "stream (during response)"],
                    "capabilities": ["Content modification", "Logging", "Validation"]
                },
                "action_function": {
                    "purpose": "Add custom buttons to messages",
                    "appearance": "Interactive buttons in chat interface",
                    "capabilities": ["Post-processing", "User interactions", "Custom workflows"]
                }
            }
        },
        "pipelines": {
            "types": {
                "pipe": {
                    "purpose": "Complete request handling",
                    "behavior": "Takes over entire conversation flow",
                    "implementation": "pipe() method processes user input and returns response"
                },
                "filter": {
                    "purpose": "Middleware for request/response processing",
                    "hooks": ["inlet", "outlet"],
                    "behavior": "Processes data before/after LLM"
                },
                "manifold": {
                    "purpose": "Multi-model provider integration",
                    "behavior": "Exposes multiple models from external providers",
                    "implementation": "pipelines() method returns available models"
                }
            }
        }
    }
}

# Create detailed comparison table
comparison_data = {
    "feature_comparison": {
        "execution_location": {
            "functions": "Internal (Open WebUI server)",
            "pipelines": "External (Separate server)"
        },
        "performance": {
            "functions": "Fast (no network overhead)",
            "pipelines": "Slower (network calls required)"
        },
        "resource_usage": {
            "functions": "Limited by main server resources",
            "pipelines": "Can use dedicated server resources"
        },
        "complexity_support": {
            "functions": "Simple to moderate tasks",
            "pipelines": "Heavy computational tasks"
        },
        "scalability": {
            "functions": "Limited (single server)",
            "pipelines": "High (distributed architecture)"
        },
        "setup_complexity": {
            "functions": "Simple (built-in)",
            "pipelines": "Complex (separate server setup)"
        },
        "use_case_recommendation": {
            "functions": "Basic providers, simple filters, quick integrations",
            "pipelines": "Complex workflows, heavy processing, enterprise deployments"
        }
    }
}

# Save the structured data
with open('open_webui_architecture.json', 'w') as f:
    json.dump(architecture_overview, f, indent=2)

with open('functions_vs_pipelines_comparison.json', 'w') as f:
    json.dump(comparison_data, f, indent=2)

print("Architecture overview and comparison data saved to JSON files")
print("\nKey Architectural Insights:")
print("- Open WebUI uses a modular SvelteKit frontend + FastAPI backend architecture")
print("- Plugin system has two main approaches: Functions (internal) vs Pipelines (external)")
print("- Functions are faster but limited, Pipelines are more powerful but complex")
print("- Tools extend LLM capabilities, Functions extend WebUI capabilities")
print("- Valves provide configuration interfaces for all plugin types")