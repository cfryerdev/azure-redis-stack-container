#!/bin/bash

# Azure Redis Stack Deployment Script
# This script deploys the Redis Stack solution to Azure using Bicep templates

# Default values
location="eastus"
environment_type="dev"
deployment_type="aci"
deployment_name="redisstack"
parameters_file="parameters.json"
resource_group_name=""
update_params_only=false
redis_password=""
use_custom_password=false
container_memory=""
container_cpu=""
skip_confirmation=false

# Display help information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Deploy the Redis Stack solution to Azure"
  echo ""
  echo "Options:"
  echo "  -g, --resource-group    Resource group name"
  echo "  -l, --location          Azure region (default: eastus)"
  echo "  -e, --environment       Environment type: dev, test, prod (default: dev)"
  echo "  -t, --type              Deployment type: aci, app-service, aks (default: aci)"
  echo "  -n, --name              Base name for deployment resources (default: redisstack)"
  echo "  -p, --parameters        Path to parameters file (default: parameters.json)"
  echo "  -u, --update-params     Only update parameters file, don't deploy"
  echo "  --password              Set Redis password (more secure than in parameters file)"
  echo "  --memory                Set container memory in GB"
  echo "  --cpu                   Set container CPU cores"
  echo "  -y, --yes               Skip confirmation prompts"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --resource-group redis-stack-rg --location westus2 --environment prod --type app-service"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  
  case $key in
    -g|--resource-group)
      resource_group_name="$2"
      shift
      shift
      ;;
    -l|--location)
      location="$2"
      shift
      shift
      ;;
    -e|--environment)
      environment_type="$2"
      shift
      shift
      ;;
    -t|--type)
      deployment_type="$2"
      shift
      shift
      ;;
    -n|--name)
      deployment_name="$2"
      shift
      shift
      ;;
    -p|--parameters)
      parameters_file="$2"
      shift
      shift
      ;;
    -u|--update-params)
      update_params_only=true
      shift
      ;;
    --password)
      redis_password="$2"
      use_custom_password=true
      shift
      shift
      ;;
    --memory)
      container_memory="$2"
      shift
      shift
      ;;
    --cpu)
      container_cpu="$2"
      shift
      shift
      ;;
    -y|--yes)
      skip_confirmation=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate deployment type
if [[ "$deployment_type" != "aci" && "$deployment_type" != "app-service" && "$deployment_type" != "aks" ]]; then
  echo "Error: Deployment type must be one of: aci, app-service, aks"
  exit 1
fi

# Check if resource group name is provided
if [[ -z "$resource_group_name" ]]; then
  resource_group_name="${deployment_name}-${environment_type}-rg"
  echo "No resource group specified. Using default: $resource_group_name"
fi

# Update parameters file if requested
if [[ "$update_params_only" == true || "$use_custom_password" == true || -n "$container_memory" || -n "$container_cpu" ]]; then
  echo "Updating parameters file: $parameters_file"
  
  # Create a temporary file
  temp_file=$(mktemp)
  
  # Process the file with jq if it's installed
  if command -v jq &> /dev/null; then
    # Read the current parameters
    jq_command="jq"
    
    # Update deploymentType if needed
    jq_command+=" '.parameters.deploymentType.value = \"$deployment_type\"'"
    
    # Update container memory if provided
    if [[ -n "$container_memory" ]]; then
      jq_command+=" | .parameters.containerMemoryGb.value = $container_memory"
    fi
    
    # Update container CPU if provided
    if [[ -n "$container_cpu" ]]; then
      jq_command+=" | .parameters.containerCpuCores.value = $container_cpu"
    fi
    
    # Execute the jq command
    eval "$jq_command $parameters_file" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$parameters_file"
    
    echo "Parameters file updated with deployment type: $deployment_type"
    if [[ -n "$container_memory" ]]; then
      echo "Updated container memory to: $container_memory GB"
    fi
    if [[ -n "$container_cpu" ]]; then
      echo "Updated container CPU to: $container_cpu cores"
    fi
  else
    echo "Warning: jq is not installed. Manual parameter file update is required."
    echo "Please edit $parameters_file and set deploymentType to: $deployment_type"
    if [[ -n "$container_memory" ]]; then
      echo "Also set containerMemoryGb to: $container_memory"
    fi
    if [[ -n "$container_cpu" ]]; then
      echo "Also set containerCpuCores to: $container_cpu"
    fi
  fi
  
  # If only updating params, exit now
  if [[ "$update_params_only" == true ]]; then
    echo "Parameters file updated. Exiting without deployment."
    exit 0
  fi
fi

# Check if az is installed
if ! command -v az &> /dev/null; then
  echo "Azure CLI is not installed. Please install it first."
  exit 1
fi

# Check if user is logged in to Azure
echo "Checking Azure login status..."
az account show &> /dev/null
if [[ $? -ne 0 ]]; then
  echo "You are not logged in to Azure. Please login first using 'az login'"
  exit 1
fi

# Confirm deployment
if [[ "$skip_confirmation" != true ]]; then
  echo ""
  echo "You are about to deploy Redis Stack with the following configuration:"
  echo "  Resource group: $resource_group_name"
  echo "  Location: $location"
  echo "  Environment: $environment_type"
  echo "  Deployment type: $deployment_type"
  echo "  Base name: $deployment_name"
  echo ""
  read -p "Do you want to proceed with this deployment? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
fi

# Create resource group if it doesn't exist
echo "Checking if resource group exists: $resource_group_name"
if ! az group show --name "$resource_group_name" &> /dev/null; then
  echo "Creating resource group: $resource_group_name in $location"
  az group create --name "$resource_group_name" --location "$location"
else
  echo "Resource group already exists: $resource_group_name"
fi

# Build deployment command
deployment_cmd="az deployment group create \
  --resource-group \"$resource_group_name\" \
  --template-file main.bicep \
  --parameters \"@$parameters_file\" \
  --parameters deploymentName=\"$deployment_name\" location=\"$location\" environmentType=\"$environment_type\" deploymentType=\"$deployment_type\""

# Add password if provided
if [[ "$use_custom_password" == true ]]; then
  deployment_cmd+=" redisPassword=\"$redis_password\""
fi

# Add verbose flag
deployment_cmd+=" --verbose"

# Execute deployment
echo "Deploying Redis Stack infrastructure to $resource_group_name..."
eval "$deployment_cmd"

# Check deployment status
if [[ $? -eq 0 ]]; then
  echo "Deployment completed successfully!"
  
  # Get deployment outputs
  echo "Fetching connection information..."
  redis_endpoint=$(az deployment group show --resource-group "$resource_group_name" --name "main" --query "properties.outputs.redisEndpoint.value" -o tsv)
  redis_insight_endpoint=$(az deployment group show --resource-group "$resource_group_name" --name "main" --query "properties.outputs.redisInsightEndpoint.value" -o tsv)
  
  echo ""
  echo "Redis Stack has been deployed!"
  echo "Redis Endpoint: $redis_endpoint"
  echo "RedisInsight UI: $redis_insight_endpoint"
  
  if [[ "$deployment_type" == "aks" ]]; then
    echo ""
    echo "For AKS deployment, you need to manually apply the Kubernetes manifests."
    echo "Run the following command to get the AKS credentials:"
    kube_command=$(az deployment group show --resource-group "$resource_group_name" --name "main" --query "properties.outputs.kubeConfigCommand.value" -o tsv)
    echo "$kube_command"
  fi
  
  echo ""
  echo "Remember to update the Redis password in your application configuration."
else
  echo "Deployment failed. Please check the error messages above."
  exit 1
fi
