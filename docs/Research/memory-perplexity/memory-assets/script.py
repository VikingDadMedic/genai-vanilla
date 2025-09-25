# Create comprehensive comparison matrix data for memory frameworks
import pandas as pd

# Define the memory frameworks and their characteristics
frameworks_data = {
    'Framework': ['Mem0', 'memU', 'Memori', 'Zep/Graphiti'],
    
    # Core Architecture
    'Architecture_Type': [
        'Multi-level memory (user/session/agent)',
        'Autonomous Memory Agent + File System', 
        'Multi-agent memory capture/analysis',
        'Temporal Knowledge Graph'
    ],
    
    'Storage_Backend': [
        'Vector DB (Qdrant), SQL, NoSQL',
        'Knowledge Graph + Memory Files',
        'SQL (SQLite/PostgreSQL/MySQL)',
        'Neo4j Knowledge Graph'
    ],
    
    'Memory_Types': [
        'Long-term, Short-term, Semantic, Episodic',
        'Organized, Linked, Evolved, Prioritized',
        'Conscious (short-term), Auto (long-term), Combined',
        'Semantic, Episodic, Entity, Community'
    ],
    
    # Performance Benchmarks
    'Benchmark_Accuracy': [
        '26% improvement over OpenAI (LLM-as-Judge)',
        '92% accuracy (Locomo benchmark)',
        'Not specified in sources',
        '94.8% DMR, 18.5% improvement LongMemEval'
    ],
    
    'Latency_Performance': [
        '91% lower p95 latency vs full-context',
        'Not specified',
        'Sub-second retrieval',
        '90% latency reduction, <100ms queries'
    ],
    
    'Cost_Optimization': [
        '90% token cost savings',
        '90% cost reduction',
        'Not specified',
        '98% token reduction (2% vs baseline)'
    ],
    
    # Technical Capabilities
    'Temporal_Awareness': [
        'Limited temporal tracking',
        'Memory evolution and aging',
        'Not explicitly mentioned',
        'Bi-temporal model (event/ingestion time)'
    ],
    
    'Search_Capabilities': [
        'Semantic search, vector similarity',
        'Semantic, hybrid, contextual retrieval',
        'Intelligent search and recall',
        'Hybrid: semantic + BM25 + graph traversal'
    ],
    
    'Real_Time_Updates': [
        'Dynamic extraction and consolidation',
        'Autonomous memory management',
        'Automatic memory capture',
        'Real-time incremental updates'
    ],
    
    # Integration & Deployment
    'API_Approach': [
        'REST API, Python/JS SDKs',
        'Python client, Cloud API',
        'Python SDK (memorisdk)',
        'REST API, Python/TypeScript/Go SDKs'
    ],
    
    'Framework_Integration': [
        'LangChain, AutoGen, Embedchain',
        'AI companion focused',
        'LangChain, Agno, CrewAI',
        'LangChain, AutoGen, frameworks'
    ],
    
    'Deployment_Options': [
        'Self-hosted, Managed service',
        'Cloud, Enterprise, Community (planned)',
        'Self-hosted, GibsonAI infrastructure',
        'Self-hosted, Zep Cloud'
    ],
    
    # Specialization & Use Cases
    'Primary_Focus': [
        'General AI memory layer',
        'AI companion specialization',
        'AI agent memory engine',
        'Enterprise agent memory'
    ],
    
    'Target_Applications': [
        'Customer support, Healthcare, Learning',
        'AI companions, Role-playing, Tutors',
        'Multi-agent systems, Workflows',
        'Enterprise agents, Business data'
    ],
    
    'Multi_Tenant_Support': [
        'Yes (user/session isolation)',
        'Yes (companion-specific)',
        'Yes (user/agent isolation)',
        'Yes (enterprise multi-tenant)'
    ],
    
    # Development & Maturity
    'Open_Source_License': [
        'Apache 2.0',
        'Open source',
        'Apache 2.0',
        'Apache 2.0 (Graphiti)'
    ],
    
    'Maturity_Level': [
        'Production-ready, Research paper',
        'Emerging, Community building',
        'Production-ready, GibsonAI backed',
        'Production-ready, Academic validation'
    ],
    
    'Community_Size': [
        'Large GitHub community',
        'Growing Discord community',
        'Discord community, GitHub',
        'Established, Enterprise focus'
    ]
}

# Create DataFrame
df_comparison = pd.DataFrame(frameworks_data)

# Display the full comparison
print("=== AI Memory Frameworks Comprehensive Comparison ===")
print("\nFull Feature Comparison Matrix:")
print(df_comparison.to_string(index=False))

# Save to CSV for further analysis
df_comparison.to_csv('ai_memory_frameworks_comparison.csv', index=False)
print("\n✓ Saved detailed comparison to 'ai_memory_frameworks_comparison.csv'")