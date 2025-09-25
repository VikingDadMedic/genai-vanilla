# GenAI Vanilla Stack - Architecture & Networking Guide

## 🏗️ Architecture Overview

The GenAI Vanilla Stack uses a **microservices architecture** with Docker Compose orchestration and a **SOURCE-based configuration system** for flexible deployment.

### Core Design Principles

1. **Single Network**: All services communicate via `backend-bridge-network`
2. **Service Discovery**: Services use container names for internal communication
3. **Port Management**: BASE_PORT + offset pattern (default: 63000)
4. **Configuration**: SOURCE variables control service deployment modes
5. **Dependency Management**: Explicit `depends_on` declarations ensure proper startup order

## 🌐 Network Architecture

### Docker Network Configuration

```yaml
networks:
  backend-bridge-network:
    driver: bridge
```

All services connect to this single bridge network, enabling:
- **Service-to-Service Communication**: Using container names as hostnames
- **External Access**: Via mapped ports on the host
- **Network Isolation**: Services are isolated from the host network by default

### Service Communication Patterns

```
┌─────────────────────────────────────────────────────────────┐
│                        Host Machine                          │
│  Ports: 63000-63020                                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────▼──────────────────────────────┐
        │     backend-bridge-network (Docker)      │
        └──────────────────────────────────────────┘
                   │
    ┌──────────────┼──────────────────────────────┐
    │              │                              │
┌───▼───┐    ┌─────▼─────┐    ┌──────────▼──────────┐
│ Kong  │◄───│  Backend  │───►│  Supabase Services  │
│  :8000│    │   :8000   │    │    (DB, Auth...)    │
└───▲───┘    └─────▲─────┘    └─────────────────────┘
    │              │
    │         ┌────▼────┐
    │         │ Ollama  │
    │         │ :11434  │
    │         └─────────┘
    │
┌───▼────────────────┐
│ Open-WebUI, n8n,   │
│ ComfyUI, etc.      │
└────────────────────┘
```

### Internal Service URLs

Services communicate internally using these patterns:

```bash
# Database connections
postgresql://supabase-db:5432/postgres

# Redis
redis://redis:6379

# Ollama API
http://ollama:11434

# Backend API
http://backend:8000

# Kong Gateway (internal)
http://kong-api-gateway:8000

# Weaviate
http://weaviate:8080

# Neo4j
bolt://neo4j-graph-db:7687
```

## 🔧 Adding New Services

### Step 1: Define Service in docker-compose.yml

```yaml
my-new-service:
  image: my-service:latest
  container_name: ${PROJECT_NAME}-my-service
  restart: unless-stopped
  environment:
    # Service configuration
    DATABASE_URL: postgresql://${SUPABASE_DB_USER}:${SUPABASE_DB_PASSWORD}@supabase-db:5432/${SUPABASE_DB_NAME}
    REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
  ports:
    - "${MY_SERVICE_PORT}:8080"
  networks:
    - backend-bridge-network
  depends_on:
    supabase-db-init:
      condition: service_completed_successfully
  volumes:
    - my-service-data:/data
  deploy:
    replicas: ${MY_SERVICE_SCALE:-1}
```

### Step 2: Add to bootstrapper/service-configs.yml

```yaml
my-service:
  source_options:
    - container
    - localhost
    - disabled
  source_configs:
    container:
      scale: 1
      dependencies:
        - supabase-db
        - redis
    localhost:
      scale: 0
      external_url_required: false
      host_port: 8080
    disabled:
      scale: 0
```

### Step 3: Update Environment Variables

Add to `.env.example`:

```bash
# My New Service Configuration
MY_SERVICE_SOURCE=container  # Options: container, localhost, disabled
MY_SERVICE_IMAGE=my-service:latest
MY_SERVICE_PORT=63021  # BASE_PORT + 21
MY_SERVICE_SCALE=1
```

### Step 4: Configure Port Assignment

Update `bootstrapper/utils/port_manager.py`:

```python
PORT_ASSIGNMENTS = {
    # ... existing ports ...
    'MY_SERVICE_PORT': 21,  # Offset from BASE_PORT
}
```

### Step 5: Add Kong Routing (Optional)

Update `volumes/api/kong-dynamic.yml`:

```yaml
services:
  - name: my-service
    url: http://my-service:8080
    
routes:
  - name: my-service-route
    service: my-service
    paths:
      - /my-service
    strip_path: true
```

## 🔄 Service Dependency Patterns

### Database Dependencies

Most services depend on database initialization:

```yaml
depends_on:
  supabase-db-init:
    condition: service_completed_successfully
```

### AI Service Dependencies

AI services often need Ollama models:

```yaml
depends_on:
  ollama-pull:
    condition: service_completed_successfully
```

### Multi-Service Dependencies

Complex services may have multiple dependencies:

```yaml
depends_on:
  supabase-db-init:
    condition: service_completed_successfully
  redis:
    condition: service_healthy
  ollama:
    condition: service_started
```

## 🎯 Common Integration Patterns

### 1. Database Integration

```python
# Python service example
import asyncpg

DATABASE_URL = os.getenv('DATABASE_URL')
conn = await asyncpg.connect(DATABASE_URL)
```

### 2. Redis Integration

```python
import redis

r = redis.Redis(
    host='redis',
    port=6379,
    password=os.getenv('REDIS_PASSWORD'),
    decode_responses=True
)
```

### 3. Service-to-Service API Calls

```python
import httpx

# Call another service internally
async with httpx.AsyncClient() as client:
    response = await client.get('http://backend:8000/api/endpoint')
```

### 4. External Access via Kong

```python
# For external clients
response = requests.get('http://localhost:63002/backend/api/endpoint')
```

## 📊 Volume Management

### Persistent Data Volumes

```yaml
volumes:
  my-service-data:
    driver: local
```

### Shared Configuration

```yaml
volumes:
  - weaviate-shared-config:/shared  # Shared between services
```

### Host Mounts

```yaml
volumes:
  - ./my-service/config:/config  # Mount host directory
```

## 🔐 Security Considerations

### Network Security

1. **Internal Communication**: Services communicate over the Docker bridge network
2. **External Access**: Only exposed ports are accessible from host
3. **Service Isolation**: Each service runs in its own container

### Secret Management

```yaml
environment:
  API_KEY: ${MY_SERVICE_API_KEY}  # Store in .env file
```

### Health Checks

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## 🚀 Scaling Services

### Horizontal Scaling

```yaml
deploy:
  replicas: ${MY_SERVICE_SCALE:-1}
```

Control via environment:
```bash
MY_SERVICE_SCALE=3  # Run 3 instances
```

### Load Balancing

Kong automatically load balances between service replicas when multiple instances are running.

## 🔍 Service Discovery Methods

### 1. Container Name (Default)

```yaml
DATABASE_URL: postgresql://supabase-db:5432/postgres
```

### 2. Service Alias

```yaml
networks:
  backend-bridge-network:
    aliases:
      - my-service-alias
```

### 3. Extra Hosts (for localhost services)

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

## 📈 Monitoring & Observability

### View All Services

```bash
docker compose ps
```

### Check Network

```bash
docker network inspect genai_backend-bridge-network
```

### Service Logs

```bash
docker compose logs -f my-service
```

### Resource Usage

```bash
docker stats
```

## 🔄 Service Lifecycle

### Startup Order

1. **Infrastructure**: Database, Redis
2. **Initialization**: DB init, model pulling
3. **Core Services**: Auth, Storage, API
4. **AI Services**: Ollama, Weaviate, ComfyUI
5. **Application Layer**: Backend, Open-WebUI, n8n

### Graceful Shutdown

```bash
docker compose stop my-service  # Stop gracefully
docker compose down              # Stop and remove containers
```

## 🎨 Architecture Modification Examples

### Example 1: Adding Elasticsearch

```yaml
elasticsearch:
  image: elasticsearch:8.11.0
  container_name: ${PROJECT_NAME}-elasticsearch
  environment:
    - discovery.type=single-node
    - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  ports:
    - "${ELASTICSEARCH_PORT}:9200"
  networks:
    - backend-bridge-network
  volumes:
    - elasticsearch-data:/usr/share/elasticsearch/data
```

### Example 2: Adding Monitoring Stack

```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: ${PROJECT_NAME}-prometheus
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus-data:/prometheus
  ports:
    - "${PROMETHEUS_PORT}:9090"
  networks:
    - backend-bridge-network
    
grafana:
  image: grafana/grafana:latest
  container_name: ${PROJECT_NAME}-grafana
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  ports:
    - "${GRAFANA_PORT}:3000"
  networks:
    - backend-bridge-network
```

### Example 3: Adding Custom API Service

```yaml
custom-api:
  build: ./custom-api
  container_name: ${PROJECT_NAME}-custom-api
  environment:
    - NODE_ENV=production
    - DATABASE_URL=postgresql://${SUPABASE_DB_USER}:${SUPABASE_DB_PASSWORD}@supabase-db:5432/${SUPABASE_DB_NAME}
    - OLLAMA_URL=http://ollama:11434
  ports:
    - "${CUSTOM_API_PORT}:3000"
  networks:
    - backend-bridge-network
  depends_on:
    supabase-db-init:
      condition: service_completed_successfully
```

## 🔮 Future Architecture Considerations

### 1. Service Mesh
Consider adding Istio or Linkerd for advanced traffic management

### 2. Message Queue
Add RabbitMQ or Kafka for async communication

### 3. Distributed Tracing
Implement Jaeger or Zipkin for request tracing

### 4. Service Registry
Add Consul for dynamic service discovery

### 5. Multi-Network Architecture
Separate networks for different service tiers:
- Frontend network
- Backend network
- Data network

## 📚 Best Practices

1. **Always use container names** for internal communication
2. **Define health checks** for critical services
3. **Use depends_on** to ensure proper startup order
4. **Store secrets in .env** file, never in docker-compose.yml
5. **Use volumes** for persistent data
6. **Document port assignments** in the bootstrapper
7. **Test service integration** before deployment
8. **Monitor resource usage** and adjust limits as needed
9. **Keep services loosely coupled** for flexibility
10. **Version your service images** for rollback capability

## 🛠️ Troubleshooting

### Service Can't Connect to Database

```bash
# Check if database is running
docker compose ps supabase-db

# Test connection from service container
docker compose exec my-service pg_isready -h supabase-db -p 5432
```

### Service Not Accessible

```bash
# Check if port is mapped
docker compose ps my-service

# Check if service is listening
docker compose exec my-service netstat -tlpn
```

### Network Issues

```bash
# Inspect network
docker network inspect genai_backend-bridge-network

# Check if service is connected
docker inspect my-service | grep NetworkMode
```

---

This guide provides the foundation for understanding and extending the GenAI Vanilla Stack architecture. For specific service configurations, refer to the individual service documentation.
