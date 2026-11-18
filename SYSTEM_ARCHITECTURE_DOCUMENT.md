# ScanCall AWS Cloud Infrastructure Specification

## 1. Executive Summary

This document specifies the technical architecture for the **ScanCall AWS Cloud Infrastructure**. The architecture is structured as a multi-tier, high-availability, microservices-based system running inside an Amazon Virtual Private Cloud (VPC) across two Availability Zones (`eu-west-1a` and `eu-west-1b`). 

It separates ingress/egress networking, serverless container execution (AWS Fargate), persistent relational storage (Amazon RDS PostgreSQL), and dedicated real-time audio/video media routing (LiveKit WebRTC).

---

## 2. High-Level Architecture Overview

The system is organized into five distinct functional layers:
1. **Client Access Layer**: Endpoints for standard app users and real-time WebRTC media visitors.
2. **Security & Perimeter Layer**: Edge encryption, TLS termination, and VPC routing via AWS Certificate Manager (ACM) and an Internet Gateway (IGW).
3. **Public Subnet Tier (Multi-AZ)**: Ingress routing via an Application Load Balancer (ALB) and redundant outbound egress via dual NAT Gateways with Elastic IPs.
4. **Private Application Subnet Tier (Multi-AZ)**: Fully isolated Amazon ECS Fargate cluster hosting containerized microservices (`api-gateway`, `core-service`, and `call-service`).
5. **Private Data Subnet Tier (Multi-AZ)**: Dedicated private subnets housing Amazon RDS PostgreSQL without internet exposure.
6. **Isolated Real-Time Media Node**: A dedicated EC2 instance running the LiveKit media server equipped with a static Elastic IP for low-latency WebRTC streaming.

---

## 3. Tier-by-Tier Architectural Breakdown

### 3.1. Client Access Layer
The architecture distinguishes between two user traffic profiles:
* **Web & Mobile Clients**: Regular application clients performing user onboarding, authentication, device management, and call setup. They communicate over standard secure protocols (`HTTPS: 443` / `WSS: 443`).
* **Visitor Clients (WebRTC Video & Voice)**: Callers and recipients participating in active two-way media sessions. They establish direct peer connections to the LiveKit media server for voice and video transmission.

---

### 3.2. Security & Edge Layer
* **AWS Certificate Manager (ACM)**: Manages and auto-renews public SSL/TLS certificates to enforce end-to-end encryption.
* **Internet Gateway (IGW)**: The VPC edge component that allows public inbound traffic to reach the Application Load Balancer and outbound traffic from NAT Gateways to reach external endpoints.

---

### 3.3. Amazon VPC (`10.0.0.0/16`) Network Topology

The VPC is divided into three isolated tiers spanning two Availability Zones:

#### A. Public Subnets (Multi-AZ)
* **Application Load Balancer (ALB)**: Deployed across both `eu-west-1a` and `eu-west-1b`. It acts as the single public entry point for application APIs and WebSocket signaling, terminating TLS and load balancing incoming traffic.
* **Dual NAT Gateways**:
  * **NAT Gateway 1** (`eu-west-1a`) with a dedicated Elastic IP.
  * **NAT Gateway 2** (`eu-west-1b`) with a dedicated Elastic IP.
  * **Purpose**: Provides independent, fault-tolerant outbound internet connectivity for private ECS tasks (e.g., Apple APNs, Firebase FCM, third-party APIs, and package updates) without exposing private containers to inbound traffic.

#### B. Private Application Subnets (Multi-AZ)
Contains the serverless **Amazon ECS Fargate Cluster** across both AZs:
* **API Gateway Service (Port 8000)**:
  * Receives forwarded traffic directly from the ALB.
  * Handles authentication verification, CORS, and request dispatching.
  * Dispatches requests to internal services using private internal routing.
* **Core Service (Port 8080)**:
  * Encapsulates core business domains: authentication, site configuration, call-points, and device permissions.
  * Communicates internally with the API Gateway and directly queries RDS PostgreSQL.
* **Calling Service (Port 8081)**:
  * Orchestrates call handshakes, rings, timeouts, and WebSocket notifications (`WS & Call Routing`).
  * Integrates with the LiveKit Media Server over WebSockets to provision call rooms, generate participant tokens, and track call lifecycle events.

#### C. Private Data Subnets (Multi-AZ)
* **Amazon RDS PostgreSQL**:
  * Hosted in isolated subnets with zero internet ingress or egress.
  * Accepts database traffic (`TCP: 5432`) strictly from the `core-service` and `call-service` security groups.
  * Includes automated backups, encryption at rest via AWS KMS (GP3 storage), and multi-AZ failover capability.

---

### 3.4. Dedicated LiveKit Media Server (EC2)
* **Compute Specification**: EC2 `t3.large` running Ubuntu 22.04 LTS and Docker.
* **Elastic IP**: A static public IPv4 address dedicated to media streaming.
* **Port Allocations**:
  * **HTTP / HTTPS**: `TCP 80`, `TCP 443` (Web traffic and TLS termination)
  * **Signaling / HTTP**: `TCP 7880`
  * **TCP Media Fallback**: `TCP 7881`
  * **TURN over TLS & UDP**: `TCP 7882`, `UDP 3478`
  * **WebRTC Voice & Video Media**: High-throughput UDP range `50000–60000`
* **Connectivity**:
  * **Signaling & Room Control**: Managed via a secure WebSocket connection between the internal `call-service` and LiveKit.
  * **Direct Streaming**: Clients connect directly via WebRTC using ICE/STUN/TURN candidates pinned to the Elastic IP.

---

## 4. End-to-End Traffic Flows

### Flow 1: Standard API & Authentication
1. **Client** initiates `HTTPS: 443` to the application endpoint.
2. **Security Layer**: ACM terminates TLS at the **ALB**.
3. **ALB** forwards the request to **API Gateway Service (Port 8000)** in the private application subnet.
4. **API Gateway** routes the request to **Core Service (Port 8networking and 080)** via private internal routing.
5. **Core Service** queries **Amazon RDS PostgreSQL** (Port 5432) and returns the response.

### Flow 2: Call Initiation & Signaling
1. **Caller Client** sends a call invitation via WebSocket (`WSS`) through the **ALB** to **API Gateway**.
2. **API Gateway** routes the request to **Calling Service (Port 8081)**.
3. **Calling Service** creates a call record in **RDS PostgreSQL** and connects to the **LiveKit Media Server** via WebSockets to create a dedicated room and generate room access tokens.
4. **Calling Service** returns the generated token and room credentials back to the caller and notifies the recipient (via Push Notification / WebSocket).

### Flow 3: WebRTC Media Stream (Voice & Video)
1. Both client devices receive their LiveKit room tokens.
2. Clients initiate direct peer-to-server WebRTC handshakes (`WebRTC / signaling`) to the **LiveKit Media Server** Elastic IP.
3. Audio and video streams bypass the ALB and ECS cluster entirely, flowing directly over **UDP 50000–60000** for ultra-low latency.

---

## 5. Security & Isolation Matrix

| Component | Network Zone | Inbound Rules | Outbound Rules |
| :--- | :--- | :--- | :--- |
| **ALB** | Public Subnets | `0.0.0.0/0` on `443` (HTTPS) & `80` (Redirect) | Port `8000` to API Gateway |
| **API Gateway** | Private App Subnets | Port `8000` from ALB SG | Port `8080` to Core SG, Port `8081` to Call SG, Port `443` via NAT |
| **Core Service** | Private App Subnets | Port `8080` from API Gateway SG | Port `5432` to RDS SG, Port `443` via NAT |
| **Calling Service** | Private App Subnets | Port `8081` from API Gateway SG | Port `5432` to RDS SG, Ports `7880/7881` to LiveKit SG, Port `443` via NAT |
| **LiveKit Server** | Public Subnet / Dedicated | `0.0.0.0/0` on `7880`, `7881`, `50000-60000/udp` | Port `443` to Internet |
| **RDS PostgreSQL**| Private Data Subnets| Port `5432` from Core & Call Service SGs | None (Isolated) |

