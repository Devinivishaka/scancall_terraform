# ScanCall AWS Infrastructure (Terraform)

Production-grade Infrastructure as Code (IaC) for ScanCall, deploying:
- **Networking**: VPC across 2 Availability Zones with Public, Private Application, and Private Data Subnets + NAT Gateways.
- **Application Load Balancer (ALB)**: Internet-facing load balancer routing external HTTP/HTTPS and WebSocket traffic to the API Gateway.
- **Amazon ECS (Fargate)**: Serverless container execution for:
  1. `scancall/api-gateway` (Port 8000)
  2. `scancall/core-service` (Port 8080)
  3. `scancall/call-service` (Port 8081)
- **AWS Cloud Map (Service Discovery)**: Private DNS namespace (`scancall.local`) allowing internal microservices to communicate privately without public exposure.
- **Amazon Aurora PostgreSQL Serverless v2**: Highly scalable, multi-AZ relational database.
- **Amazon ElastiCache Redis**: Fast caching layer for rate limiting and real-time state.
- **AWS Secrets Manager**: Secure, encrypted credential store for database master passwords, JWT secrets, LiveKit credentials, and internal API keys.
- **EC2 VM (LiveKit Media Server)**: Public-facing Ubuntu 22.04 VM with an Elastic IP, configured security groups, and automated Docker cloud-init setup running LiveKit WebRTC server.
- **AWS ECR Repositories**: Container image registries with automated scanning and lifecycle policies.
- **AWS WAFv2 & Route53/ACM (Optional)**: Web application firewall protection and managed SSL certificates.

---

## Architecture Diagram

```mermaid
graph TD
    Client[Internet Clients / Mobile App / Web] --> Route53[Route53 + WAF]
    Route53 --> ALB[Application Load Balancer (Public Subnets)]
    
    subgraph Public Subnets [Public Subnets (AZ1 & AZ2)]
        ALB
        NAT[NAT Gateway]
        LiveKit[LiveKit Server EC2 (Public Subnet)]
    end

    subgraph Private App Subnets [Private Subnets (AZ1 & AZ2)]
        APIGW[API Gateway ECS (Port 8000)]
        CoreECS[Core Service ECS (Port 8080)]
        CallECS[Calling Service ECS (Port 8081)]
    end

    subgraph Private Data Subnets [Private Subnets (AZ1 & AZ2)]
        Aurora[(Aurora PostgreSQL Serverless v2)]
        Redis[(ElastiCache Redis 6379)]
        SecretsMgr[AWS Secrets Manager]
    end

    ALB -->|Forward :8000| APIGW
    APIGW -->|Cloud Map :8080| CoreECS
    APIGW -->|Cloud Map :8081 / WebSocket| CallECS
    CoreECS --> Aurora
    CallECS --> Aurora
    APIGW --> Redis
    CallECS --> Redis
    CallECS -.->|LiveKit Tokens/Signaling| LiveKit
    SecretsMgr -.->|Credentials Injection| APIGW
    SecretsMgr -.->|Credentials Injection| CoreECS
    SecretsMgr -.->|Credentials Injection| CallECS
```

---

## Directory Structure

```
terraform/
├── main.tf                    # Provider configuration, terraform block, local tags
├── variables.tf               # Input variables & sizing configurations
├── outputs.tf                 # Endpoints, ECR URLs, connection commands
├── terraform.tfvars.example   # Example variable values
├── vpc.tf                     # 2-AZ VPC, subnets, IGW, NAT Gateways, route tables
├── security_groups.tf         # Microservice isolation security groups
├── secrets.tf                 # AWS Secrets Manager & random passwords
├── rds_aurora.tf              # Aurora PostgreSQL Serverless v2
├── elasticache.tf             # ElastiCache Redis cluster
├── ecr.tf                     # ECR repositories & lifecycle policies
├── ecs_cluster.tf             # ECS Cluster, Cloud Map private DNS, IAM roles
├── ecs_services.tf            # ECS Fargate task definitions & services
├── alb.tf                     # Application Load Balancer, listeners, target groups
├── waf.tf                     # Optional AWS WAFv2 Web ACL
├── ec2_livekit.tf             # LiveKit EC2 VM, Elastic IP, and cloud-init setup
├── scripts/
│   ├── build_and_push.ps1     # Windows PowerShell automated build & push script
│   └── build_and_push.sh      # Linux/macOS automated build & push script
└── README.md
```

---

## Prerequisites

1. **Terraform CLI** (>= 1.5.0) or **OpenTofu**:
   - Windows: `winget install HashiCorp.Terraform` or `choco install terraform`
   - Mac: `brew install terraform`
   - Linux: `sudo apt-get install terraform`
2. **AWS CLI** configured with administrator credentials:
   ```bash
   aws configure
   ```
3. **Docker Desktop** (running for building and pushing container images).

---

## Step-by-Step Deployment Guide

### Step 1: Initialize Terraform
Copy the example variables file:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Inspect and adjust `terraform.tfvars` if desired (e.g. `aws_region`, `environment`).

Initialize the Terraform working directory and download providers:
```bash
terraform init
```

### Step 2: Review and Apply Infrastructure
Generate an execution plan to verify resources:
```bash
terraform plan
```

Deploy the infrastructure:
```bash
terraform apply
```
Type `yes` when prompted. Terraform will output:
- Application Load Balancer DNS name
- ECR repository URLs
- Aurora PostgreSQL endpoint
- ElastiCache Redis endpoint
- LiveKit EC2 public IP & SSH command
- Local private key file `scancall-livekit-key.pem`

---

### Step 3: Access and Verify the LiveKit EC2 VM

Terraform automatically creates `scancall-livekit-key.pem` in your `terraform/` directory.

Connect via SSH:
```bash
# On Linux/macOS (set permissions first)
chmod 400 scancall-livekit-key.pem
ssh -i scancall-livekit-key.pem ubuntu@<LIVEKIT_PUBLIC_IP>

# On Windows (PowerShell)
ssh -i scancall-livekit-key.pem ubuntu@<LIVEKIT_PUBLIC_IP>
```

Check the status of the LiveKit server:
```bash
docker ps
docker logs -f livekit-server
```
LiveKit is listening on port `7880` (HTTP/WebSocket) and WebRTC ports `50000-60000/UDP`.

---

### Step 4: Build and Push Docker Images to ECR

Once the ECR repositories are provisioned by Terraform, build and push all 3 services.

**On Windows (PowerShell):**
```powershell
cd terraform\scripts
.\build_and_push.ps1 -Region "ap-south-1" -Environment "dev"
```

**On Linux/macOS / CI/CD:**
```bash
cd terraform/scripts
chmod +x build_and_push.sh
./build_and_push.sh
```

This script will:
1. Log into AWS ECR.
2. Build the Docker images for `scancall/api-gateway`, `scancall/core-service`, and `scancall/call-service`.
3. Tag images with both `latest` and a timestamp.
4. Push all images to ECR.
5. Signal ECS services to perform a `force-new-deployment`.

---

### Step 5: Verify Secrets in AWS Secrets Manager

The credentials are automatically encrypted and stored in AWS Secrets Manager:
- `${project_name}/db-credentials-${environment}`: Database user, password, port, host, database name.
- `${project_name}/app-secrets-${environment}`: JWT secret, internal API key, LiveKit API key, and LiveKit API secret.

You can inspect secrets anytime via the AWS CLI:
```bash
aws secretsmanager get-secret-value --secret-id scancall/app-secrets-dev --region ap-south-1
```

---

### Step 6: Test the Application Load Balancer

Retrieve the ALB URL from terraform output:
```bash
terraform output application_url
```

Test the API Gateway through the ALB:
```bash
curl http://<ALB_DNS_NAME>/
```

---

## Clean Up / Destroy

To tear down all provisioned resources to avoid ongoing AWS charges:
```bash
terraform destroy
```
Type `yes` when prompted.
