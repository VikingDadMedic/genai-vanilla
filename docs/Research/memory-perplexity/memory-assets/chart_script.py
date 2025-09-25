import plotly.graph_objects as go
import json

# Data from the provided JSON
data = {
    "dimensions": ["Performance", "Cost Efficiency", "Ease of Integration", "Enterprise Readiness", "Real-time Capability", "Memory Intelligence", "Community Support", "Specialization"], 
    "Mem0": [8, 9, 9, 8, 8, 8, 9, 7], 
    "memU": [9, 9, 10, 6, 8, 9, 7, 10], 
    "Memori": [7, 7, 10, 8, 9, 8, 7, 8], 
    "Zep_Graphiti": [10, 10, 7, 10, 10, 9, 8, 9]
}

# Abbreviate dimension names to fit 15 character limit
abbreviated_dims = [
    "Performance",
    "Cost Efficiency", 
    "Integration",
    "Enterprise",
    "Real-time Cap",
    "Memory Intel",
    "Community Supp",
    "Specialization"
]

# Brand colors
colors = ["#1FB8CD", "#DB4545", "#2E8B57", "#5D878F"]

# Create radar chart
fig = go.Figure()

# Add traces for each framework
frameworks = ["Mem0", "memU", "Memori", "Zep/Graphiti"]
framework_data = [data["Mem0"], data["memU"], data["Memori"], data["Zep_Graphiti"]]

for i, (framework, scores) in enumerate(zip(frameworks, framework_data)):
    # Close the radar by adding first value at the end
    scores_closed = scores + [scores[0]]
    dims_closed = abbreviated_dims + [abbreviated_dims[0]]
    
    fig.add_trace(go.Scatterpolar(
        r=scores_closed,
        theta=dims_closed,
        fill='toself',
        name=framework,
        line=dict(color=colors[i], width=3),
        fillcolor=colors[i],
        opacity=0.1
    ))

# Update layout
fig.update_layout(
    title="Memory Framework Comparison",
    polar=dict(
        radialaxis=dict(
            visible=True,
            range=[0, 10],
            tickmode='linear',
            tick0=0,
            dtick=2
        )
    ),
    legend=dict(
        orientation='h',
        yanchor='bottom',
        y=1.05,
        xanchor='center',
        x=0.5
    )
)

# Update traces
fig.update_traces(cliponaxis=False)

# Save the chart
fig.write_image("memory_framework_radar_chart.png")