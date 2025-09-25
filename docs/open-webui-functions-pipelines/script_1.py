# Create comprehensive setup and configuration guides
setup_guides = {
    "functions_setup": {
        "overview": "Built-in plugin system for Open WebUI",
        "requirements": ["Open WebUI installation", "Admin access"],
        "installation_steps": [
            "Navigate to Admin Panel > Functions",
            "Import from community or create custom",
            "Configure valves/settings",
            "Enable for specific models or globally",
            "Test functionality"
        ],
        "configuration": {
            "location": "Admin Panel > Functions",
            "per_model": "Workspace > Models > Assign Functions",
            "global": "Functions menu > Global toggle"
        }
    },
    "pipelines_setup": {
        "overview": "External server for heavy processing and complex workflows",
        "requirements": ["Docker", "Open WebUI instance", "Network connectivity"],
        "installation_steps": [
            "Run Pipelines container: docker run -d -p 9099:9099 --add-host=host.docker.internal:host-gateway -v pipelines:/app/pipelines --name pipelines --restart always ghcr.io/open-webui/pipelines:main",
            "Configure Open WebUI connection: Admin Panel > Settings > Connections",
            "Add API URL: http://localhost:9099 (or host.docker.internal:9099 for Docker)",
            "Set API key: 0p3n-w3bu!",
            "Install/manage pipelines: Admin Panel > Settings > Pipelines",
            "Configure valve settings per pipeline"
        ],
        "networking": {
            "port": "9099",
            "docker_host": "host.docker.internal",
            "api_key": "0p3n-w3bu!"
        }
    },
    "development_workflow": {
        "functions": {
            "creation": "Built-in code editor in Admin Panel",
            "testing": "Enable and test in chat interface",
            "debugging": "Console logs and error messages",
            "deployment": "Save and enable directly"
        },
        "pipelines": {
            "creation": "External Python files in /pipelines directory",
            "testing": "Separate server testing environment",
            "debugging": "Server logs and API responses",
            "deployment": "File placement and server restart"
        }
    }
}

# Create detailed technical specifications
technical_specs = {
    "valves_system": {
        "definition": "Configuration interface for plugins",
        "types": {
            "Valves": "Admin-configurable settings",
            "UserValves": "User-configurable settings per chat session"
        },
        "implementation": "Pydantic BaseModel classes",
        "ui_elements": {
            "int/float": "Number input",
            "bool": "Toggle switch",
            "str": "Text input",
            "Literal": "Dropdown selection",
            "enum": "Multi-choice dropdown"
        }
    },
    "hooks_and_methods": {
        "functions": {
            "tools": ["main function with parameters"],
            "pipe_functions": ["pipe(body: dict)"],
            "filter_functions": ["inlet(body: dict)", "outlet(body: dict)", "stream(event: dict)"],
            "action_functions": ["action method with custom logic"]
        },
        "pipelines": {
            "pipe": ["pipe(user_message, model_id, messages, body)"],
            "filter": ["inlet(body, user)", "outlet(body, user)"],
            "manifold": ["pipelines()", "pipe(user_message, model_id, messages, body)"]
        }
    },
    "data_structures": {
        "common_parameters": {
            "__user__": "Current user context",
            "__event_emitter__": "Real-time UI updates",
            "body": "Complete request/response data",
            "messages": "Chat conversation history"
        }
    }
}

# Save comprehensive guides
with open('setup_guides.json', 'w') as f:
    json.dump(setup_guides, f, indent=2)

with open('technical_specifications.json', 'w') as f:
    json.dump(technical_specs, f, indent=2)

print("Setup guides and technical specifications saved")
print("\nKey Setup Insights:")
print("- Functions: Built-in, admin panel configuration, immediate deployment")
print("- Pipelines: External server, Docker setup, network configuration required")
print("- Valves provide standardized configuration UI for both systems")
print("- Development workflows differ significantly between Functions and Pipelines")