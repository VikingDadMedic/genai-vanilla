import plotly.graph_objects as go
import json

# Data from the provided JSON
data = {
    "comparison": {
        "dimensions": ["Performance", "Setup Simplicity", "Resource Efficiency", "Scalability", "Feature Richness"],
        "functions": {"Performance": 9, "Setup Simplicity": 10, "Resource Efficiency": 8, "Scalability": 4, "Feature Richness": 6},
        "pipelines": {"Performance": 6, "Setup Simplicity": 3, "Resource Efficiency": 5, "Scalability": 10, "Feature Richness": 10}
    }
}

# Extract dimensions and scores
dimensions = data["comparison"]["dimensions"]
functions_scores = [data["comparison"]["functions"][dim] for dim in dimensions]
pipelines_scores = [data["comparison"]["pipelines"][dim] for dim in dimensions]

# Abbreviate dimension names to stay under 15 characters
abbrev_dimensions = ["Performance", "Setup Simple", "Resource Eff", "Scalability", "Feature Rich"]

# Create radar chart
fig = go.Figure()

# Add Functions trace
fig.add_trace(go.Scatterpolar(
    r=functions_scores,
    theta=abbrev_dimensions,
    fill='toself',
    name='Functions',
    line_color='#1FB8CD',
    fillcolor='rgba(31, 184, 205, 0.2)'
))

# Add Pipelines trace  
fig.add_trace(go.Scatterpolar(
    r=pipelines_scores,
    theta=abbrev_dimensions,
    fill='toself',
    name='Pipelines',
    line_color='#DB4545',
    fillcolor='rgba(219, 69, 69, 0.2)'
))

# Update layout
fig.update_layout(
    title='Functions vs Pipelines Comparison',
    polar=dict(
        radialaxis=dict(
            visible=True,
            range=[0, 10],
            tickvals=[2, 4, 6, 8, 10]
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

# Save the chart
fig.write_image("functions_vs_pipelines_radar.png")
fig.show()