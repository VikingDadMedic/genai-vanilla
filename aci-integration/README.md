# ACI Integration

## 📚 Documentation

All documentation has been moved to the centralized docs folder:

- **Quick Start Guide**: [docs/aci-integration/readme.md](../docs/aci-integration/readme.md)
- **Integration Plan**: [docs/aci-integration/plan.md](../docs/aci-integration/plan.md)
- **Integration Guide**: [docs/aci-integration/integration-guide.md](../docs/aci-integration/integration-guide.md)
- **Final Summary**: [docs/aci-integration/final-integration-summary.md](../docs/aci-integration/final-integration-summary.md)

## 🚀 Quick Setup

```bash
# Run setup script
./setup-aci.sh

# Start services
docker compose -f docker-compose.yml -f docker-compose.aci.yml up -d

# Check health
./health-checks.sh
```

## 🔗 Access Points

- **ACI Portal**: http://localhost:63027
- **Services Dashboard**: http://localhost:63025/services-dashboard-v2.html
- **Documentation**: [../docs/README.md](../docs/README.md)
