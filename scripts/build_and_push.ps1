<#
.SYNOPSIS
    Builds Docker images for ScanCall microservices and pushes them to AWS ECR.
.DESCRIPTION
    1. Obtains AWS Account ID and ECR login credentials.
    2. Builds Docker images for:
       - scancall/api-gateway
       - scancall/core-service
       - scancall/call-service
    3. Tags images with both 'latest' and timestamp/git-commit.
    4. Pushes images to AWS ECR.
    5. Optionally triggers ECS service force-new-deployment.
#>

[CmdletBinding()]
param (
    [string]$Region = "eu-west-1",
    [string]$Environment = "prod",
    [switch]$RedeployECS = $true
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " ScanCall: Build & Push Microservices to AWS ECR" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check AWS CLI and Docker
try {
    $callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
    $accountId = $callerIdentity.Account
    Write-Host "[✓] AWS Account: $accountId in Region: $Region" -ForegroundColor Green
} catch {
    Write-Error "Failed to execute 'aws sts get-caller-identity'. Please configure AWS credentials (aws configure)."
    exit 1
}

try {
    docker version | Out-Null
    Write-Host "[✓] Docker is running." -ForegroundColor Green
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop and retry."
    exit 1
}

$ecrRegistry = "$accountId.dkr.ecr.$Region.amazonaws.com"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# 2. Authenticate Docker with ECR
Write-Host "`n--> Authenticating Docker with ECR registry ($ecrRegistry)..." -ForegroundColor Yellow
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ecrRegistry

if ($LASTEXITCODE -ne 0) {
    Write-Error "ECR authentication failed."
    exit 1
}

# Resolve root workspace path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path "$scriptDir\..\..").Path

# Microservices to build and push
$services = @(
    @{
        Name       = "api-gateway"
        RepoName   = "scancall/api-gateway"
        SourceDir  = Join-Path $rootDir "scancall_api_gateway"
        Dockerfile = Join-Path $rootDir "scancall_api_gateway\Dockerfile"
    },
    @{
        Name       = "core-service"
        RepoName   = "scancall/core-service"
        SourceDir  = Join-Path $rootDir "scancall_backend_phase1"
        Dockerfile = Join-Path $rootDir "scancall_backend_phase1\Dockerfile"
    },
    @{
        Name       = "call-service"
        RepoName   = "scancall/call-service"
        SourceDir  = Join-Path $rootDir "scancall-call-service"
        Dockerfile = Join-Path $rootDir "scancall-call-service\Dockerfile"
    }
)

foreach ($svc in $services) {
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " Building & Pushing: $($svc.RepoName)" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    $latestTag = "$ecrRegistry/$($svc.RepoName):latest"
    $versionTag = "$ecrRegistry/$($svc.RepoName):$timestamp"

    Write-Host "Building Docker image from: $($svc.SourceDir)" -ForegroundColor Yellow
    docker build -t $latestTag -t $versionTag -f $svc.Dockerfile $svc.SourceDir

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed for $($svc.Name)."
        exit 1
    }

    Write-Host "Pushing image tag: latest" -ForegroundColor Yellow
    docker push $latestTag

    Write-Host "Pushing image tag: $timestamp" -ForegroundColor Yellow
    docker push $versionTag

    Write-Host "[✓] Successfully pushed $($svc.RepoName)" -ForegroundColor Green
}

# 3. Trigger ECS Redeployment
if ($RedeployECS) {
    Write-Host "`n--> Triggering ECS Service redeployments..." -ForegroundColor Yellow
    $clusterName = "scancall-cluster-$Environment"

    foreach ($svc in $services) {
        $serviceName = "scancall-$($svc.Name)-$Environment"
        Write-Host "Updating ECS Service: $serviceName on cluster: $clusterName" -ForegroundColor Yellow
        aws ecs update-service --cluster $clusterName --service $serviceName --force-new-deployment --region $Region | Out-Null
    }
    Write-Host "[✓] All ECS services signaled for new deployment!" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL SERVICES SUCCESSFULLY BUILT & DEPLOYED TO AWS ECS!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
