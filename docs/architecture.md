# Azure Architecture Diagrams

This document provides architecture diagrams for deploying Redis Stack in different Azure environments.

## Table of Contents

- [Azure Container Instances (ACI) Architecture](#azure-container-instances-aci-architecture)
- [Azure App Service Architecture](#azure-app-service-architecture)
- [Azure Kubernetes Service (AKS) Architecture](#azure-kubernetes-service-aks-architecture)
- [Monitoring Integration Architecture](#monitoring-integration-architecture)

## Azure Container Instances (ACI) Architecture

```mermaid
graph TD
    subgraph "Azure"
        subgraph "Resource Group"
            ACI[Azure Container Instance<br/>Redis Stack]
            Storage[Azure Storage Account]
            FileShare[Azure File Share<br/>Redis Data]
            AppInsights[Application Insights]
            
            ACI -->|Mounts| FileShare
            Storage -->|Hosts| FileShare
            ACI -->|Sends Logs| AppInsights
            
            subgraph "Networking"
                PublicIP[Public IP Address]
                NSG[Network Security Group]
                PublicIP -->|Protected by| NSG
                ACI -->|Exposed via| PublicIP
            end
        end
        
        Client[Client Application] -->|Connect to Redis<br/>port 6379| PublicIP
        Browser[Web Browser] -->|RedisInsight UI<br/>port 8001| PublicIP
    end
    
    style ACI fill:#4285F4,stroke:#333,stroke-width:2px,color:white
    style Storage fill:#34A853,stroke:#333,stroke-width:2px,color:white
    style FileShare fill:#FBBC05,stroke:#333,stroke-width:2px,color:white
    style PublicIP fill:#EA4335,stroke:#333,stroke-width:2px,color:white
    style NSG fill:#5F6368,stroke:#333,stroke-width:2px,color:white
    style AppInsights fill:#8E44AD,stroke:#333,stroke-width:2px,color:white
```

## Azure App Service Architecture

```mermaid
graph TD
    subgraph "Azure"
        subgraph "Resource Group"
            AppService[Azure App Service<br/>Web App for Containers]
            AppServicePlan[App Service Plan]
            Storage[Azure Storage Account]
            FileShare[Azure File Share<br/>Redis Data]
            AppInsights[Application Insights]
            
            AppService -->|Runs on| AppServicePlan
            AppService -->|Mounts| FileShare
            Storage -->|Hosts| FileShare
            AppService -->|Sends Logs| AppInsights
            
            subgraph "Networking"
                VNET[Virtual Network]
                NSG[Network Security Group]
                VNET -->|Protected by| NSG
                AppService -->|Can be integrated with| VNET
            end
        end
        
        Client[Client Application] -->|Connect to Redis<br/>port 6379| AppService
        Browser[Web Browser] -->|RedisInsight UI<br/>Custom Domain| AppService
    end
    
    style AppService fill:#4285F4,stroke:#333,stroke-width:2px,color:white
    style AppServicePlan fill:#34A853,stroke:#333,stroke-width:2px,color:white
    style Storage fill:#FBBC05,stroke:#333,stroke-width:2px,color:white
    style FileShare fill:#FBBC05,stroke:#333,stroke-width:2px,color:white
    style VNET fill:#EA4335,stroke:#333,stroke-width:2px,color:white
    style NSG fill:#5F6368,stroke:#333,stroke-width:2px,color:white
    style AppInsights fill:#8E44AD,stroke:#333,stroke-width:2px,color:white
```

## Azure Kubernetes Service (AKS) Architecture

```mermaid
graph TD
    subgraph "Azure"
        subgraph "Resource Group"
            AKS[Azure Kubernetes Service]
            ACR[Azure Container Registry]
            AppInsights[Application Insights]
            
            subgraph "Managed Kubernetes Cluster"
                Node1[AKS Node 1]
                Node2[AKS Node 2]
                
                subgraph "Redis Stack Pods"
                    Pod[Redis Stack Pod]
                    Sidecar[Monitoring Sidecar]
                    PV[Persistent Volume]
                    PVC[Persistent Volume Claim]
                    Pod -->|Uses| PVC
                    PVC -->|Claims| PV
                    Pod -->|Shares logs with| Sidecar
                    Sidecar -->|Sends telemetry| AppInsights
                end
                
                subgraph "Kubernetes Services"
                    SVC[Redis Service]
                    Pod -->|Exposed by| SVC
                end
                
                subgraph "Load Balancing"
                    LB[Azure Load Balancer]
                    SVC -->|Exposed through| LB
                end
            end
            
            AKS -->|Contains| Node1
            AKS -->|Contains| Node2
            AKS -->|Pulls images from| ACR
        end
        
        Client[Client Application] -->|Connect to Redis| LB
        Browser[Web Browser] -->|RedisInsight UI| LB
    end
    
    style AKS fill:#4285F4,stroke:#333,stroke-width:2px,color:white
    style ACR fill:#FBBC05,stroke:#333,stroke-width:2px,color:white
    style Node1 fill:#34A853,stroke:#333,stroke-width:2px,color:white
    style Node2 fill:#34A853,stroke:#333,stroke-width:2px,color:white
    style Pod fill:#EA4335,stroke:#333,stroke-width:2px,color:white
    style Sidecar fill:#8E44AD,stroke:#333,stroke-width:2px,color:white
    style PV fill:#5F6368,stroke:#333,stroke-width:2px,color:white
    style PVC fill:#5F6368,stroke:#333,stroke-width:2px,color:white
    style SVC fill:#4285F4,stroke:#333,stroke-width:2px,color:white
    style LB fill:#EA4335,stroke:#333,stroke-width:2px,color:white
    style AppInsights fill:#8E44AD,stroke:#333,stroke-width:2px,color:white
```

## Monitoring Integration Architecture

```mermaid
graph TD
    subgraph "Redis Stack with Application Insights"
        subgraph "Container Group / Pod"
            Redis[Redis Stack Container]
            Sidecar[App Insights Sidecar]
            LogVol[Shared Log Volume]
            
            Redis -->|Writes logs to| LogVol
            Sidecar -->|Reads logs from| LogVol
        end
        
        AppInsights[Azure Application Insights]
        LogAnalytics[Log Analytics Workspace]
        Dashboard[Azure Dashboard]
        Alerts[Azure Alerts]
        
        Sidecar -->|Sends structured logs| AppInsights
        AppInsights -->|Stores data in| LogAnalytics
        LogAnalytics -->|Visualized in| Dashboard
        LogAnalytics -->|Triggers| Alerts
    end
    
    style Redis fill:#EA4335,stroke:#333,stroke-width:2px,color:white
    style Sidecar fill:#8E44AD,stroke:#333,stroke-width:2px,color:white
    style LogVol fill:#FBBC05,stroke:#333,stroke-width:2px,color:white
    style AppInsights fill:#4285F4,stroke:#333,stroke-width:2px,color:white
    style LogAnalytics fill:#34A853,stroke:#333,stroke-width:2px,color:white
    style Dashboard fill:#5F6368,stroke:#333,stroke-width:2px,color:white
    style Alerts fill:#DB4437,stroke:#333,stroke-width:2px,color:white
```

## Notes on Architecture Diagrams

These diagrams are created using Mermaid markdown syntax, which can be rendered by many markdown viewers including GitHub. To view these diagrams:

1. View this file in GitHub, which natively renders Mermaid diagrams
2. Use a Markdown editor that supports Mermaid (like VS Code with extensions)
3. Use an online Mermaid editor like [Mermaid Live Editor](https://mermaid-js.github.io/mermaid-live-editor/)
4. Install the Mermaid CLI to render these diagrams locally
