# GPU Sharing Strategy

## Overview

This document details the GPU sharing strategy for the AI/MLOps platform, implementing both Time-Slicing and MIG (Multi-Instance GPU) approaches.

## Strategy Summary

| Strategy | GPU Type | Use Case | Isolation | Replicas/Partitions |
|----------|----------|----------|-----------|---------------------|
| Time-Slicing | A100, H100 | Research, Training, Development | Soft | 2-4 per GPU |
| MIG | A100 80GB | Production Inference | Hard | 1-7 per GPU |

## Time-Slicing Configuration

### Objective
Maximize GPU utilization for research, training, and development workloads with acceptable performance isolation.

### Configuration Details

#### A100 Time-Slicing Pool
- **Node Labels**: 
  - `workload-type=research`
  - `workload-type=training`
  - `workload-type=development`
  - `workload-type=batch-inference`
- **Replicas per GPU**: 3 (configurable)
- **Memory per Replica**: ~26GB (80GB / 3)
- **Use Cases**:
  - Model training with checkpointing
  - Research experiments
  - Development and testing
  - Batch inference jobs

#### H100 Time-Slicing Pool
- **Node Labels**: 
  - `workload-type=training`
  - `workload-type=fine-tuning`
- **Replicas per GPU**: 2 (for high-performance workloads)
- **Memory per Replica**: ~40GB (80GB / 2)
- **Use Cases**:
  - Large model training
  - Fine-tuning workloads
  - High-performance inference

### Time-Slicing Implementation

```yaml
# Example: 3 replicas per A100 GPU
apiVersion: v1
kind: ConfigMap
metadata:
  name: device-plugin-config
  namespace: gpu-operator-resources
data:
  config.yaml: |
    version: v1
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 3
```

### Resource Requests

Workloads using time-sliced GPUs should request:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # One time-sliced replica
  requests:
    nvidia.com/gpu: 1
```

### Performance Characteristics

- **Pros**:
  - High utilization (80-90% typical)
  - Flexible allocation
  - Easy to scale
- **Cons**:
  - No hard performance isolation
  - Potential interference between workloads
  - Memory contention possible

## MIG Configuration

### Objective
Provide strong performance isolation for production inference workloads.

### MIG Profiles

#### Profile Selection

| Profile | GPU Memory | Compute Units | Use Case |
|---------|------------|---------------|----------|
| `1g.10gb` | 10GB | 1/7 of SM | Small models, low latency |
| `2g.20gb` | 20GB | 2/7 of SM | Medium models, balanced |
| `3g.40gb` | 40GB | 3/7 of SM | Large models, high throughput |

#### A100 80GB MIG Configuration

From a single A100 80GB GPU, we can create:
- **Option 1**: 7x `1g.10gb` instances
- **Option 2**: 3x `2g.20gb` + 1x `1g.10gb`
- **Option 3**: 2x `3g.40gb` + 1x `1g.10gb`
- **Option 4**: 1x `3g.40gb` + 2x `2g.20gb`

**Recommended**: Option 4 (1x `3g.40gb` + 2x `2g.20gb`) for balanced production workloads.

### MIG Node Pools

#### Production Inference Pool (3g.40gb)
- **Node Labels**: `workload-type=production-inference`, `mig-profile=3g.40gb`
- **MIG Profile**: `3g.40gb`
- **Use Cases**: Large language models, high-throughput inference

#### Critical Agents Pool (2g.20gb)
- **Node Labels**: `workload-type=critical-agents`, `mig-profile=2g.20gb`
- **MIG Profile**: `2g.20gb`
- **Use Cases**: Agentic AI systems requiring guaranteed performance

#### Small Inference Pool (1g.10gb)
- **Node Labels**: `workload-type=production-inference`, `mig-profile=1g.10gb`
- **MIG Profile**: `1g.10gb`
- **Use Cases**: Small models, low-latency services

### MIG Implementation

MIG configuration is done at the node level via GPU Operator. Each node pool uses a specific MIG profile.

### Resource Requests

Workloads using MIG partitions should request:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # One MIG instance
  requests:
    nvidia.com/gpu: 1
nodeSelector:
  mig-profile: "3g.40gb"
```

## Scheduling Strategy

### Node Selection

Workloads specify their requirements via node selectors:

```yaml
# Time-sliced GPU (research)
nodeSelector:
  workload-type: research
tolerations:
- key: gpu
  operator: Equal
  value: "true"
  effect: NoSchedule

# MIG GPU (production)
nodeSelector:
  workload-type: production-inference
  mig-profile: "3g.40gb"
tolerations:
- key: gpu
  operator: Equal
  value: "mig"
  effect: NoSchedule
```

### Priority Classes

```yaml
# High priority for production
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: production-inference
value: 1000
globalDefault: false

# Medium priority for training
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: training
value: 500
globalDefault: false

# Low priority for research
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: research
value: 100
globalDefault: false
```

## Resource Quotas

### Per Namespace Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: production
spec:
  hard:
    requests.nvidia.com/gpu: "10"
    limits.nvidia.com/gpu: "10"
```

## Monitoring

### GPU Metrics

- **DCGM Exporter**: GPU utilization, memory, temperature
- **Time-Slice Metrics**: Per-replica utilization
- **MIG Metrics**: Per-instance metrics

### Key Metrics
- GPU utilization per time-slice/MIG instance
- Memory usage per partition
- Queue depth for GPU requests
- Scheduler wait times

## Migration Path

### From Time-Slicing to MIG

1. **Development Phase**: Use time-sliced GPUs
2. **Testing Phase**: Continue with time-slicing, monitor performance
3. **Production Phase**: Migrate to MIG for guaranteed isolation

### Fallback Strategy

If preferred GPU type unavailable:
- Time-sliced workloads can fall back to other time-sliced pools
- MIG workloads should not fall back (maintain isolation)
- Use priority classes to preempt lower-priority workloads

## Cost Optimization

### Time-Slicing Benefits
- 3x utilization improvement (3 replicas per GPU)
- Cost per workload: ~33% of dedicated GPU
- Suitable for bursty workloads

### MIG Benefits
- Guaranteed performance isolation
- Predictable latency
- Better for SLA-bound services
- Higher cost per workload but justified for production

## Operational Considerations

### Maintenance Windows
- Time-sliced pools: Can drain nodes gradually
- MIG pools: Require careful planning (production workloads)

### Scaling
- Time-sliced pools: Easy to scale (add/remove nodes)
- MIG pools: Requires MIG reconfiguration (node restart)

### Troubleshooting
- Time-slicing: Check for memory/performance interference
- MIG: Verify profile configuration, check instance allocation

