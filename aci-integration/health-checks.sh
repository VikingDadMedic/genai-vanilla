#!/bin/bash

# Health Check Script for ACI Platform Services
# Monitors all ACI services and reports their status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 ACI Platform Health Check${NC}"
echo "================================"

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_response=$3
    
    echo -n "Checking $service_name... "
    
    if curl -s -f -o /dev/null "$url" 2>/dev/null; then
        echo -e "${GREEN}✅ Healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ Unhealthy${NC}"
        return 1
    fi
}

# Function to check Docker container status
check_container() {
    local container_name=$1
    
    echo -n "Container $container_name... "
    
    if docker ps | grep -q "$container_name"; then
        status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "running")
        if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
            echo -e "${GREEN}✅ Running${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  $status${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Not running${NC}"
        return 1
    fi
}

# Track overall health
HEALTHY=0
UNHEALTHY=0

echo -e "\n${YELLOW}1. Core ACI Services${NC}"
echo "------------------------"

# Check ACI Backend
if check_service "ACI Backend API" "http://localhost:63026/v1/health"; then
    ((HEALTHY++))
else
    ((UNHEALTHY++))
fi

# Check ACI Frontend Portal
if check_service "ACI Portal" "http://localhost:63027"; then
    ((HEALTHY++))
else
    ((UNHEALTHY++))
fi

# Check MCP Servers
if check_service "MCP Apps Server" "http://localhost:63028/health"; then
    ((HEALTHY++))
else
    ((UNHEALTHY++))
fi

if check_service "MCP Unified Server" "http://localhost:63029/health"; then
    ((HEALTHY++))
else
    ((UNHEALTHY++))
fi

# Check LocalStack KMS
if check_service "LocalStack KMS" "http://localhost:63030/_localstack/health"; then
    ((HEALTHY++))
else
    ((UNHEALTHY++))
fi

echo -e "\n${YELLOW}2. Container Status${NC}"
echo "------------------------"

# Check Docker containers
containers=(
    "genai-aci-backend"
    "genai-aci-frontend"
    "genai-aci-mcp-apps"
    "genai-aci-mcp-unified"
    "genai-localstack-kms"
)

for container in "${containers[@]}"; do
    if check_container "$container"; then
        ((HEALTHY++))
    else
        ((UNHEALTHY++))
    fi
done

echo -e "\n${YELLOW}3. Integration Points${NC}"
echo "------------------------"

# Check Open WebUI integration
echo -n "Open WebUI ACI Bridge... "
if docker exec genai-open-web-ui ls /app/backend/data/functions/aci_selfhosted_bridge.py &>/dev/null; then
    echo -e "${GREEN}✅ Installed${NC}"
    ((HEALTHY++))
else
    echo -e "${RED}❌ Not installed${NC}"
    ((UNHEALTHY++))
fi

# Check database schema
echo -n "ACI Database Schema... "
if docker exec genai-supabase-db psql -U supabase_admin -d postgres -c "\dn" | grep -q "aci" &>/dev/null; then
    echo -e "${GREEN}✅ Created${NC}"
    ((HEALTHY++))
else
    echo -e "${RED}❌ Not created${NC}"
    ((UNHEALTHY++))
fi

echo -e "\n${YELLOW}4. Tool Availability${NC}"
echo "------------------------"

# Check available tools
if [ $UNHEALTHY -eq 0 ]; then
    echo -n "Fetching available tools... "
    tool_count=$(curl -s "http://localhost:63026/v1/apps" 2>/dev/null | grep -o '"name"' | wc -l || echo "0")
    if [ "$tool_count" -gt 0 ]; then
        echo -e "${GREEN}✅ $tool_count apps available${NC}"
    else
        echo -e "${YELLOW}⚠️  No tools configured yet${NC}"
    fi
fi

echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Healthy services: ${GREEN}$HEALTHY${NC}"
echo -e "  Unhealthy services: ${RED}$UNHEALTHY${NC}"

if [ $UNHEALTHY -eq 0 ]; then
    echo -e "\n${GREEN}✨ All ACI services are healthy!${NC}"
    echo -e "\nNext steps:"
    echo "1. Access ACI Portal: http://localhost:63027"
    echo "2. Configure your first tool integration"
    echo "3. Test in Open WebUI: http://localhost:63015"
else
    echo -e "\n${YELLOW}⚠️  Some services need attention${NC}"
    echo -e "\nTroubleshooting:"
    echo "1. Check if setup script was run: cd aci-integration && ./setup-aci.sh"
    echo "2. Start ACI services: docker compose -f docker-compose.yml -f aci-integration/docker-compose.aci.yml up -d"
    echo "3. Check logs: docker compose logs aci-backend"
fi

echo -e "${BLUE}================================${NC}"

# Exit with appropriate code
if [ $UNHEALTHY -gt 0 ]; then
    exit 1
else
    exit 0
fi
