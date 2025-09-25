import plotly.graph_objects as go
import plotly.io as pio

# Create figure
fig = go.Figure()

# Colors for current (red/orange) and recommended (green/blue)
current_colors = ['#DB4545', '#B4413C', '#964325']  # Red/orange tones
recommended_colors = ['#2E8B57', '#1FB8CD', '#5D878F']  # Green/blue tones

# Current setup (top section)
current_y = 8
client_positions = [(1, current_y), (3, current_y), (5, current_y), (7, current_y), (9, current_y), (11, current_y)]
clients = ["Claude Desktop", "Cursor", "Docker MCP", "VS Code", "Kiro", "Trae"]
configs = ["claude_config", "mcp.json", "docker_mcp", "vscode_mcp", "kiro-config", "trae-config"]
servers_count = [16, 5, 10, 0, 0, 0]

# Add current setup boxes and labels
for i, (x, y) in enumerate(client_positions):
    # Client box
    fig.add_shape(
        type="rect",
        x0=x-0.4, y0=y-0.3, x1=x+0.4, y1=y+0.3,
        fillcolor=current_colors[0],
        opacity=0.7,
        line=dict(color=current_colors[1], width=2)
    )
    fig.add_annotation(
        x=x, y=y,
        text=clients[i][:12],  # Limit to 12 chars
        showarrow=False,
        font=dict(size=10, color="white"),
        align="center"
    )
    
    # Config box below
    fig.add_shape(
        type="rect",
        x0=x-0.4, y0=y-1.3, x1=x+0.4, y1=y-0.7,
        fillcolor=current_colors[1],
        opacity=0.6,
        line=dict(color=current_colors[2], width=1)
    )
    fig.add_annotation(
        x=x, y=y-1,
        text=configs[i][:12],
        showarrow=False,
        font=dict(size=8, color="white"),
        align="center"
    )
    
    # Servers count annotation
    if servers_count[i] > 0:
        fig.add_annotation(
            x=x, y=y-1.8,
            text=f"{servers_count[i]} servers",
            showarrow=False,
            font=dict(size=8, color=current_colors[2]),
            align="center"
        )

# Current setup title
fig.add_annotation(
    x=6, y=9.5,
    text="Current Fragmented Setup",
    showarrow=False,
    font=dict(size=16, color=current_colors[0]),
    align="center"
)

# Recommended setup (bottom section)
recommended_y = 3
hub_x, hub_y = 6, 3

# MCP Hub/Gateway (central)
fig.add_shape(
    type="rect",
    x0=hub_x-1, y0=hub_y-0.5, x1=hub_x+1, y1=hub_y+0.5,
    fillcolor=recommended_colors[1],
    opacity=0.8,
    line=dict(color=recommended_colors[2], width=3)
)
fig.add_annotation(
    x=hub_x, y=hub_y,
    text="MCP Hub/Gateway",
    showarrow=False,
    font=dict(size=12, color="white"),
    align="center"
)

# Recommended clients positions (arranged around hub)
rec_clients = ["Claude Desktop", "Cursor", "Docker AI", "ChatGPT Desktop", "Perplexity", "VS Code", "Kiro", "Trae"]
rec_client_positions = [(2, 4.5), (4, 4.5), (8, 4.5), (10, 4.5), (2, 1.5), (4, 1.5), (8, 1.5), (10, 1.5)]

# Add recommended client boxes and connections
for i, (x, y) in enumerate(rec_client_positions):
    # Client box
    fig.add_shape(
        type="rect",
        x0=x-0.6, y0=y-0.3, x1=x+0.6, y1=y+0.3,
        fillcolor=recommended_colors[0],
        opacity=0.7,
        line=dict(color=recommended_colors[2], width=2)
    )
    fig.add_annotation(
        x=x, y=y,
        text=rec_clients[i][:12],
        showarrow=False,
        font=dict(size=9, color="white"),
        align="center"
    )
    
    # Connection line to hub
    fig.add_shape(
        type="line",
        x0=x, y0=y-0.3 if y > hub_y else y+0.3,
        x1=hub_x, y1=hub_y+0.5 if y > hub_y else hub_y-0.5,
        line=dict(color=recommended_colors[2], width=2)
    )

# Unified config box
fig.add_shape(
    type="rect",
    x0=hub_x-1, y0=hub_y-1.3, x1=hub_x+1, y1=hub_y-0.7,
    fillcolor=recommended_colors[2],
    opacity=0.6,
    line=dict(color=recommended_colors[0], width=2)
)
fig.add_annotation(
    x=hub_x, y=hub_y-1,
    text="Single Config",
    showarrow=False,
    font=dict(size=10, color="white"),
    align="center"
)

# MCP Servers (connected to hub)
servers = ["GitHub", "Azure DevOps", "Memory", "Docker", "Taskflow", "Context7", "Others"]
server_positions = [(0.5, 3), (1.5, 2.5), (11.5, 3), (10.5, 2.5), (0.5, 3.5), (11.5, 3.5), (6, 0.5)]

for i, (x, y) in enumerate(server_positions):
    fig.add_shape(
        type="rect",
        x0=x-0.4, y0=y-0.2, x1=x+0.4, y1=y+0.2,
        fillcolor=recommended_colors[2],
        opacity=0.5,
        line=dict(color=recommended_colors[0], width=1)
    )
    fig.add_annotation(
        x=x, y=y,
        text=servers[i][:10],
        showarrow=False,
        font=dict(size=8, color="white"),
        align="center"
    )
    
    # Connection to hub
    fig.add_shape(
        type="line",
        x0=x, y0=y,
        x1=hub_x, y1=hub_y,
        line=dict(color=recommended_colors[2], width=1, dash="dot")
    )

# Benefits annotations
benefits = ["Single Endpoint", "Unified Config", "Health Monitor", "Tool Namespace", "Real-time Update"]
benefit_positions = [(1, 0.2), (3, 0.2), (6, 0.2), (9, 0.2), (11, 0.2)]

for i, (x, y) in enumerate(benefit_positions):
    fig.add_annotation(
        x=x, y=y,
        text=benefits[i][:12],
        showarrow=False,
        font=dict(size=9, color=recommended_colors[0]),
        align="center",
        bgcolor="white",
        bordercolor=recommended_colors[0],
        borderwidth=1
    )

# Recommended setup title
fig.add_annotation(
    x=6, y=5.5,
    text="Recommended Centralized Architecture",
    showarrow=False,
    font=dict(size=16, color=recommended_colors[0]),
    align="center"
)

# Update layout
fig.update_layout(
    title="MCP Architecture Comparison",
    showlegend=False,
    xaxis=dict(range=[-0.5, 12], showgrid=False, showticklabels=False, zeroline=False),
    yaxis=dict(range=[-0.5, 10], showgrid=False, showticklabels=False, zeroline=False),
    plot_bgcolor='white',
    paper_bgcolor='white'
)

# Save the chart
fig.write_image("mcp_architecture_diagram.png", width=1200, height=800)
fig.show()