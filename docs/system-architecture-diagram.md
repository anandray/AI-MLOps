# System Architecture Diagram

This document contains the comprehensive system architecture diagram for the AI/MLOps platform.

## High-Level System Architecture

```mermaid
graph TB
    subgraph AWS["AWS Cloud"]
        subgraph VPC["VPC"]
            subgraph EKS["EKS Cluster"]
                subgraph CP["Control Plane"]
                    API[Kubernetes API Server]
                    ETCD[etcd]
                    SCHED[Scheduler]
                end
                
                subgraph CPU_POOL["CPU Node Pool<br/>m5.2xlarge/m5.4xlarge"]
                    direction TB
                    MLOPS[MLOps Tools<br/>MLflow, W&B]
                    AGENTS[Agentic Frameworks<br/>CrewAI, LangGraph, AutoGen]
                    MONITOR[Monitoring Stack<br/>Prometheus, Grafana]
                    MESH[Linkerd Control Plane]
                end
                
                subgraph A100_TS["A100 Node Pool - Time-Slicing<br/>p5.48xlarge (8x A100 80GB)"]
                    direction TB
                    A100_TS_TRAIN[Training Jobs<br/>PyTorch, TensorFlow]
                    A100_TS_RESEARCH[Research Workloads]
                    A100_TS_BATCH[Batch Inference]
                    A100_TS_DEV[Development]
                end
                
                subgraph A100_MIG["A100 Node Pool - MIG<br/>p5.48xlarge (8x A100 80GB)"]
                    direction TB
                    A100_MIG_PROD[Production Inference<br/>Triton, vLLM, TGI]
                    A100_MIG_CRIT[Critical Agents]
                end
                
                subgraph H100_TS["H100 Node Pool - Time-Slicing<br/>p5.48xlarge (8x H100 80GB)"]
                    direction TB
                    H100_TRAIN[High-Perf Training]
                    H100_FINETUNE[Fine-tuning]
                end
            end
            
            subgraph STORAGE["Storage Layer"]
                EFS[EFS<br/>Datasets, Models,<br/>Shared Storage]
                EBS[EBS<br/>Checkpoints,<br/>High-Perf Storage]
                S3[S3<br/>Artifacts, Logs,<br/>Model Registry]
            end
            
            subgraph NETWORK["Networking"]
                LINKERD[Linkerd Service Mesh<br/>mTLS, Observability]
                ALB[Application Load Balancer<br/>HTTP/HTTPS]
                NLB[Network Load Balancer<br/>TCP/UDP]
                VPC_CNI[VPC CNI<br/>Pod Networking]
            end
        end
        
        subgraph EXTERNAL["External Services"]
            GITHUB[GitHub<br/>CI/CD]
            ARGOCD[ArgoCD<br/>GitOps]
            SECRETS[AWS Secrets Manager]
        end
    end
    
    subgraph GPU_OP["GPU Operator"]
        TS_CONFIG[Time-Slicing Config<br/>2-4 replicas/GPU]
        MIG_CONFIG[MIG Config<br/>1g.10gb, 2g.20gb, 3g.40gb]
        DEVICE_PLUGIN[Device Plugin]
    end
    
    %% Connections
    CP --> CPU_POOL
    CP --> A100_TS
    CP --> A100_MIG
    CP --> H100_TS
    
    GPU_OP --> A100_TS
    GPU_OP --> A100_MIG
    GPU_OP --> H100_TS
    
    A100_TS --> EFS
    A100_TS --> EBS
    A100_MIG --> EFS
    A100_MIG --> EBS
    H100_TS --> EFS
    H100_TS --> EBS
    CPU_POOL --> EFS
    CPU_POOL --> S3
    
    LINKERD --> CPU_POOL
    LINKERD --> A100_TS
    LINKERD --> A100_MIG
    LINKERD --> H100_TS
    
    ALB --> A100_MIG_PROD
    NLB --> A100_MIG_PROD
    
    GITHUB --> ARGOCD
    ARGOCD --> EKS
    
    SECRETS --> EKS
    
    style AWS fill:#232f3e,stroke:#ff9900,color:#fff
    style EKS fill:#146eb4,stroke:#ff9900,color:#fff
    style CPU_POOL fill:#2d8659,stroke:#ff9900,color:#fff
    style A100_TS fill:#d13212,stroke:#ff9900,color:#fff
    style A100_MIG fill:#d13212,stroke:#ff9900,color:#fff
    style H100_TS fill:#7c2d12,stroke:#ff9900,color:#fff
    style STORAGE fill:#146eb4,stroke:#ff9900,color:#fff
    style NETWORK fill:#146eb4,stroke:#ff9900,color:#fff
    style GPU_OP fill:#7c2d12,stroke:#ff9900,color:#fff
```

## Component Interaction Flow

```mermaid
sequenceDiagram
    participant User
    participant ALB as Application Load Balancer
    participant Linkerd as Linkerd Service Mesh
    participant Inference as Inference Service (vLLM/Triton)
    participant Training as Training Job (PyTorch)
    participant Agentic as Agentic Framework (CrewAI)
    participant MLOps as MLflow/W&B
    participant Storage as EFS/EBS/S3
    participant GPU as GPU Operator
    
    User->>ALB: HTTP Request
    ALB->>Linkerd: Route to Service
    Linkerd->>Inference: mTLS Connection
    Inference->>GPU: Request GPU Resource
    GPU->>Inference: Allocate GPU (MIG/Time-Slice)
    Inference->>Storage: Load Model
    Storage-->>Inference: Model Artifacts
    Inference->>Inference: Process Request
    Inference-->>Linkerd: Response
    Linkerd-->>ALB: Response
    ALB-->>User: HTTP Response
    
    User->>Training: Submit Training Job
    Training->>GPU: Request GPU Resources
    GPU->>Training: Allocate Time-Sliced GPUs
    Training->>Storage: Load Dataset
    Storage-->>Training: Training Data
    Training->>Training: Distributed Training
    Training->>MLOps: Log Metrics
    Training->>Storage: Save Checkpoints
    Storage-->>Training: Checkpoint Confirmed
    Training->>Storage: Save Final Model
    Storage-->>MLOps: Register Model
    
    User->>Agentic: Submit Agent Task
    Agentic->>Linkerd: Inter-Agent Communication
    Agentic->>Inference: LLM API Call
    Inference-->>Agentic: LLM Response
    Agentic->>Agentic: Agent Orchestration
    Agentic->>MLOps: Log Agent Metrics
    Agentic-->>User: Task Result
```

## GPU Sharing Strategy Diagram

```mermaid
graph LR
    subgraph PHYSICAL_GPU["Physical GPU"]
        subgraph TS_STRATEGY["Time-Slicing Strategy"]
            direction TB
            TS_GPU1[GPU Replica 1<br/>~20GB Memory]
            TS_GPU2[GPU Replica 2<br/>~20GB Memory]
            TS_GPU3[GPU Replica 3<br/>~20GB Memory]
            TS_GPU4[GPU Replica 4<br/>~20GB Memory]
        end
        
        subgraph MIG_STRATEGY["MIG Strategy"]
            direction TB
            MIG_1G[MIG 1g.10gb<br/>10GB Memory]
            MIG_2G[MIG 2g.20gb<br/>20GB Memory]
            MIG_3G[MIG 3g.40gb<br/>40GB Memory]
        end
    end
    
    subgraph WORKLOADS_TS["Time-Slicing Workloads"]
        TS_TRAIN[Training Jobs]
        TS_RESEARCH[Research]
        TS_DEV[Development]
        TS_BATCH[Batch Inference]
    end
    
    subgraph WORKLOADS_MIG["MIG Workloads"]
        MIG_PROD[Production Inference]
        MIG_CRIT[Critical Agents]
    end
    
    TS_STRATEGY --> WORKLOADS_TS
    MIG_STRATEGY --> WORKLOADS_MIG
    
    style TS_STRATEGY fill:#2d8659,stroke:#ff9900,color:#fff
    style MIG_STRATEGY fill:#d13212,stroke:#ff9900,color:#fff
    style WORKLOADS_TS fill:#146eb4,stroke:#ff9900,color:#fff
    style WORKLOADS_MIG fill:#7c2d12,stroke:#ff9900,color:#fff
```

## Data Flow Architecture

```mermaid
graph TB
    subgraph INGEST["Data Ingestion"]
        DATASET[Raw Datasets]
        MODEL[Pre-trained Models]
        CODE[Training Code]
    end
    
    subgraph STORAGE_LAYER["Storage Layer"]
        S3_RAW[S3: Raw Data<br/>Versioned]
        EFS_SHARED[EFS: Shared Storage<br/>Datasets, Models]
        EBS_FAST[EBS: Fast Storage<br/>Checkpoints, Cache]
        S3_ARTIFACTS[S3: Artifacts<br/>Models, Logs]
    end
    
    subgraph TRAINING_LAYER["Training Layer"]
        TRAIN_JOB[Training Jobs<br/>PyTorch/TensorFlow]
        HYPERPARAM[Hyperparameter Tuning]
        CHECKPOINT[Checkpointing]
    end
    
    subgraph MLOPS_LAYER["MLOps Layer"]
        MLFLOW[MLflow<br/>Experiment Tracking]
        WANDB[Weights & Biases<br/>Metrics]
        REGISTRY[Model Registry]
    end
    
    subgraph INFERENCE_LAYER["Inference Layer"]
        TRITON[Triton Server]
        VLLM[vLLM Server]
        TGI[TGI Server]
    end
    
    subgraph AGENTIC_LAYER["Agentic Layer"]
        CREWAI[CrewAI]
        LANGGRAPH[LangGraph]
        AUTOGEN[AutoGen]
    end
    
    INGEST --> S3_RAW
    INGEST --> EFS_SHARED
    
    S3_RAW --> TRAIN_JOB
    EFS_SHARED --> TRAIN_JOB
    TRAIN_JOB --> HYPERPARAM
    TRAIN_JOB --> CHECKPOINT
    CHECKPOINT --> EBS_FAST
    
    TRAIN_JOB --> MLFLOW
    TRAIN_JOB --> WANDB
    TRAIN_JOB --> REGISTRY
    REGISTRY --> S3_ARTIFACTS
    
    S3_ARTIFACTS --> TRITON
    S3_ARTIFACTS --> VLLM
    S3_ARTIFACTS --> TGI
    
    TRITON --> AGENTIC_LAYER
    VLLM --> AGENTIC_LAYER
    TGI --> AGENTIC_LAYER
    
    style INGEST fill:#146eb4,stroke:#ff9900,color:#fff
    style STORAGE_LAYER fill:#2d8659,stroke:#ff9900,color:#fff
    style TRAINING_LAYER fill:#d13212,stroke:#ff9900,color:#fff
    style MLOPS_LAYER fill:#7c2d12,stroke:#ff9900,color:#fff
    style INFERENCE_LAYER fill:#d13212,stroke:#ff9900,color:#fff
    style AGENTIC_LAYER fill:#146eb4,stroke:#ff9900,color:#fff
```

## Network Architecture

```mermaid
graph TB
    subgraph INTERNET["Internet"]
        USERS[Users/Applications]
    end
    
    subgraph AWS["AWS"]
        subgraph VPC["VPC"]
            subgraph PUBLIC["Public Subnets"]
                ALB[Application Load Balancer]
                NLB[Network Load Balancer]
                NAT[NAT Gateway]
            end
            
            subgraph PRIVATE["Private Subnets"]
                subgraph EKS["EKS Cluster"]
                    INGRESS[Ingress Controller]
                    LINKERD_CP[Linkerd Control Plane]
                    
                    subgraph NAMESPACES["Namespaces"]
                        INFERENCE_NS[inference namespace]
                        TRAINING_NS[training namespace]
                        AGENTIC_NS[agentic namespace]
                        MLOPS_NS[mlops namespace]
                    end
                    
                    subgraph PODS["Pods"]
                        INFERENCE_POD[Inference Pods]
                        TRAINING_POD[Training Pods]
                        AGENTIC_POD[Agentic Pods]
                        MLOPS_POD[MLOps Pods]
                    end
                end
            end
            
            subgraph STORAGE["Storage"]
                EFS[EFS Endpoints]
                EBS[EBS Volumes]
            end
        end
        
        S3[S3 Buckets]
        SECRETS[AWS Secrets Manager]
    end
    
    USERS --> ALB
    USERS --> NLB
    ALB --> INGRESS
    NLB --> INGRESS
    INGRESS --> LINKERD_CP
    LINKERD_CP --> INFERENCE_NS
    LINKERD_CP --> TRAINING_NS
    LINKERD_CP --> AGENTIC_NS
    LINKERD_CP --> MLOPS_NS
    
    INFERENCE_NS --> INFERENCE_POD
    TRAINING_NS --> TRAINING_POD
    AGENTIC_NS --> AGENTIC_POD
    MLOPS_NS --> MLOPS_POD
    
    INFERENCE_POD --> EFS
    TRAINING_POD --> EFS
    TRAINING_POD --> EBS
    AGENTIC_POD --> EFS
    MLOPS_POD --> S3
    
    PODS --> SECRETS
    PODS --> NAT
    NAT --> INTERNET
    
    style INTERNET fill:#232f3e,stroke:#ff9900,color:#fff
    style AWS fill:#146eb4,stroke:#ff9900,color:#fff
    style VPC fill:#2d8659,stroke:#ff9900,color:#fff
    style EKS fill:#d13212,stroke:#ff9900,color:#fff
    style STORAGE fill:#7c2d12,stroke:#ff9900,color:#fff
```

## Monitoring and Observability

```mermaid
graph TB
    subgraph CLUSTER["EKS Cluster"]
        PODS[Application Pods]
        NODES[Node Metrics]
        GPU[GPU Metrics<br/>DCGM Exporter]
    end
    
    subgraph COLLECTION["Metrics Collection"]
        PROMETHEUS[Prometheus<br/>Metrics Scraping]
        FLUENTBIT[Fluent Bit<br/>Log Collection]
        OPENTELEMETRY[OpenTelemetry<br/>Tracing]
    end
    
    subgraph STORAGE["Time-Series Storage"]
        PROM_DB[(Prometheus TSDB)]
        CLOUDWATCH[CloudWatch Logs]
        TRACING_BACKEND[Tracing Backend]
    end
    
    subgraph VISUALIZATION["Visualization"]
        GRAFANA[Grafana Dashboards]
        ALERTMANAGER[AlertManager]
    end
    
    PODS --> PROMETHEUS
    NODES --> PROMETHEUS
    GPU --> PROMETHEUS
    PODS --> FLUENTBIT
    PODS --> OPENTELEMETRY
    
    PROMETHEUS --> PROM_DB
    FLUENTBIT --> CLOUDWATCH
    OPENTELEMETRY --> TRACING_BACKEND
    
    PROM_DB --> GRAFANA
    PROM_DB --> ALERTMANAGER
    CLOUDWATCH --> GRAFANA
    
    ALERTMANAGER --> NOTIFICATIONS[Notifications<br/>Slack, PagerDuty]
    
    style CLUSTER fill:#146eb4,stroke:#ff9900,color:#fff
    style COLLECTION fill:#2d8659,stroke:#ff9900,color:#fff
    style STORAGE fill:#d13212,stroke:#ff9900,color:#fff
    style VISUALIZATION fill:#7c2d12,stroke:#ff9900,color:#fff
```

## Deployment Pipeline

```mermaid
graph LR
    subgraph CI["CI - GitHub Actions"]
        COMMIT[Code Commit]
        BUILD[Build & Test]
        IMAGE[Build Container Images]
        PUSH[Push to ECR]
    end
    
    subgraph CD["CD - ArgoCD"]
        GIT_REPO[Git Repository]
        ARGOCD[ArgoCD Controller]
        SYNC[Sync to Cluster]
    end
    
    subgraph CLUSTER["EKS Cluster"]
        APPLY[Apply Manifests]
        DEPLOY[Deploy Workloads]
        VERIFY[Health Checks]
    end
    
    COMMIT --> BUILD
    BUILD --> IMAGE
    IMAGE --> PUSH
    PUSH --> GIT_REPO
    
    GIT_REPO --> ARGOCD
    ARGOCD --> SYNC
    SYNC --> APPLY
    APPLY --> DEPLOY
    DEPLOY --> VERIFY
    
    style CI fill:#146eb4,stroke:#ff9900,color:#fff
    style CD fill:#2d8659,stroke:#ff9900,color:#fff
    style CLUSTER fill:#d13212,stroke:#ff9900,color:#fff
```

## Notes

These diagrams can be rendered in:
- GitHub (native Mermaid support)
- GitLab (native Mermaid support)
- VS Code with Mermaid extensions
- Online Mermaid editors (mermaid.live)
- Documentation tools (MkDocs, Docusaurus, etc.)

For best results, use a Mermaid-compatible viewer or renderer.

