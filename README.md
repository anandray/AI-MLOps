# AI/MLOps Platform on Kubernetes

A comprehensive AI/MLOps platform on AWS EKS with support for training, inference, and agentic AI workloads.

## Architecture Overview

This platform provides:

- **AI/MLOps Foundation**: Model training, experiment tracking, model registry, feature stores
- **Agentic AI Frameworks**: CrewAI, LangGraph, AutoGen
- **Training Workloads**: Distributed training with hyperparameter optimization
- **Inference Workloads**: Real-time and batch inference with autoscaling
- **LLM Management**: Multiple backends with caching and optimization
- **GPU Management**: Mixed A100/H100 with Time-Slicing and MIG strategies

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── modules/           # Reusable Terraform modules
│   ├── environments/      # Environment-specific configurations
│   └── main.tf           # Root module
├── kubernetes/            # Kubernetes manifests
│   ├── gpu-operator/      # GPU Operator configuration
│   ├── training/          # Training job operators
│   ├── inference/         # Inference services
│   ├── agentic/           # Agentic AI frameworks
│   ├── mlops/             # MLOps tools (MLflow, W&B)
│   ├── monitoring/        # Prometheus, Grafana
│   └── networking/        # Service mesh (Linkerd)
├── docs/                  # Architecture and operational documentation
└── examples/              # Example deployments and configurations
```

## Quick Start

See [docs/architecture.md](docs/architecture.md) for detailed architecture.

See [docs/deployment.md](docs/deployment.md) for deployment instructions.

## Components

### Infrastructure
- AWS EKS cluster with mixed node pools
- NVIDIA GPU Operator with Time-Slicing and MIG
- High-performance storage (EFS, EBS)
- Linkerd service mesh

### AI/ML Components
- Training: PyTorch, TensorFlow with distributed training
- Inference: Triton, vLLM, Text Generation Inference
- MLOps: MLflow, Weights & Biases, Feature Stores
- Agentic: CrewAI, LangGraph, AutoGen

### Operations
- Monitoring: Prometheus + Grafana
- CI/CD: GitHub Actions + ArgoCD
- Autoscaling: KEDA, Cluster Autoscaler
- Security: Pod Security Policies, Network Policies

## License

MIT

