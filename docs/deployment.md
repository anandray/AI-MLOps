# Deployment Guide

This guide walks through deploying the AI/MLOps platform on AWS EKS.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl >= 1.28
- helm >= 3.12
- Access to AWS account with permissions to create EKS clusters

## Infrastructure Deployment

### 1. Configure Terraform Backend

Update `terraform/environments/production/main.tf` with your S3 bucket for state:

```hcl
backend "s3" {
  bucket = "your-terraform-state-bucket"
  key    = "production/terraform.tfstate"
  region = "us-west-2"
}
```

### 2. Configure Variables

Create `terraform/environments/production/terraform.tfvars`:

```hcl
cluster_name = "ai-mlops-production"
aws_region   = "us-west-2"
vpc_id       = "vpc-xxxxxxxxx"
subnet_ids   = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]

# Node pool sizes
cpu_desired_size              = 2
a100_timeslice_desired_size   = 1
a100_mig_desired_size         = 1
h100_timeslice_desired_size   = 1

# S3 buckets for model artifacts
s3_bucket_arns = [
  "arn:aws:s3:::mlflow-artifacts",
  "arn:aws:s3:::model-registry"
]
```

### 3. Initialize and Apply Terraform

```bash
cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

### 4. Configure kubectl

```bash
aws eks update-kubeconfig --name ai-mlops-production --region us-west-2
```

## Kubernetes Components Deployment

### 1. Install GPU Operator

```bash
# Install via Helm
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator-resources \
  --create-namespace \
  --version 23.9.0

# Apply GPU Operator configurations
kubectl apply -f kubernetes/gpu-operator/
```

### 2. Install EFS CSI Driver

```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"
```

### 3. Install Linkerd Service Mesh

```bash
# Install Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh

# Install Linkerd
linkerd install | kubectl apply -f -
linkerd check

# Install Linkerd Viz (for metrics)
linkerd viz install | kubectl apply -f -
```

### 4. Install Monitoring Stack

```bash
kubectl apply -f kubernetes/monitoring/
```

### 5. Install Resource Management

```bash
kubectl apply -f kubernetes/resource-management/
```

### 6. Install MLOps Components

```bash
# Create secrets first
kubectl create secret generic mlflow-s3-credentials \
  --from-literal=access-key-id=YOUR_ACCESS_KEY \
  --from-literal=secret-access-key=YOUR_SECRET_KEY \
  -n mlops

kubectl create secret generic mlflow-postgres-secret \
  --from-literal=password=YOUR_PASSWORD \
  -n mlops

kubectl create secret generic wandb-secret \
  --from-literal=api-key=YOUR_API_KEY \
  -n mlops

# Apply MLOps manifests
kubectl apply -f kubernetes/mlops/
```

### 7. Install Training Workloads

```bash
# Install Kubeflow Training Operators
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# Apply training manifests
kubectl apply -f kubernetes/training/
```

### 8. Install Inference Services

```bash
kubectl apply -f kubernetes/inference/
```

### 9. Install Agentic AI Frameworks

```bash
kubectl apply -f kubernetes/agentic/
```

## Verification

### Check GPU Operator

```bash
kubectl get pods -n gpu-operator-resources
kubectl get nodes -l gpu-sharing=timeslice
kubectl get nodes -l gpu-sharing=mig
```

### Check GPU Availability

```bash
kubectl describe node <gpu-node-name> | grep nvidia.com/gpu
```

### Test GPU Workload

```bash
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:11.8.0-base-ubuntu22.04 \
  --overrides='
{
  "spec": {
    "nodeSelector": {
      "gpu-sharing": "timeslice"
    },
    "tolerations": [{
      "key": "gpu",
      "operator": "Equal",
      "value": "true",
      "effect": "NoSchedule"
    }],
    "containers": [{
      "name": "gpu-test",
      "resources": {
        "limits": {
          "nvidia.com/gpu": "1"
        }
      },
      "command": ["nvidia-smi"]
    }]
  }
}'
```

### Check Monitoring

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Post-Deployment Configuration

### 1. Configure Ingress

Set up ALB Ingress Controller for external access:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ai-mlops-production
```

### 2. Configure Autoscaling

Cluster Autoscaler should be configured via Terraform. Verify it's running:

```bash
kubectl get deployment cluster-autoscaler -n kube-system
```

### 3. Set Up CI/CD

Configure GitHub Actions and ArgoCD for GitOps workflows (see `docs/cicd.md`).

## Troubleshooting

### GPU Not Available

1. Check GPU Operator pods:
   ```bash
   kubectl get pods -n gpu-operator-resources
   kubectl logs -n gpu-operator-resources -l app=nvidia-device-plugin-daemonset
   ```

2. Check node labels:
   ```bash
   kubectl get nodes --show-labels | grep gpu
   ```

3. Verify GPU Operator ClusterPolicy:
   ```bash
   kubectl get clusterpolicy -n gpu-operator-resources
   ```

### Storage Issues

1. Check EFS CSI Driver:
   ```bash
   kubectl get pods -n kube-system | grep efs
   ```

2. Verify StorageClass:
   ```bash
   kubectl get storageclass
   kubectl describe storageclass efs-sc
   ```

### Service Mesh Issues

1. Check Linkerd:
   ```bash
   linkerd check
   linkerd viz stat deploy -n <namespace>
   ```

## Next Steps

- Configure monitoring dashboards in Grafana
- Set up alerting rules in Prometheus
- Configure backup strategies
- Review security policies
- Set up cost monitoring

