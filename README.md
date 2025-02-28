# Azure Redis Stack with Persistence / Insights

A Docker-based implementation of Redis Stack with persistence, and monitoring with Azure Application Insights, similar to the Redis Enterprise offering in Azure.

## Summary Overview

Azure Redis Stack is an enterprise-grade, containerized Redis Stack deployment solution designed for production use in Azure. It combines the full Redis Stack (Redis with modules like RedisJSON, RediSearch, RedisGraph, RedisTimeSeries, and RedisBloom) with robust data persistence mechanisms (both RDB snapshots and AOF logs), comprehensive monitoring capabilities, and flexible deployment options across various Azure services.

The project follows cloud-native architecture patterns with Docker containerization, allowing developers to achieve Redis Enterprise-like capabilities with more granular configuration control and deployment flexibility. It addresses common challenges in production Redis deployments including data durability, observability, high availability, and secure access patterns.

Key technical components include a primary Redis Stack container with persistence configuration, optional monitoring sidecars for Azure Application Insights integration, and deployment templates for various Azure compute services.

This solution is suitable for development teams requiring advanced Redis capabilities with enterprise-grade reliability in Azure environments.

### About the Sidecar Pattern

This project implements the "sidecar pattern" for application monitoring with Azure Application Insights. In this pattern:

- The main Redis Stack container operates independently, focusing on its core responsibility of data storage
- A separate but co-located container (the "sidecar") handles the auxiliary function of log monitoring
- The sidecar container reads Redis logs, processes them, and forwards structured data to Azure Application Insights
- This separation of concerns allows for independent scaling, updating, and maintenance of each component
- The Redis container can be replaced or updated without affecting the monitoring configuration

The sidecar pattern is particularly effective for cloud-native architectures as it enables modular design while maintaining logical coupling of related services.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Documentation](#documentation)
  - [Getting Started](#getting-started)
  - [Deployment Options](#deployment-options)
  - [Architecture Diagrams](#architecture-diagrams)
  - [Insights and Monitoring](#monitoring)
  - [Version Information](#version-information)
  - [FAQ](#faq)
- [Project Structure](#project-structure)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## Overview

This project provides a containerized Redis Stack solution with enterprise-grade features like persistence, high availability, and monitoring capabilities. It's designed to give you the benefits of Redis Enterprise in Azure with more control over your infrastructure and configuration.

## Features

- **Redis Stack**: Includes the full Redis Stack with modules like RediSearch, RedisJSON, RedisTimeSeries, and RedisBloom
- **Dual Persistence**: Combines RDB snapshots and AOF logs for robust data durability
- **Docker-Ready**: Easy to deploy locally or in any container environment
- **Azure Deployment Options**: Multiple options for hosting in Azure
- **Backup Solutions**: Built-in backup script for data protection
- **RedisInsight Included**: Web-based GUI for Redis management and monitoring
- **Customizable Configuration**: Fully configurable Redis settings
- **Application Insights Integration**: Optional monitoring with Azure Application Insights using a sidecar pattern

## Documentation

### Getting Started

For local development and basic usage:

- [Getting Started Guide](docs/gettingstarted.md) - Setup, configuration, and local usage

### Deployment Options

For production deployment in Azure:

- [Azure Container Instances (ACI) Deployment](docs/deployment-aci.md) - Simple serverless container deployment
- [Azure App Service Deployment](docs/deployment-app-service.md) - PaaS deployment with managed infrastructure
- More deployment options coming soon!

### Architecture Diagrams

Visual representations of deployment architectures in Azure:

- [Azure Architecture Diagrams](docs/architecture.md) - Includes diagrams for:
  - Azure Container Instances deployment
  - Azure App Service deployment
  - Azure Kubernetes Service deployment
  - Secure production deployment pattern

### Monitoring

Monitor your Redis Stack instance:

- [Azure Application Insights Integration](docs/monitoring-app-insights.md) - Monitor Redis logs and performance with Application Insights
  - Sidecar container approach
  - Log forwarding configuration
  - Creating alerts based on Redis logs
  - Custom dashboard suggestions

### Version Information

This project is based on the official Redis Stack image which includes Redis and several modules:

- **Redis**: v7.4.x - Core Redis server
- **RedisJSON**: v2.4.x - Native JSON data type handling
- **RediSearch**: v2.6.x - Full-text search capability
- **RedisGraph**: v2.10.x - Graph database functionality
- **RedisTimeSeries**: v1.8.x - Time-series data structure
- **RedisBloom**: v2.4.x - Probabilistic data structures

For detailed version information and upgrade guidance, see our [Versions Guide](docs/versions.md).

### FAQ

Have questions? Check our [Frequently Asked Questions](docs/faq.md) for answers to common questions, including:

- Data persistence across container restarts
- Performance considerations
- Security best practices
- Deployment options
- Configuration guidance
- Troubleshooting tips

## Project Structure

```
azure-redis-stack/
├── Dockerfile                # Redis Stack container definition
├── redis.conf                # Redis configuration with persistence settings
├── docker-compose.yml        # Composition for local deployment
├── backup.sh                 # Backup script for Redis data
├── .env.example              # Template for environment variables
├── monitoring/               # Monitoring utilities
│   └── app-insights-sidecar/ # App Insights integration
│       ├── Dockerfile        # Sidecar container definition
│       ├── requirements.txt  # Python dependencies
│       └── log_forwarder.py  # Log processing script
└── docs/                     # Documentation directory
    ├── gettingstarted.md     # Guide for getting started
    ├── deployment-aci.md     # ACI deployment instructions
    ├── deployment-app-service.md # App Service deployment instructions
    ├── architecture.md       # Azure architecture diagrams
    ├── monitoring-app-insights.md # App Insights integration
    ├── versions.md           # Version information and upgrade guide
    └── faq.md                # Frequently Asked Questions
```

## Security Considerations

- **Password Protection**: Always set a strong Redis password in production
- **Network Security**: Use private networks and firewalls in Azure deployments
- **Regular Updates**: Keep the Redis Stack image updated with security patches
- **Encrypted Storage**: Consider encryption-at-rest for sensitive data
- **Access Control**: Implement proper access controls in production environments

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
