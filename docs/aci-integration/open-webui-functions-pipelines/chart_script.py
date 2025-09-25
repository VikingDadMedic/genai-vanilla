import plotly.graph_objects as go
import plotly.express as px
import json
import pandas as pd

# Data from the architecture JSON
architecture_data = {
    "architecture": {
        "user_interface": "SvelteKit Frontend", 
        "core_server": "FastAPI Backend", 
        "functions": {
            "location": "Internal", 
            "types": ["Tools", "Pipe Functions", "Filter Functions", "Action Functions"]
        }, 
        "pipelines": {
            "location": "External Server", 
            "types": ["Pipe", "Filter", "Manifold"]
        }, 
        "data_flow": ["User Request", "Functions Processing", "Pipeline Processing", "LLM/External API", "Response Processing", "User Response"]
    }, 
    "connections": {
        "user_to_webui": "HTTP/WebSocket", 
        "webui_to_functions": "Internal calls", 
        "webui_to_pipelines": "HTTP API (port 9099)", 
        "pipelines_to_llm": "Various APIs"
    }
}

# Create the figure
fig = go.Figure()

# Define positions and components
components = [
    # Layer 1: User
    {"name": "User", "x": 1, "y": 3, "color": "#1FB8CD", "size": 60},
    
    # Layer 2: Open WebUI
    {"name": "SvelteKit<br>Frontend", "x": 3, "y": 4, "color": "#DB4545", "size": 50},
    {"name": "FastAPI<br>Backend", "x": 3, "y": 2, "color": "#DB4545", "size": 50},
    
    # Layer 3: Functions (Internal)
    {"name": "Tools", "x": 5, "y": 4.5, "color": "#2E8B57", "size": 40},
    {"name": "Pipe Func", "x": 5, "y": 3.5, "color": "#2E8B57", "size": 40},
    {"name": "Filter Func", "x": 5, "y": 2.5, "color": "#2E8B57", "size": 40},
    {"name": "Action Func", "x": 5, "y": 1.5, "color": "#2E8B57", "size": 40},
    
    # Layer 4: Pipelines Server
    {"name": "Pipe Pipeline", "x": 7, "y": 4, "color": "#5D878F", "size": 45},
    {"name": "Filter Pipeline", "x": 7, "y": 3, "color": "#5D878F", "size": 45},
    {"name": "Manifold", "x": 7, "y": 2, "color": "#5D878F", "size": 45},
    
    # Layer 5: External Services
    {"name": "LLM/External<br>Services", "x": 9, "y": 3, "color": "#D2BA4C", "size": 60}
]

# Add components to the plot
for comp in components:
    fig.add_trace(go.Scatter(
        x=[comp["x"]], 
        y=[comp["y"]], 
        mode='markers+text',
        marker=dict(size=comp["size"], color=comp["color"], line=dict(width=2, color='white')),
        text=comp["name"],
        textposition="middle center",
        textfont=dict(size=10, color='white', family='Arial Black'),
        showlegend=False,
        hoverinfo='none'
    ))

# Define connections with arrows
connections = [
    # User to Frontend
    {"start": (1, 3), "end": (3, 4), "text": "HTTP/WebSocket"},
    # User to Backend  
    {"start": (1, 3), "end": (3, 2), "text": ""},
    # Frontend to Backend
    {"start": (3, 4), "end": (3, 2), "text": ""},
    # Backend to Functions
    {"start": (3, 2), "end": (5, 4.5), "text": "Internal calls"},
    {"start": (3, 2), "end": (5, 3.5), "text": ""},
    {"start": (3, 2), "end": (5, 2.5), "text": ""},
    {"start": (3, 2), "end": (5, 1.5), "text": ""},
    # Functions to Pipelines
    {"start": (5, 4.5), "end": (7, 4), "text": "HTTP API<br>9099"},
    {"start": (5, 3.5), "end": (7, 3), "text": ""},
    {"start": (5, 2.5), "end": (7, 2), "text": ""},
    # Pipelines to LLM
    {"start": (7, 4), "end": (9, 3), "text": "Various APIs"},
    {"start": (7, 3), "end": (9, 3), "text": ""},
    {"start": (7, 2), "end": (9, 3), "text": ""}
]

# Add arrows for connections
for conn in connections:
    start_x, start_y = conn["start"]
    end_x, end_y = conn["end"]
    
    fig.add_annotation(
        x=end_x, y=end_y,
        ax=start_x, ay=start_y,
        xref='x', yref='y',
        axref='x', ayref='y',
        arrowhead=2,
        arrowsize=1.5,
        arrowwidth=2,
        arrowcolor='#666666',
        showarrow=True
    )
    
    # Add connection labels for key connections
    if conn["text"]:
        mid_x = (start_x + end_x) / 2
        mid_y = (start_y + end_y) / 2
        fig.add_annotation(
            x=mid_x, y=mid_y + 0.2,
            text=conn["text"],
            showarrow=False,
            font=dict(size=8, color='#333333'),
            bgcolor='white',
            bordercolor='#cccccc',
            borderwidth=1
        )

# Add layer labels
layer_labels = [
    {"text": "User Layer", "x": 1, "y": 5.2, "color": "#1FB8CD"},
    {"text": "Open WebUI", "x": 3, "y": 5.2, "color": "#DB4545"},
    {"text": "Functions", "x": 5, "y": 5.2, "color": "#2E8B57"},
    {"text": "Pipelines", "x": 7, "y": 5.2, "color": "#5D878F"},
    {"text": "External", "x": 9, "y": 5.2, "color": "#D2BA4C"}
]

for label in layer_labels:
    fig.add_annotation(
        x=label["x"], y=label["y"],
        text=label["text"],
        showarrow=False,
        font=dict(size=12, color=label["color"], family='Arial Black'),
        bgcolor='rgba(255,255,255,0.8)',
        bordercolor=label["color"],
        borderwidth=2
    )

# Update layout
fig.update_layout(
    title="Open WebUI Plugin Architecture",
    xaxis=dict(range=[0, 10], showgrid=False, showticklabels=False, zeroline=False),
    yaxis=dict(range=[0, 6], showgrid=False, showticklabels=False, zeroline=False),
    plot_bgcolor='rgba(0,0,0,0)',
    paper_bgcolor='white'
)

fig.update_traces(cliponaxis=False)

# Save the chart
fig.write_image("open_webui_architecture.png", width=1200, height=800, scale=2)