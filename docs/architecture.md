# High-Level Architecture

## Overview

This document describes the architecture of the AI/MLOps platform running on AWS EKS with mixed GPU node pools.

> **📊 Interactive Diagrams**: For comprehensive visual diagrams including system architecture, component interactions, data flows, and deployment pipelines, see [system-architecture-diagram.md](./system-architecture-diagram.md).

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    EKS Control Plane                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Node Pools                             │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│  │  │  CPU Pool    │  │  A100 Pool   │  │  H100 Pool   │    │  │
│  │  │              │  │              │  │              │    │  │
│  │  │ - Control    │  │ - Time-Slice │  │ - Time-Slice │    │  │
│  │  │ - MLOps      │  │ - MIG        │  │ - Training   │    │  │
│  │  │ - Agents     │  │ - Inference  │  │ - Fine-tune  │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Storage Layer                          │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│  │  │     EFS      │  │     EBS      │  │     S3       │    │  │
│  │  │              │  │              │  │              │    │  │
│  │  │ - Datasets   │  │ - Checkpoints│  │ - Artifacts  │    │  │
│  │  │ - Models     │  │ - Cache      │  │ - Logs       │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Networking                             │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│  │  │   Linkerd    │  │   ALB/NLB    │  │   VPC CNI    │    │  │
│  │  │ Service Mesh │  │ Load Balancer│  │   Networking │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Node Pool Strategy

### CPU Node Pool
- **Purpose**: Control plane, MLOps tools, agentic frameworks (CPU-only)
- **Instance Types**: `m5.2xlarge`, `m5.4xlarge`
- **Labels**: `workload-type=control`, `workload-type=mlops`
- **Taints**: None (default pool)

### A100 Node Pool (Time-Slicing)
- **Purpose**: Research, development, training, batch inference
- **Instance Types**: `p4d.24xlarge` (8x A100 40GB) or `p5.48xlarge` (8x A100 80GB)
- **GPU Sharing**: Time-Slicing (2-4 replicas per GPU)
- **Labels**: 
  - `workload-type=research`
  - `workload-type=training`
  - `workload-type=development`
  - `workload-type=batch-inference`
- **Taints**: `gpu=true:NoSchedule` (optional)

### A100 Node Pool (MIG)
- **Purpose**: Production inference, critical agents
- **Instance Types**: `p5.48xlarge` (8x A100 80GB)
- **GPU Sharing**: MIG (1g.10gb, 2g.20gb, 3g.40gb profiles)
- **Labels**: 
  - `workload-type=production-inference`
  - `workload-type=critical-agents`
- **Taints**: `gpu=mig:NoSchedule`

### H100 Node Pool (Time-Slicing)
- **Purpose**: High-performance training, fine-tuning
- **Instance Types**: `p5.48xlarge` (8x H100 80GB)
- **GPU Sharing**: Time-Slicing (2-3 replicas per GPU)
- **Labels**: 
  - `workload-type=training`
  - `workload-type=fine-tuning`
- **Taints**: `gpu=h100:NoSchedule`

## GPU Sharing Strategy

### Time-Slicing Configuration
- **Replicas per GPU**: 2-4 (configurable per node pool)
- **Memory Limits**: Proportional to replica count
- **Use Cases**: 
  - Research and development
  - Training workloads with checkpointing
  - Batch inference
  - Agentic AI frameworks

### MIG Configuration
- **Profiles**: 
  - `1g.10gb`: Small inference workloads
  - `2g.20gb`: Medium inference workloads
  - `3g.40gb`: Large inference workloads
- **Use Cases**:
  - Production inference services
  - Critical agentic AI systems
  - Guaranteed performance isolation

## Component Architecture

### Training Layer
```
┌─────────────────────────────────────────────────────────┐
│              Training Orchestration                      │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   PyTorch    │  │ TensorFlow   │  │  Custom      │  │
│  │   Operator   │  │   Operator   │  │  Training    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Hyperparam  │  │ Checkpointing│  │ Distributed  │  │
│  │  Tuning      │  │   & Resume   │  │  Training    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Inference Layer
```
┌─────────────────────────────────────────────────────────┐
│              Inference Services                          │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Triton    │  │     vLLM     │  │     TGI      │  │
│  │   Inference  │  │   Inference  │  │  Inference   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Real-time    │  │ Batch        │  │ Autoscaling  │  │
│  │ Inference    │  │ Inference    │  │ (KEDA)       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Agentic AI Layer
```
┌─────────────────────────────────────────────────────────┐
│              Agentic AI Frameworks                       │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   CrewAI     │  │  LangGraph   │  │   AutoGen    │  │
│  │ Role-based   │  │ Stateful     │  │ Conversational│  │
│  │ Collaboration│  │ Workflows    │  │ Multi-Agent  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  LLM Backend │  │  Prompt      │  │  Orchestration│  │
│  │  Management  │  │  Management  │  │  Engine      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### MLOps Layer
```
┌─────────────────────────────────────────────────────────┐
│              MLOps Tools                                  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   MLflow     │  │  Weights &   │  │   Feature    │  │
│  │  Tracking    │  │   Biases     │  │   Store      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Model      │  │  Monitoring  │  │  Observability│  │
│  │   Registry   │  │  & Alerts    │  │  Stack       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Networking Architecture

### Service Mesh (Linkerd)
- **Purpose**: mTLS, observability, traffic management
- **Components**: 
  - Control plane (CPU nodes)
  - Data plane (all pods)
- **Features**:
  - Automatic mTLS
  - Service discovery
  - Load balancing
  - Metrics and tracing

### Load Balancing
- **Application Load Balancer (ALB)**: HTTP/HTTPS traffic
- **Network Load Balancer (NLB)**: High-performance TCP/UDP
- **Ingress**: ALB Ingress Controller

## Storage Architecture

### EFS (Elastic File System)
- **Use Cases**: 
  - Shared datasets
  - Model artifacts
  - Checkpoint storage
- **Performance**: Standard or EFS One Zone

### EBS (Elastic Block Store)
- **Use Cases**:
  - High-performance checkpoints
  - Local model cache
  - Database storage
- **Types**: gp3 (general purpose), io2 (high IOPS)

### S3
- **Use Cases**:
  - Long-term artifact storage
  - Model registry backend
  - Log archives

## Security Architecture

### Network Policies
- Pod-to-pod communication restrictions
- Namespace isolation
- Egress controls

### Pod Security
- Pod Security Standards (restricted)
- Security contexts
- Resource limits

### Secrets Management
- AWS Secrets Manager integration
- External Secrets Operator
- Encrypted at rest and in transit

## Monitoring and Observability

### Metrics
- Prometheus for metrics collection
- Node Exporter for node metrics
- GPU metrics via DCGM Exporter
- Custom application metrics

### Logging
- Fluent Bit for log collection
- CloudWatch Logs or Elasticsearch
- Centralized log aggregation

### Tracing
- OpenTelemetry integration
- Distributed tracing for agentic workflows
- Linkerd tracing

## Cost Optimization

### Strategies
1. **Spot Instances**: For training workloads (with checkpointing)
2. **Autoscaling**: Scale down during low demand
3. **GPU Sharing**: Maximize utilization via time-slicing
4. **Right-sizing**: Match instance types to workloads
5. **Scheduling**: Batch jobs during off-peak hours

### Resource Management
- Resource quotas per namespace
- Priority classes for scheduling
- Pod disruption budgets
- Cluster autoscaler policies

## Disaster Recovery

### Backup Strategy
- EBS snapshots for persistent volumes
- S3 versioning for artifacts
- etcd backups for cluster state
- Configuration as code (GitOps)

### Recovery Procedures
- Multi-AZ deployment
- Automated failover
- Data replication
- RTO/RPO targets defined per workload

