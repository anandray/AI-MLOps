# Quick Reference Guide

## Common Commands

### Cluster Management

```bash
# Update kubeconfig
aws eks update-kubeconfig --name ai-mlops-production --region us-west-2

# Check cluster status
kubectl cluster-info
kubectl get nodes

# Check GPU nodes
kubectl get nodes -l gpu-sharing=timeslice
kubectl get nodes -l gpu-sharing=mig
kubectl describe node <node-name> | grep nvidia.com/gpu
```

### GPU Management

```bash
# Check GPU Operator
kubectl get pods -n gpu-operator-resources
kubectl logs -n gpu-operator-resources -l app=nvidia-device-plugin-daemonset

# Check GPU availability
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpu: .status.capacity."nvidia.com/gpu"}'

# Test GPU access
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:11.8.0-base-ubuntu22.04 \
  --overrides='{"spec":{"nodeSelector":{"gpu-sharing":"timeslice"},"tolerations":[{"key":"gpu","operator":"Equal","value":"true","effect":"NoSchedule"}],"containers":[{"name":"gpu-test","resources":{"limits":{"nvidia.com/gpu":"1"}},"command":["nvidia-smi"]}]}}'
```

### Training Jobs

```bash
# Submit training job
kubectl apply -f examples/training-job-example.yaml

# Check job status
kubectl get pytorchjobs -n training
kubectl describe pytorchjob <job-name> -n training

# View logs
kubectl logs -n training <pod-name> -f

# Delete job
kubectl delete pytorchjob <job-name> -n training
```

### Inference Services

```bash
# Check inference services
kubectl get deployments -n inference
kubectl get services -n inference

# Port-forward for testing
kubectl port-forward -n inference svc/vllm-inference-server 8000:8000

# Test inference
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama2-7b","prompt":"Hello, world!","max_tokens":50}'

# Check autoscaling
kubectl get hpa -n inference
kubectl describe hpa <hpa-name> -n inference
```

### Agentic AI

```bash
# Check agentic deployments
kubectl get deployments -n agentic
kubectl get services -n agentic

# Port-forward CrewAI
kubectl port-forward -n agentic svc/crewai-orchestrator 8000:8000

# Test CrewAI API
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"description":"Research AI trends","agents":["researcher"]}'
```

### Monitoring

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Check metrics
kubectl top nodes
kubectl top pods -n training
kubectl top pods -n inference
```

### Storage

```bash
# Check PVCs
kubectl get pvc -n training
kubectl get pvc -n inference
kubectl get pvc -n agentic

# Check EFS CSI Driver
kubectl get pods -n kube-system | grep efs

# Check StorageClasses
kubectl get storageclass
kubectl describe storageclass efs-sc
```

### Service Mesh

```bash
# Check Linkerd
linkerd check
linkerd viz stat deploy -n inference
linkerd viz stat deploy -n agentic

# Check mTLS
linkerd viz tap deploy/triton-inference-server -n inference
```

### Resource Management

```bash
# Check resource quotas
kubectl get resourcequota -n training
kubectl get resourcequota -n inference
kubectl get resourcequota -n agentic

# Check limit ranges
kubectl get limitrange -n training
kubectl describe limitrange training-limits -n training

# Check priority classes
kubectl get priorityclass

# Check pod disruption budgets
kubectl get pdb -A
```

## Node Selection Examples

### Time-Sliced GPU (Research/Training)

```yaml
nodeSelector:
  workload-type: research
  gpu-sharing: timeslice
tolerations:
- key: gpu
  operator: Equal
  value: "true"
  effect: NoSchedule
```

### MIG GPU (Production Inference)

```yaml
nodeSelector:
  workload-type: production-inference
  mig-profile: "3g.40gb"
tolerations:
- key: gpu
  operator: Equal
  value: "mig"
  effect: NoSchedule
```

### H100 GPU (High-Performance Training)

```yaml
nodeSelector:
  workload-type: training
  gpu-type: h100
  gpu-sharing: timeslice
tolerations:
- key: gpu
  operator: Equal
  value: "h100"
  effect: NoSchedule
```

## Resource Request Examples

### Training Job (Time-Sliced)

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
    memory: 32Gi
    cpu: 8
  requests:
    nvidia.com/gpu: 1
    memory: 32Gi
    cpu: 8
```

### Inference Service (MIG)

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
    memory: 40Gi
    cpu: 8
  requests:
    nvidia.com/gpu: 1
    memory: 40Gi
    cpu: 8
```

### Agentic AI (MIG)

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
    memory: 20Gi
    cpu: 4
  requests:
    nvidia.com/gpu: 1
    memory: 20Gi
    cpu: 4
```

## Troubleshooting

### Pod Not Scheduling

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe node <node-name>

# Check resource quotas
kubectl describe resourcequota -n <namespace>
```

### GPU Not Available

```bash
# Check GPU Operator
kubectl get pods -n gpu-operator-resources
kubectl logs -n gpu-operator-resources -l app=nvidia-device-plugin-daemonset

# Check node labels
kubectl get nodes --show-labels | grep gpu

# Check ClusterPolicy
kubectl get clusterpolicy -n gpu-operator-resources
kubectl describe clusterpolicy cluster-policy -n gpu-operator-resources
```

### Storage Mount Issues

```bash
# Check EFS CSI Driver
kubectl get pods -n kube-system | grep efs
kubectl logs -n kube-system <efs-csi-pod>

# Check PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*efs*"
```

## Useful Queries

### Prometheus Queries

```promql
# GPU Utilization
DCGM_FI_DEV_GPU_UTIL

# GPU Memory Usage
DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL

# Pod CPU Usage
rate(container_cpu_usage_seconds_total[5m])

# Pod Memory Usage
container_memory_working_set_bytes

# Request Rate
rate(http_requests_total[5m])
```

### kubectl Queries

```bash
# All GPU pods
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu") | {namespace: .metadata.namespace, name: .metadata.name, gpu: .spec.containers[].resources.limits."nvidia.com/gpu"}'

# Pods by priority
kubectl get pods -A --sort-by=.spec.priority

# Resource usage by namespace
kubectl top pods --all-namespaces --sort-by=memory
```

## Cost Monitoring

```bash
# Check node costs
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/ai-mlops-production,Values=owned" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' --output table

# Check EBS volumes
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/ai-mlops-production,Values=owned" --query 'Volumes[*].[VolumeId,Size,State]' --output table

# Check EFS
aws efs describe-file-systems --query 'FileSystems[*].[FileSystemId,SizeInBytes.Value]' --output table
```

