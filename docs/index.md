# nf-proteindesign

!!! warning "Proof of Principle Pipeline"
    This pipeline was developed by Seqera as a proof of principle using Seqera AI. It demonstrates the capabilities of AI-assisted bioinformatics pipeline development but should be thoroughly validated before use in production environments.

<div style="text-align: center; margin: 2rem 0;">
  <img src="https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg" alt="Nextflow">
  <img src="https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker" alt="Docker">
</div>

## :material-test-tube: Overview

**nf-proteindesign** is a powerful Nextflow pipeline for running [Boltzgen](https://github.com/HannesStark/boltzgen) protein design workflows in parallel across multiple design specifications. Boltzgen is an all-atom generative diffusion model that can design proteins, peptides, and nanobodies to bind various biomolecular targets including proteins, nucleic acids, and small molecules.

!!! tip "Unified Workflow Architecture"
## :octicons-workflow-24: Pipeline Modes

<div class="feature-grid">
  <div class="feature-card">
    <h3>📄 Design Mode</h3>
    <p>Use pre-made design YAML files for complete control over design specifications.</p>
    <code>--mode design</code>
  </div>
  
  <div class="feature-card">
    <h3>🎯 Target Mode</h3>
    <p>Automatically generate design variants from target structures with configurable parameters.</p>
    <code>--mode target</code>
  </div>
  
  <div class="feature-card">
    <h3>🔬 </h3>
    <p>Use machine learning to identify binding sites and automatically design binders.</p>
  </div>
</div>

## :material-lightning-bolt: Key Features

- **:material-parallel: Parallel Processing**: Run multiple design specifications simultaneously
- **:material-tune-variant: Flexible Modes**: two operational modes with automatic detection
- **:material-chart-line: Comprehensive Analysis**: Optional IPSAE scoring and PRODIGY binding affinity prediction
- **:material-docker: Container Support**: Full Docker compatibility
- **:material-gpu: GPU Acceleration**: Optimized for NVIDIA GPU execution
- **:material-file-tree: Organized Outputs**: Structured results with intermediate files and metrics

## :material-pipeline: Pipeline Workflow

```mermaid
flowchart TD
    A[📋 Input Samplesheet CSV] --> B{Mode Selection}
    B -->|--mode design| C1[📄 Design Mode]
    B -->|--mode target| C2[🎯 Target Mode]
    B -->|--mode  C3[🔬 ]
    
    C1 --> D1[Use Pre-made<br/>Design YAMLs]
    C2 --> D2[Generate Design<br/>Variants from Target]
    
    D1 --> E[🔀 Unified Workflow Entry]
    D2 --> E
    D3 --> E
    
    E --> F[📦 Parallel Design Processing]
    F --> G[⚡ BOLTZGEN Design Generation]
    G --> H{Optional Analysis}
    H -->|IPSAE| I[📊 Interaction Scoring]
    H -->|PRODIGY| J[⚡ Affinity Prediction]
    I --> K[✅ Final Results]
    J --> K
    H -->|None| K
    
    style B fill:#E1BEE7
    style C1 fill:#CE93D8
    style C2 fill:#BA68C8
    style C3 fill:#AB47BC
    style E fill:#9C27B0,color:#fff
    style K fill:#8E24AA,color:#fff
```

## :material-rocket-launch: Quick Start

Get started with nf-proteindesign in minutes:

```bash
# 1. Install Nextflow (>=23.04.0)
curl -s https://get.nextflow.io | bash

# 2. Run the pipeline
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

!!! example "Need Help?"
    Check out the [Quick Start Guide](quick-start.md) for detailed setup instructions and examples.

## :material-chemical-weapon: What Can You Design?

The pipeline leverages Boltzgen's capabilities to design:

- **Proteins**: Full-length protein binders targeting specific interfaces
- **Peptides**: Short peptide sequences for tight binding
- **Nanobodies**: Compact antibody fragments for therapeutic applications
- **Multi-target Binders**: Design to multiple targets simultaneously

All with the flexibility to specify:
- Binding site residues
- Designed chain type (protein, peptide, nanobody)
- Chain length constraints
- Custom diffusion parameters

## :material-file-document: Documentation Structure

<div class="feature-grid">
  <div class="feature-card">
    <h3>Getting Started</h3>
    <p>Installation, basic usage, and quick reference guides.</p>
  </div>
  
  <div class="feature-card">
    <h3>Pipeline Modes</h3>
    <p>Detailed documentation for each operational mode.</p>
  </div>
  
  <div class="feature-card">
    <h3>Analysis Tools</h3>
    <p>PRODIGY and ipSAE integration guides.</p>
  </div>
  
  <div class="feature-card">
    <h3>Architecture</h3>
    <p>Technical details and implementation notes.</p>
  </div>
</div>

## :material-server: Computing Requirements

!!! info "Hardware Requirements"
    **GPU**: NVIDIA GPU with CUDA support (recommended for reasonable execution times)  
    **Memory**: Minimum 16GB RAM, 32GB+ recommended for large designs  
    **Storage**: 50GB+ for pipeline dependencies and outputs

## :octicons-people-24: Contributing

We welcome contributions! The pipeline is designed with modularity and extensibility in mind.

## :material-license: License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/seqeralabs/nf-proteindesign/blob/main/LICENSE) file for details.

---

<div style="text-align: center; margin-top: 3rem; color: #666;">
  Built with :material-heart: using Nextflow and Material for MkDocs
</div>
