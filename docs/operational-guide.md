# Operational Guide

## Cost Optimization Strategies

### 1. Spot Instances for Training

Use Spot instances for training workloads with checkpointing:

```yaml
# Add to node pool configuration
capacity_type = "SPOT"
instance_types = ["p5.48xlarge", "p4d.24xlarge"]
```

### 2. Autoscaling Configuration

Configure Cluster Autoscaler for automatic scaling:

```hcl
# In Terraform node pool configuration
min_size     = 0  # Scale to zero when not in use
max_size     = 10
desired_size = 1  # Start with minimum
```

### 3. GPU Utilization Monitoring

Monitor GPU utilization to identify underutilized resources:

```bash
# Query Prometheus for GPU utilization
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Then query: DCGM_FI_DEV_GPU_UTIL
```

### 4. Right-Sizing Workloads

Regularly review resource requests and limits:

```bash
# Check resource usage
kubectl top pods -n training
kubectl top pods -n inference
```

## Multi-Tenant Isolation

### 1. Namespace Isolation

Each tenant should have dedicated namespaces:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: tenant-a
```

### 2. Network Policies

Implement network policies for namespace isolation:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-a-isolation
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: tenant-a
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: tenant-a
```

### 3. Resource Quotas

Set resource quotas per tenant:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-quota
  namespace: tenant-a
spec:
  hard:
    requests.nvidia.com/gpu: "4"
    limits.nvidia.com/gpu: "4"
    requests.cpu: "16"
    limits.cpu: "32"
```

## Security Best Practices

### 1. Pod Security Standards

Enforce restricted pod security:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 2. Secrets Management

Use AWS Secrets Manager with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mlflow-credentials
  namespace: mlops
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: mlflow-s3-credentials
  data:
  - secretKey: access-key-id
    remoteRef:
      key: mlflow/credentials
      property: access-key-id
  - secretKey: secret-access-key
    remoteRef:
      key: mlflow/credentials
      property: secret-access-key
```

### 3. Image Scanning

Implement image scanning in CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'your-image:tag'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

### 4. Network Policies

Implement network policies for all namespaces:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: inference
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Backup and Disaster Recovery

### 1. etcd Backups

Configure automated etcd backups:

```bash
# EKS managed etcd backups are automatic
# For self-managed, use Velero
```

### 2. Velero for Application Backups

Install Velero for application-level backups:

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-aws:v1.7.0 \
  --bucket velero-backups \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2
```

### 3. Persistent Volume Backups

Backup EBS volumes using AWS Backup:

```hcl
# Terraform configuration
resource "aws_backup_plan" "eks_pv_backup" {
  name = "eks-pv-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.eks_pv.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = 30
    }
  }
}
```

### 4. S3 Artifact Backups

Enable S3 versioning and lifecycle policies:

```hcl
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
```

## Monitoring and Alerting

### 1. Prometheus Alerts

Configure critical alerts:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: gpu-alerts
  namespace: monitoring
spec:
  groups:
  - name: gpu
    rules:
    - alert: HighGPUUtilization
      expr: DCGM_FI_DEV_GPU_UTIL > 95
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High GPU utilization detected"
    - alert: GPUMemoryPressure
      expr: DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL > 0.9
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "GPU memory pressure detected"
```

### 2. Grafana Dashboards

Create custom dashboards for:
- GPU utilization per node pool
- Training job progress
- Inference latency and throughput
- Cost per workload

### 3. Cost Monitoring

Use AWS Cost Explorer and CloudWatch for cost tracking:

```bash
# Tag resources for cost allocation
# Tags are set in Terraform variables
```

## Maintenance Windows

### 1. Node Draining

Drain nodes before maintenance:

```bash
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=300
```

### 2. Rolling Updates

Use rolling updates for deployments:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### 3. Pod Disruption Budgets

Ensure PDBs are configured for critical workloads (already in manifests).

## Performance Tuning

### 1. GPU Memory Optimization

Tune GPU memory allocation:

```yaml
# For time-slicing
resources:
  limits:
    nvidia.com/gpu: 1
    memory: 26Gi  # 80GB / 3 replicas
```

### 2. Network Optimization

Optimize service mesh for low latency:

```yaml
# Linkerd configuration
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: triton-inference-server
  namespace: inference
spec:
  routes:
  - name: "/v2/models/*/infer"
    timeout: 10s
    retries:
      budget:
        retryRatio: 0.2
        minRetriesPerSecond: 10
        ttl: 10s
```

### 3. Storage Performance

Use appropriate storage classes:

- EFS: For shared datasets and models
- gp3: For high IOPS workloads
- io2: For database workloads

## Troubleshooting

### Common Issues

1. **GPU Not Available**
   - Check GPU Operator status
   - Verify node labels
   - Check ClusterPolicy configuration

2. **Pod Scheduling Failures**
   - Check resource quotas
   - Verify node selectors and tolerations
   - Review priority classes

3. **Storage Mount Failures**
   - Verify EFS CSI Driver
   - Check security groups
   - Review access points

4. **Service Mesh Issues**
   - Run `linkerd check`
   - Review service profiles
   - Check mTLS configuration

## Support and Escalation

- **Level 1**: Check logs and documentation
- **Level 2**: Review monitoring dashboards
- **Level 3**: Escalate to platform team
- **Critical**: Use on-call rotation

