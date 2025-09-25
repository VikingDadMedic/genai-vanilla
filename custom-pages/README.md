# Custom Pages Directory

This directory contains custom HTML pages and dashboards for the GenAI Vanilla Stack.

## Available Pages

### 1. Services Dashboard (`services-dashboard.html`)
A comprehensive dashboard providing quick access to all services in the stack.

**Features:**
- Real-time service status indicators
- Color-coded service categories
- Quick access links to all services
- Configuration summary
- Default credentials display
- Mobile-responsive design

**Usage:**
Open `services-dashboard.html` in your browser or access via:
```bash
open custom-pages/services-dashboard.html
```

## Future Pages (Planned)

### 2. System Metrics Dashboard
- Real-time resource usage (CPU, Memory, GPU)
- Service health monitoring
- Performance metrics visualization

### 3. Research Hub
- Research history viewer
- Saved queries management
- Results comparison tool

### 4. Model Management Interface
- Active models overview
- Model performance comparison
- Quick model switching interface

### 5. Workflow Designer
- Visual workflow creation for n8n
- ComfyUI workflow templates
- Integration testing tools

## Development Guidelines

When creating new custom pages:

1. **Consistency**: Use similar styling and structure as existing pages
2. **Self-contained**: Include all CSS/JS inline or use CDN links
3. **Documentation**: Update this README with new pages
4. **Configuration**: Use environment variables where possible
5. **Responsive**: Ensure mobile compatibility

## Adding New Pages

1. Create your HTML file in this directory
2. Follow the naming convention: `feature-name.html`
3. Update this README with description and usage
4. Test on multiple browsers and devices
5. Consider adding to `.gitignore` if it contains sensitive data

## Notes

- These pages are static HTML for simplicity and portability
- They can be served via any web server or opened directly
- For production, consider serving through Kong or a dedicated web server
- Keep sensitive information (API keys, passwords) out of these files
