# GenAI Vanilla Stack Development Guidelines

## Core Principles
- **Respect the SOURCE-based configuration system** - all service modes are configured via SOURCE environment variables
- **Check bootstrapper/service-configs.yml** before modifying service configurations
- **Use Python bootstrapper** for all configuration management (start.py/stop.py)
- **Follow BASE_PORT + offset pattern** for port assignments (default BASE_PORT=63000)

## Architecture Overview
This stack uses a microservices architecture with:
- **Infrastructure Layer**: Supabase (PostgreSQL, Auth, Storage), Redis, Neo4j, Kong Gateway
- **AI/ML Layer**: Ollama, ComfyUI, Weaviate, Deep Researcher, SearxNG
- **Application Layer**: FastAPI backend, Open-WebUI, n8n workflows

## Service Configuration
### Adding New Service Modes
1. Update `bootstrapper/service-configs.yml` with new SOURCE options
2. Never modify `docker-compose.yml` directly for configuration changes
3. Document service dependencies in the YAML configuration

### SOURCE Variable Pattern
- Format: `SERVICE_NAME_SOURCE` (e.g., `LLM_PROVIDER_SOURCE`)
- Valid values: `container-cpu`, `container-gpu`, `localhost`, `external`, `api`, `disabled`

## Development Patterns

### Python Services
- Use **FastAPI + Pydantic** for REST APIs
- Use **asyncpg** for PostgreSQL (not SQLAlchemy)
- Use **neo4j-driver** for Neo4j graph database
- Create **client classes** for service integrations
- Always use **environment variables** for configuration

### Docker Services
- All services defined in unified `docker-compose.yml`
- Service scaling controlled by `*_SCALE` environment variables
- Dependencies managed through Docker Compose `depends_on`

### Port Management
- Ports assigned as `BASE_PORT + offset` (see port_manager.py)
- Use `--base-port` flag with start.sh to change base port
- Never hardcode ports in service configurations

## Key Files Reference
- `bootstrapper/service-configs.yml` - Source of truth for service configurations
- `bootstrapper/start.py` - Orchestrates entire startup process
- `docker-compose.yml` - Unified service definitions
- `.env.example` - Template for environment configuration

## Service Dependencies
Important relationships to maintain:
- **Weaviate** requires Ollama for embeddings
- **n8n** requires Weaviate for vector operations
- **Backend** depends on Supabase DB and can connect to all AI services
- **Open-WebUI** requires Ollama and optionally Deep Researcher

## Testing & Validation
- Run `./start.sh` to validate all configurations
- Check service health at respective ports
- Use Kong Gateway endpoints for centralized access
- Monitor logs with `docker compose logs [service-name]`

## Common Operations
```bash
# Start with default configuration
./start.sh

# Start with custom base port
./start.sh --base-port 64000

# Start with SOURCE overrides
./start.sh --llm-provider-source ollama-localhost --comfyui-source localhost

# Stop and clean up
./stop.sh --cold  # Removes all data
```
