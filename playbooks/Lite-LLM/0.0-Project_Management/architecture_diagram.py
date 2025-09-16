#!/usr/bin/env python3
"""
Generate architecture diagram for LiteLLM deployment
Requires: pip install matplotlib
"""

import os
import sys
import traceback
from pathlib import Path

# Check for matplotlib dependency
try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches
    from matplotlib.patches import FancyBboxPatch, ConnectionPatch
    import matplotlib.lines as mlines
except ImportError as e:
    print(f"Error: Missing required dependency - {e}")
    print("\nPlease install matplotlib to run this script:")
    print("  pip install matplotlib")
    print("\nOr if using a virtual environment:")
    print("  python -m pip install matplotlib")
    sys.exit(1)

# Main function to generate diagram
def generate_diagram():
    # Create figure and axis
    fig, ax = plt.subplots(1, 1, figsize=(14, 10))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # Title
    plt.title('HX Infrastructure - LiteLLM API Gateway Architecture', fontsize=18, fontweight='bold', pad=20)

    # Color scheme
    color_client = '#E8F4FD'
    color_gateway = '#B8E0D2'
    color_backend = '#D6EAF8'
    color_model = '#FAD7A0'
    color_arrow = '#5D6D7E'

    # Draw components
    # Clients layer
    clients = [
        {'name': 'Development\nTeams', 'x': 1, 'y': 7},
        {'name': 'Engineering\nTeams', 'x': 4, 'y': 7},
        {'name': 'Open WebUI', 'x': 7, 'y': 7},
        {'name': 'API Clients', 'x': 10, 'y': 7}
    ]

    for client in clients:
        box = FancyBboxPatch((client['x']-0.8, client['y']-0.4), 1.6, 0.8, 
                             boxstyle="round,pad=0.1", 
                             facecolor=color_client, 
                             edgecolor='black', 
                             linewidth=1.5)
        ax.add_patch(box)
        ax.text(client['x'], client['y'], client['name'], 
                ha='center', va='center', fontsize=10, fontweight='bold')

    # API Gateway layer
    gateway_box = FancyBboxPatch((2, 4.5), 8, 1.5, 
                                boxstyle="round,pad=0.1", 
                                facecolor=color_gateway, 
                                edgecolor='black', 
                                linewidth=2)
    ax.add_patch(gateway_box)
    ax.text(6, 5.5, 'LiteLLM API Gateway', ha='center', va='center', fontsize=14, fontweight='bold')
    ax.text(6, 5.1, 'hx-api-server.dev-test.hana-x.ai:4000', ha='center', va='center', fontsize=10, style='italic')
    ax.text(6, 4.7, 'OpenAI-Compatible REST API', ha='center', va='center', fontsize=9)

    # Features box
    features_box = FancyBboxPatch((11, 4.5), 2.5, 1.5, 
                                 boxstyle="round,pad=0.1", 
                                 facecolor='white', 
                                 edgecolor='gray', 
                                 linewidth=1, 
                                 linestyle='--')
    ax.add_patch(features_box)
    ax.text(12.25, 5.6, 'Features:', ha='center', va='center', fontsize=9, fontweight='bold')
    ax.text(12.25, 5.3, '• Authentication', ha='center', va='center', fontsize=8)
    ax.text(12.25, 5.0, '• Load Balancing', ha='center', va='center', fontsize=8)
    ax.text(12.25, 4.7, '• Rate Limiting', ha='center', va='center', fontsize=8)

    # Ollama Backend Servers
    backend1_box = FancyBboxPatch((1, 2), 5, 1.5, 
                                 boxstyle="round,pad=0.1", 
                                 facecolor=color_backend, 
                                 edgecolor='black', 
                                 linewidth=1.5)
    ax.add_patch(backend1_box)
    ax.text(3.5, 3.1, 'Ollama Backend Server 1', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(3.5, 2.7, 'hx-llm01-server:11434', ha='center', va='center', fontsize=9, style='italic')
    ax.text(3.5, 2.3, '(Primary)', ha='center', va='center', fontsize=9)

    backend2_box = FancyBboxPatch((7, 2), 5, 1.5, 
                                 boxstyle="round,pad=0.1", 
                                 facecolor=color_backend, 
                                 edgecolor='black', 
                                 linewidth=1.5)
    ax.add_patch(backend2_box)
    ax.text(9.5, 3.1, 'Ollama Backend Server 2', ha='center', va='center', fontsize=12, fontweight='bold')
    ax.text(9.5, 2.7, 'hx-llm02-server:11434', ha='center', va='center', fontsize=9, style='italic')
    ax.text(9.5, 2.3, '(Secondary)', ha='center', va='center', fontsize=9)

    # Models
    models = [
        {'name': 'phi3\n3.8b', 'x': 1.5},
        {'name': 'llama3\n8b', 'x': 2.8},
        {'name': 'llama3.1\n8b', 'x': 4.1},
        {'name': 'mistral\n7b', 'x': 5.4},
        {'name': 'gemma2\n9b', 'x': 7.5},
        {'name': 'phi3\n3.8b', 'x': 8.8},
        {'name': 'llama3\n8b', 'x': 10.1},
        {'name': 'llama3.1\n8b', 'x': 11.4}
    ]

    y_model = 0.5
    for i, model in enumerate(models):
        if i == 5:  # Visual separator between backends
            ax.plot([6.7, 6.7], [0, 1.5], 'k--', alpha=0.3, linewidth=1)
        
        model_box = FancyBboxPatch((model['x']-0.5, y_model-0.3), 1, 0.6, 
                                  boxstyle="round,pad=0.05", 
                                  facecolor=color_model, 
                                  edgecolor='black', 
                                  linewidth=1)
        ax.add_patch(model_box)
        ax.text(model['x'], y_model, model['name'], 
                ha='center', va='center', fontsize=8)

    # Arrows - Clients to Gateway
    for client in clients:
        arrow = patches.FancyArrowPatch((client['x'], client['y']-0.5), 
                                       (client['x'], 6.2),
                                       connectionstyle="arc3,rad=0", 
                                       arrowstyle='->', 
                                       color=color_arrow, 
                                       linewidth=1.5,
                                       mutation_scale=20)
        ax.add_patch(arrow)

    # Arrows - Gateway to Backends (with load balancing indication)
    # To Backend 1
    arrow1 = patches.FancyArrowPatch((4, 4.4), (3.5, 3.7),
                                    connectionstyle="arc3,rad=-.2", 
                                    arrowstyle='->', 
                                    color=color_arrow, 
                                    linewidth=2,
                                    mutation_scale=20)
    ax.add_patch(arrow1)

    # To Backend 2
    arrow2 = patches.FancyArrowPatch((8, 4.4), (9.5, 3.7),
                                    connectionstyle="arc3,rad=.2", 
                                    arrowstyle='->', 
                                    color=color_arrow, 
                                    linewidth=2,
                                    mutation_scale=20)
    ax.add_patch(arrow2)

    # Load balancing indicator
    ax.text(6, 3.8, 'Least-Busy\nRouting', ha='center', va='center', 
            fontsize=10, style='italic', bbox=dict(boxstyle="round,pad=0.3", 
            facecolor='white', edgecolor='gray'))

    # Arrows - Backends to Models
    # Backend 1 to its models
    for i in range(5):
        x = models[i]['x']
        arrow = patches.FancyArrowPatch((x, 1.9), (x, 1.1),
                                       connectionstyle="arc3,rad=0", 
                                       arrowstyle='->', 
                                       color=color_arrow, 
                                       linewidth=1,
                                       mutation_scale=15,
                                       alpha=0.7)
        ax.add_patch(arrow)

    # Backend 2 to its models
    for i in range(5, len(models)):
        x = models[i]['x']
        arrow = patches.FancyArrowPatch((x, 1.9), (x, 1.1),
                                       connectionstyle="arc3,rad=0", 
                                       arrowstyle='->', 
                                       color=color_arrow, 
                                       linewidth=1,
                                       mutation_scale=15,
                                       alpha=0.7)
        ax.add_patch(arrow)

    # Add protocol labels
    ax.text(1, 8.5, 'HTTPS/REST', ha='center', va='center', fontsize=9, 
            bbox=dict(boxstyle="round,pad=0.2", facecolor='yellow', alpha=0.7))
    ax.text(6, 4, 'HTTP/REST', ha='center', va='center', fontsize=9, 
            bbox=dict(boxstyle="round,pad=0.2", facecolor='yellow', alpha=0.7))

    # Add legend
    legend_elements = [
        mlines.Line2D([0], [0], marker='o', color='w', label='Client Applications',
                      markerfacecolor=color_client, markersize=10, markeredgecolor='black'),
        mlines.Line2D([0], [0], marker='o', color='w', label='API Gateway',
                      markerfacecolor=color_gateway, markersize=10, markeredgecolor='black'),
        mlines.Line2D([0], [0], marker='o', color='w', label='Ollama Backends',
                      markerfacecolor=color_backend, markersize=10, markeredgecolor='black'),
        mlines.Line2D([0], [0], marker='o', color='w', label='LLM Models',
                      markerfacecolor=color_model, markersize=10, markeredgecolor='black')
    ]
    ax.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), frameon=True)

    # Add notes
    notes = """
Key Features:
• OpenAI-compatible API
• Automatic failover
• Model load balancing
• API key authentication
• Request routing
"""
    ax.text(13.5, 8.5, notes, ha='left', va='top', fontsize=8,
            bbox=dict(boxstyle="round,pad=0.4", facecolor='lightyellow', edgecolor='gray'))

    # Save the diagram
    # Compute relative output directory
    output_dir = Path(__file__).resolve().parent
    output_dir.mkdir(parents=True, exist_ok=True)

    # Define output paths
    png_path = output_dir / "litellm_architecture.png"
    pdf_path = output_dir / "litellm_architecture.pdf"

    plt.tight_layout()
    plt.savefig(png_path, 
                dpi=300, bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.savefig(pdf_path, 
                format='pdf', bbox_inches='tight', facecolor='white', edgecolor='none')

    print("Architecture diagrams saved:")
    print(f"- {png_path.name}")
    print(f"- {pdf_path.name}")


# Main execution with error handling
if __name__ == "__main__":
    try:
        print("Generating LiteLLM architecture diagram...")
        generate_diagram()
        print("\nDiagram generation completed successfully!")
        sys.exit(0)
    except Exception as e:
        print(f"\nError during diagram generation: {type(e).__name__}: {e}")
        print("\nDetailed traceback:")
        traceback.print_exc()
        sys.exit(1)