# ScanCall Infrastructure: AWS Cost Analysis & Official Scaling Report

**Target Region:** Europe (Ireland) / `eu-west-1`  
**Currency:** USD ($)  
**Pricing Model:** AWS Official On-Demand Rates, Per-Second/Hourly Resource Dimensions, and Data Transfer Tiers  
**Scope:** Terraform Infrastructure (`vpc.tf`, `alb.tf`, `ecs_cluster.tf`, `ecs_services.tf`, `ec2_livekit.tf`, `rds_postgres.tf`, `secrets.tf`, `ecr.tf`)

---

## 1. Executive Summary

This report delivers a full architectural cost analysis and workload scaling projection for the **ScanCall AWS Cloud Infrastructure**. The architecture is structured as a resilient, multi-tier environment spanning two Availability Zones (`eu-west-1a` and `eu-west-1b`), separating serverless container execution (AWS Fargate), relational storage (Amazon RDS PostgreSQL), public traffic distribution (Application Load Balancer + Dual NAT Gateways), and real-time audio/video WebRTC streaming (LiveKit EC2).

### Monthly Cost Overview

| Deployment Profile | Compute & DB Specification | High Availability Setup | Estimated Baseline Cost / Month |
| :--- | :--- | :--- | :--- |
| **Production Baseline (Current TF)** | ECS (6 tasks / 5 vCPU / 10 GB), LiveKit `t3.large`, RDS `db.t4g.micro` | Dual AZ, Dual NAT Gateways, ALB | **$406.96 / month** (~$4,883/yr) |
| **Production Recommended (Scaled DB)** | ECS (6 tasks / 5 vCPU / 10 GB), LiveKit `t3.large`, RDS `db.t3.medium` | Dual AZ, Dual NAT Gateways, ALB | **$450.76 / month** (~$5,409/yr) |
| **Production Enterprise (Multi-AZ DB)** | ECS (6 tasks / 5 vCPU / 10 GB), LiveKit `t3.large`, RDS `db.t3.medium` Multi-AZ | Dual AZ, Dual NAT, Multi-AZ RDS | **$510.00 / month** (~$6,120/yr) |
| **Development / Staging Baseline** | ECS (3 tasks / 1.25 vCPU / 2.5 GB), LiveKit `t3.small`, RDS `db.t4g.micro` | Single NAT Gateway, Single AZ | **$159.94 / month** (~$1,919/yr) |

---

## 2. Infrastructure Inventory & Component-by-Component Pricing

Official unit pricing is based on the **AWS `eu-west-1` (Ireland)** region:

### 2.1. Dedicated Real-Time Media Node (LiveKit EC2)
* **EC2 Compute (`t3.large`):**
  * Sizing: 2 vCPUs, 8 GiB RAM (Burstable x86_64)
  * Unit Rate: **$0.0912 / hour**
  * Monthly Cost (730 hrs): `730 * $0.0912` = **$66.58 / month**
* **Root Storage (EBS gp3):**
  * Sizing: 20 GB encrypted gp3 SSD (includes 3,000 IOPS & 125 MB/s throughput baseline)
  * Unit Rate: **$0.088 / GB-month**
  * Monthly Cost: `20 * $0.088` = **$1.76 / month**
* **Elastic IP (IPv4 in-use):**
  * AWS Public IPv4 Unit Rate: **$0.005 / hour**
  * Monthly Cost: `730 * $0.005` = **$3.65 / month**
* **Total Component Cost:** **$71.99 / month**

### 2.2. Amazon ECS on AWS Fargate (Microservices Tier)
The system deploys 3 microservices across private application subnets: `api-gateway`, `core-service`, and `call-service`.

#### Task Allocation Matrix (Production: 2 Replicas per Service)
* `api-gateway` (2 tasks): 0.50 vCPU, 1.0 GiB RAM each = 1.00 vCPU, 2.0 GiB RAM
* `core-service` (2 tasks): 1.00 vCPU, 2.0 GiB RAM each = 2.00 vCPU, 4.0 GiB RAM
* `call-service` (2 tasks): 1.00 vCPU, 2.0 GiB RAM each = 2.00 vCPU, 4.0 GiB RAM
* **Combined Total:** **6 tasks | 5.00 vCPU | 10.00 GiB RAM**

#### Fargate Rate Breakdown (`eu-west-1` Linux/x86)
* **vCPU Rate:** **$0.0456 per vCPU-hour** -> `5.0 vCPU * 730 hours * $0.0456` = **$166.44 / month**
* **Memory Rate:** **$0.0050 per GB-hour** -> `10.0 GB * 730 hours * $0.0050` = **$36.50 / month**
* **Total Fargate Compute:** **$202.94 / month**

### 2.3. Amazon RDS for PostgreSQL (Database Tier)
* **Configured Default (`terraform.tfvars` - `db.t4g.micro` Single-AZ):**
  * Compute: ~$0.018 / hr = $13.14 / mo
  * Storage (20 GB gp3 @ $0.115/GB): $2.30 / mo
  * **Total: $15.44 / month**
* **Production Recommended (`db.t3.medium` Single-AZ):**
  * Compute: ~$0.078 / hr = $56.94 / mo
  * Storage (20 GB gp3): $2.30 / mo
  * **Total: $59.24 / month**
* **Enterprise Multi-AZ Standby (`db.t3.medium` Multi-AZ):**
  * Compute: ~$0.156 / hr = $113.88 / mo
  * Storage (20 GB gp3 Multi-AZ @ $0.230/GB): $4.60 / mo
  * **Total: $118.48 / month**

### 2.4. VPC Networking, NAT Gateways & Elastic IPs
In production (`single_nat_gateway = false`), two NAT Gateways are provisioned in AZ1 and AZ2 for high availability.
* **NAT Gateways (2 units):** `2 * 730 * $0.048` = **$70.08 / month**
* **Elastic IPs for NAT Gateways (2 units):** `2 * 730 * $0.005` = **$7.30 / month**
* **Total Fixed VPC Egress Baseline:** **$77.38 / month**
* **Data Processing Rate (Variable):** **$0.048 per GB** processed outbound through the NAT Gateways.

### 2.5. Application Load Balancer (ALB) & Edge Security
* **ALB Base Hourly:** `730 * $0.0225` = **$16.43 / month**
* **ALB Public IPv4 Addresses (2 AZs):** `2 * 730 * $0.005` = **$7.30 / month**
* **LCU Baseline (1 LCU):** `730 * $0.008` = **$5.84 / month**
* **AWS Certificate Manager (ACM):** Public SSL/TLS certificates and automated renewal: **$0.00 (Free)**
* **Total ALB Baseline:** **$29.57 / month**

### 2.6. Managed Auxiliary Services
* **AWS Secrets Manager:** 2 secrets (`db-credentials` & `app-secrets`): **$0.80 / month**
* **Amazon ECR:** 3 repos with 10 image lifecycle retention (~15 GB): **$1.50 / month**
* **Amazon CloudWatch:** Logs ingestion (5 GB/mo) + Container Insights metrics: **~$7.50 / month**
* **Total Auxiliaries:** **$9.80 / month**

---

## 3. Official AWS Cost Scaling Formulas

### Scaling Dimension 1: LiveKit WebRTC Real-Time Media (Audio/Video Egress)
LiveKit audio and video media routes directly between client devices and the LiveKit EC2 instance over **UDP 50000–60000**.
* Media traffic **never passes through the ALB or NAT Gateway**, completely avoiding NAT processing charges.
* Billed under **AWS Data Transfer Out to Internet (Egress)**.

#### AWS Data Transfer Out Tiers (eu-west-1):
* First 100 GB / month: **$0.00 (Free)**
* Next 9.9 TB / month (up to 10 TB): **$0.090 per GB**
* Next 40 TB / month (10 TB to 50 TB): **$0.085 per GB**
* Next 100 TB / month (50 TB to 150 TB): **$0.070 per GB**

#### Media Bitrate & Data Consumption Modeling:
* **Video Call (720p 30fps WebRTC):** ~1.5 Mbps per stream = **~675 MB per video stream hour** (~1.35 GB / 1-on-1 call hour).
* **Audio-Only Call (Opus 48kHz):** ~50 kbps = **~22.5 MB per audio stream hour**.

#### LiveKit EC2 Sizing:
* `t3.large` (2 vCPU, 8 GB RAM): Handles up to **~150–250 concurrent participant tracks**.
* When concurrent calls exceed 200: Upgrade to Compute-Optimized Graviton3 instances:
  * `c7g.xlarge` (4 vCPU, 8 GB RAM): **$0.1445 / hour** (~$105.48/month).
  * `c7g.2xlarge` (8 vCPU, 16 GB RAM): **$0.2890 / hour** (~$210.97/month).

### Scaling Dimension 2: Application Traffic & ECS Fargate Autoscaling
* **Cost per added `api-gateway` task (0.5 vCPU, 1 GB RAM):** **$0.0278 / task-hour** ($20.29 / month if run 24/7).
* **Cost per added `core-service` or `call-service` task (1.0 vCPU, 2 GB RAM):** **$0.0556 / task-hour** ($40.59 / month if run 24/7).
* **Application Load Balancer (ALU) Scaling:** **$0.008 per LCU-hour** (1 LCU provides 25 new connections/sec, 3,000 active connections/min, 1 GB processed/hr, or 1,000 rule evaluations/sec).

### Scaling Dimension 3: NAT Gateway Data Processing
For outbound API traffic (APNs, Firebase FCM, SMS API, relay triggers):
$$\text{NAT Egress Cost} = \text{Volume in GB} \times \$0.048 + \text{Internet Egress} \times \$0.090 = \mathbf{\$0.138 \text{ per GB}}$$

### Scaling Dimension 4: RDS PostgreSQL Storage & IOPS Scaling
* `allocated_storage = 20` and `max_allocated_storage = 100`.
* Incremental storage beyond 20 GB costs **$0.115 per GB-month** (e.g., reaching 100 GB adds **+$9.20 / month**).
* Baseline 20–100 GB gp3 storage tier includes 3,000 IOPS and 125 MB/s throughput baseline at no additional charge.

---

## 4. Workload Tier Scenarios (Monthly Projections)

| Cost Category | Baseline (0 users) | Tier 1: Startup (1k Users, 5k call-mins) | Tier 2: Growth (10k Users, 50k call-mins) | Tier 3: Scale-Up (50k Users, 250k call-mins) |
| :--- | :--- | :--- | :--- | :--- |
| **Active MAU / Day** | 0 users | 1,000 MAU / ~50 daily calls | 10,000 MAU / ~500 daily calls | 50,000 MAU / ~2,500 daily calls |
| **LiveKit EC2 Server** | $71.83 (`t3.large`) | $71.83 (`t3.large`) | $105.48 (`c7g.xlarge`) | $210.97 (`c7g.2xlarge`) |
| **WebRTC Media Egress** | $0.00 (0 GB) | $0.00 (Free 100 GB tier) | $45.00 (500 GB egress) | $225.00 (2.5 TB egress) |
| **ECS Fargate Compute** | $202.94 (6 tasks) | $202.94 (6 tasks) | $243.53 (7 tasks avg) | $365.29 (10 tasks autoscaled) |
| **RDS PostgreSQL** | $59.24 (`db.t3.med`) | $59.24 (`db.t3.med`) | $65.00 (`db.t3.med` + 70GB) | $125.00 (`db.m6g.large` + 100GB) |
| **Dual NAT Gateways** | $77.38 (Fixed) | $78.34 (+20 GB processed) | $82.18 (+100 GB processed) | $101.38 (+500 GB processed) |
| **Application Load Balancer** | $29.57 (1 LCU) | $31.80 (1.4 LCU) | $39.50 (2.7 LCU) | $62.00 (6.5 LCU) |
| **Auxiliary (CloudWatch/Secrets/ECR)** | $9.80 | $14.65 | $22.71 | $45.76 (High log volume) |
| **TOTAL ESTIMATED MONTHLY** | **$450.76** | **$478.80** | **$573.40** | **$1,085.40** |
| **ANNUALIZED RUN-RATE** | **~$5,409 / yr** | **~$5,745 / yr** | **~$6,880 / yr** | **~$13,024 / yr** |

---

## 5. Cost Optimization & Strategic Savings Recommendations

1. **Enable Compute Savings Plans (Save 28% – 38%):**
   * Committing to a 1-year No Upfront Compute Savings Plan lowers Fargate from $202.94 to ~$144.10/mo and LiveKit EC2 from $66.58 to ~$46.20/mo, saving **~$79.22 / month (~$950 / year)**.
2. **Dev / Staging Single NAT Gateway:**
   * Set `single_nat_gateway = true` in non-prod environments to eliminate 1 NAT Gateway and 1 EIP, saving **$38.69 / month per non-prod environment (~$464 / year)**.
3. **Upgrade to Graviton3 Instances:**
   * Switching LiveKit from `t3.large` to `t4g.large` ($0.0768/hr) and RDS from `db.t3.medium` to `db.t4g.medium` ($0.065/hr) saves **~$20.00 / month** while delivering superior packet routing performance.
4. **VPC Gateway Endpoints for S3 (100% Free):**
   * Provisioning a free S3 Gateway endpoint routes container layer pulls and S3 traffic off NAT Gateways, eliminating data processing fees.
5. **Summary Comparison:**
   * **Current Production Baseline:** **$450.76 / month** ($5,409 / year)
   * **Optimized Production Baseline:** **$354.50 / month** ($4,254 / year)
   * **Net Annual Savings:** **~$1,155 / year (21% overall reduction)**

