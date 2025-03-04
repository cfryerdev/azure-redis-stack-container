@description('Azure region for the deployment')
param location string

@description('Base name for the deployment resources')
param deploymentName string

@description('Environment type (dev, test, prod)')
param environmentType string = 'dev'

@description('Container image to deploy - for when using custom image')
param containerImage string = 'redis/redis-stack:latest'

@description('Azure Container Registry name')
param containerRegistryName string = ''

@description('Whether to enable Application Insights for monitoring')
param enableAppInsights bool = false

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string = ''

@description('Virtual Network name for AKS')
param vnetName string = ''

@description('Subnet ID for AKS if using virtual network')
param subnetId string = ''

@description('Tags for the resources')
param tags object

// AKS cluster for Redis Stack
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-02-01' = {
  name: '${deploymentName}-${environmentType}-aks'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: '${deploymentName}-${environmentType}'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        maxPods: 110
        vnetSubnetID: !empty(subnetId) ? subnetId : null
      }
    ]
    networkProfile: {
      networkPlugin: !empty(subnetId) ? 'azure' : 'kubenet'
      loadBalancerSku: 'standard'
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: enableAppInsights ? {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      } : {
        enabled: false
      }
    }
  }
}

// Reference to Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (enableAppInsights) {
  name: '${deploymentName}-${environmentType}-logs'
}

// Optional ACR role assignment
module acrPullRole 'acr-role.bicep' = if (!empty(containerRegistryName)) {
  name: 'acrPullRole'
  params: {
    aksServicePrincipalId: aksCluster.identity.principalId
    acrName: containerRegistryName
  }
}

// Generate K8s configuration files
resource redisConfigMap 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${deploymentName}-${environmentType}-redis-config'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azCliVersion: '2.45.0'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'DEPLOYMENT_NAME'
        value: deploymentName
      }
      {
        name: 'ENVIRONMENT'
        value: environmentType
      }
      {
        name: 'CONTAINER_IMAGE'
        value: containerImage
      }
      {
        name: 'APP_INSIGHTS_ENABLED'
        value: string(enableAppInsights)
      }
      {
        name: 'APP_INSIGHTS_CONNECTION_STRING'
        value: enableAppInsights ? appInsightsConnectionString : ''
      }
    ]
    scriptContent: '''
      #!/bin/bash
      
      # Create output directory for K8s files
      mkdir -p $AZ_SCRIPTS_OUTPUT_PATH/k8s
      
      # Create namespace YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/namespace.yaml << EOF
      apiVersion: v1
      kind: Namespace
      metadata:
        name: redis-stack
        labels:
          name: redis-stack
      EOF
      
      # Create storage class YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/storage-class.yaml << EOF
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: redis-stack-storage
      provisioner: kubernetes.io/azure-disk
      parameters:
        storageaccounttype: Standard_LRS
        kind: Managed
      EOF
      
      # Create persistent volume claim YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/pvc.yaml << EOF
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: redis-data
        namespace: redis-stack
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: redis-stack-storage
        resources:
          requests:
            storage: 10Gi
      EOF
      
      # Create redis config YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/redis-config.yaml << EOF
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: redis-config
        namespace: redis-stack
      data:
        redis.conf: |
          bind 0.0.0.0
          protected-mode yes
          port 6379
          tcp-backlog 511
          timeout 0
          tcp-keepalive 300
          
          # Persistence
          save 900 1
          save 300 10
          save 60 10000
          stop-writes-on-bgsave-error yes
          rdbcompression yes
          rdbchecksum yes
          dbfilename dump.rdb
          dir /data
          
          # AOF
          appendonly yes
          appendfilename "appendonly.aof"
          appendfsync everysec
          no-appendfsync-on-rewrite no
          auto-aof-rewrite-percentage 100
          auto-aof-rewrite-min-size 64mb
          aof-load-truncated yes
          aof-use-rdb-preamble yes
          
          # Memory
          maxmemory-policy noeviction
          
          # Logging
          loglevel notice
          logfile /var/log/redis/redis.log
      EOF
      
      # Create the redis deployment YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/redis-deployment.yaml << EOF
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: redis-stack
        namespace: redis-stack
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: redis-stack
        template:
          metadata:
            labels:
              app: redis-stack
          spec:
            volumes:
              - name: redis-data
                persistentVolumeClaim:
                  claimName: redis-data
              - name: redis-config
                configMap:
                  name: redis-config
              - name: redis-logs
                emptyDir: {}
            containers:
              - name: redis-stack
                image: $CONTAINER_IMAGE
                ports:
                  - containerPort: 6379
                    name: redis
                  - containerPort: 8001
                    name: redisinsight
                volumeMounts:
                  - name: redis-data
                    mountPath: /data
                  - name: redis-config
                    mountPath: /redis-stack.conf
                    subPath: redis.conf
                  - name: redis-logs
                    mountPath: /var/log/redis
                resources:
                  requests:
                    memory: "1Gi"
                    cpu: "500m"
                  limits:
                    memory: "2Gi"
                    cpu: "1000m"
                env:
                  - name: REDIS_ARGS
                    valueFrom:
                      secretKeyRef:
                        name: redis-secrets
                        key: redis-password
      EOF
      
      if [ "$APP_INSIGHTS_ENABLED" == "true" ]; then
        # Append app insights sidecar to the deployment
        cat >> $AZ_SCRIPTS_OUTPUT_PATH/k8s/redis-deployment.yaml << EOF
              - name: app-insights-sidecar
                image: mcr.microsoft.com/azure-monitor/applicationinsights/python:latest
                volumeMounts:
                  - name: redis-logs
                    mountPath: /var/log/redis
                    readOnly: true
                env:
                  - name: REDIS_LOG_PATH
                    value: "/var/log/redis/redis.log"
                  - name: APP_INSIGHTS_CONNECTION_STRING
                    value: "$APP_INSIGHTS_CONNECTION_STRING"
                  - name: APP_INSIGHTS_ROLE_NAME
                    value: "redis-stack"
                  - name: APP_INSIGHTS_ROLE_INSTANCE
                    valueFrom:
                      fieldRef:
                        fieldPath: metadata.name
                  - name: LOG_LEVEL
                    value: "info"
                  - name: SAMPLING_PERCENTAGE
                    value: "100"
                resources:
                  requests:
                    memory: "256Mi"
                    cpu: "200m"
                  limits:
                    memory: "512Mi"
                    cpu: "500m"
      EOF
      fi
      
      # Create the service YAML
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/service.yaml << EOF
      apiVersion: v1
      kind: Service
      metadata:
        name: redis-stack
        namespace: redis-stack
      spec:
        selector:
          app: redis-stack
        ports:
          - port: 6379
            targetPort: 6379
            name: redis
          - port: 8001
            targetPort: 8001
            name: redisinsight
        type: LoadBalancer
      EOF
      
      # Create a placeholder for secrets
      cat > $AZ_SCRIPTS_OUTPUT_PATH/k8s/secrets-template.yaml << EOF
      apiVersion: v1
      kind: Secret
      metadata:
        name: redis-secrets
        namespace: redis-stack
      type: Opaque
      stringData:
        redis-password: "REPLACE_WITH_YOUR_SECURE_PASSWORD"
      EOF
      
      # Create a README with deployment instructions
      cat > $AZ_SCRIPTS_OUTPUT_PATH/README.md << EOF
      # Redis Stack Kubernetes Deployment
      
      This directory contains all the Kubernetes manifests needed to deploy Redis Stack on your AKS cluster.
      
      ## Prerequisites
      
      - AKS cluster deployed and configured with kubectl
      - Kubernetes CLI (kubectl) installed
      
      ## Deployment Steps
      
      1. Apply the namespace configuration:
         \`\`\`bash
         kubectl apply -f k8s/namespace.yaml
         \`\`\`
      
      2. Create the Redis password secret (edit the template first):
         \`\`\`bash
         # Edit the secrets-template.yaml file to set your password
         kubectl apply -f k8s/secrets-template.yaml
         \`\`\`
      
      3. Apply the storage configuration:
         \`\`\`bash
         kubectl apply -f k8s/storage-class.yaml
         kubectl apply -f k8s/pvc.yaml
         \`\`\`
      
      4. Apply the Redis configuration:
         \`\`\`bash
         kubectl apply -f k8s/redis-config.yaml
         \`\`\`
      
      5. Deploy Redis Stack:
         \`\`\`bash
         kubectl apply -f k8s/redis-deployment.yaml
         \`\`\`
      
      6. Create the service to expose Redis:
         \`\`\`bash
         kubectl apply -f k8s/service.yaml
         \`\`\`
      
      7. Get the external IP to connect to Redis:
         \`\`\`bash
         kubectl get svc -n redis-stack
         \`\`\`
      
      ## Connection Information
      
      - Redis endpoint: redis-stack.redis-stack.svc.cluster.local:6379 (internal)
      - RedisInsight UI: http://<EXTERNAL-IP>:8001 (once the LoadBalancer has an IP assigned)
      EOF
    '''
    supportingScriptUris: []
  }
}

// Outputs for AKS deployment
output aksClusterId string = aksCluster.id
output kubeConfigCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${aksCluster.name}'
output redisEndpoint string = '<AKS-EXTERNAL-IP>:6379 (Available after kubectl deployment)'
output redisInsightEndpoint string = 'http://<AKS-EXTERNAL-IP>:8001 (Available after kubectl deployment)'
output k8sManifestsPath string = redisConfigMap.properties.outputs.AZ_SCRIPTS_OUTPUT_PATH
