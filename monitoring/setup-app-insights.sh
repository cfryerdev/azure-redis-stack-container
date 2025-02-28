#!/bin/bash
#
# Setup script for Azure Application Insights integration with Redis Stack
#

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Redis Stack App Insights Integration Setup =====${NC}"
echo "This script helps you configure Azure Application Insights monitoring"
echo

# Check if running in Azure Cloud Shell
IN_CLOUD_SHELL=false
if [ -n "$AZURE_HTTP_USER_AGENT" ]; then
  IN_CLOUD_SHELL=true
  echo -e "${GREEN}✓ Running in Azure Cloud Shell${NC}"
else
  echo -e "${BLUE}Checking Azure CLI installation...${NC}"
  if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI is not installed. Please install it first:${NC}"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
  fi
  
  echo -e "${BLUE}Checking Azure CLI login status...${NC}"
  if ! az account show &> /dev/null; then
    echo -e "${BLUE}Please log in to Azure:${NC}"
    az login
  fi
fi

echo -e "${GREEN}✓ Azure CLI is installed and logged in${NC}"

# Get subscription
echo
echo -e "${BLUE}Available subscriptions:${NC}"
az account list --query "[].{Name:name, ID:id, Default:isDefault}" -o table

echo
read -p "Enter subscription ID to use (leave blank for default): " SUBSCRIPTION_ID

if [ -n "$SUBSCRIPTION_ID" ]; then
  az account set --subscription "$SUBSCRIPTION_ID"
  echo -e "${GREEN}✓ Using subscription: $SUBSCRIPTION_ID${NC}"
fi

# Get or create resource group
echo
echo -e "${BLUE}Available resource groups:${NC}"
az group list --query "[].{Name:name, Location:location}" -o table

echo
read -p "Enter resource group name (or create new): " RESOURCE_GROUP
if [ -z "$RESOURCE_GROUP" ]; then
  RESOURCE_GROUP="redis-monitoring-rg"
  echo "Using default resource group: $RESOURCE_GROUP"
fi

if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
  echo -e "${BLUE}Resource group doesn't exist. Creating new resource group...${NC}"
  read -p "Enter location (e.g., eastus): " LOCATION
  if [ -z "$LOCATION" ]; then
    LOCATION="eastus"
    echo "Using default location: $LOCATION"
  fi
  
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
  echo -e "${GREEN}✓ Created resource group: $RESOURCE_GROUP${NC}"
else
  echo -e "${GREEN}✓ Using existing resource group: $RESOURCE_GROUP${NC}"
fi

# Create or use existing Log Analytics workspace
echo
echo -e "${BLUE}Available Log Analytics workspaces in $RESOURCE_GROUP:${NC}"
az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Location:location}" -o table

echo
read -p "Enter Log Analytics workspace name (or create new): " WORKSPACE_NAME
if [ -z "$WORKSPACE_NAME" ]; then
  WORKSPACE_NAME="redis-monitoring-workspace"
  echo "Using default workspace: $WORKSPACE_NAME"
fi

if ! az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" &> /dev/null; then
  echo -e "${BLUE}Workspace doesn't exist. Creating new Log Analytics workspace...${NC}"
  az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME"
  echo -e "${GREEN}✓ Created Log Analytics workspace: $WORKSPACE_NAME${NC}"
else
  echo -e "${GREEN}✓ Using existing Log Analytics workspace: $WORKSPACE_NAME${NC}"
fi

# Create or use existing Application Insights
echo
echo -e "${BLUE}Available Application Insights in $RESOURCE_GROUP:${NC}"
az monitor app-insights component list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Location:location}" -o table

echo
read -p "Enter Application Insights name (or create new): " APP_INSIGHTS_NAME
if [ -z "$APP_INSIGHTS_NAME" ]; then
  APP_INSIGHTS_NAME="redis-monitoring-insights"
  echo "Using default Application Insights: $APP_INSIGHTS_NAME"
fi

if ! az monitor app-insights component show --resource-group "$RESOURCE_GROUP" --app "$APP_INSIGHTS_NAME" &> /dev/null; then
  echo -e "${BLUE}Application Insights doesn't exist. Creating new Application Insights...${NC}"
  az monitor app-insights component create \
    --resource-group "$RESOURCE_GROUP" \
    --app "$APP_INSIGHTS_NAME" \
    --location "$(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv)" \
    --workspace "$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" --query "id" -o tsv)"
  echo -e "${GREEN}✓ Created Application Insights: $APP_INSIGHTS_NAME${NC}"
else
  echo -e "${GREEN}✓ Using existing Application Insights: $APP_INSIGHTS_NAME${NC}"
fi

# Get connection string
CONNECTION_STRING=$(az monitor app-insights component show \
  --resource-group "$RESOURCE_GROUP" \
  --app "$APP_INSIGHTS_NAME" \
  --query "connectionString" -o tsv)

echo
echo -e "${GREEN}✓ Application Insights setup complete!${NC}"
echo
echo -e "${BLUE}Add this to your .env file:${NC}"
echo "APP_INSIGHTS_CONNECTION_STRING=$CONNECTION_STRING"
echo

# Check if we need to uncomment the sidecar in docker-compose.yml
DOCKER_COMPOSE_FILE="../docker-compose.yml"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
  echo -e "${BLUE}Do you want to enable the App Insights sidecar in docker-compose.yml? (y/n)${NC}"
  read -p "" ENABLE_SIDECAR
  
  if [[ $ENABLE_SIDECAR == "y" || $ENABLE_SIDECAR == "Y" ]]; then
    if grep -q "# app-insights-sidecar:" "$DOCKER_COMPOSE_FILE"; then
      # Uncomment the app-insights-sidecar section
      sed -i 's/# app-insights-sidecar:/app-insights-sidecar:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   build:/  build:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     context:/    context:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     dockerfile:/    dockerfile:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   container_name:/  container_name:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   depends_on:/  depends_on:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - redis-stack/    - redis-stack/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   volumes:/  volumes:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - redis-logs:/    - redis-logs:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   environment:/  environment:/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - REDIS_LOG_PATH=/    - REDIS_LOG_PATH=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - APP_INSIGHTS_CONNECTION_STRING=/    - APP_INSIGHTS_CONNECTION_STRING=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - APP_INSIGHTS_ROLE_NAME=/    - APP_INSIGHTS_ROLE_NAME=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - APP_INSIGHTS_ROLE_INSTANCE=/    - APP_INSIGHTS_ROLE_INSTANCE=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - LOG_LEVEL=/    - LOG_LEVEL=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#     - SAMPLING_PERCENTAGE=/    - SAMPLING_PERCENTAGE=/g' "$DOCKER_COMPOSE_FILE"
      sed -i 's/#   restart:/  restart:/g' "$DOCKER_COMPOSE_FILE"
      
      echo -e "${GREEN}✓ Enabled App Insights sidecar in docker-compose.yml${NC}"
    else
      echo -e "${BLUE}App Insights sidecar already enabled in docker-compose.yml${NC}"
    fi
  else
    echo "Skipped modifying docker-compose.yml"
  fi
fi

# Create .env file if it doesn't exist
ENV_FILE="../.env"
if [ ! -f "$ENV_FILE" ]; then
  cp "../.env.example" "$ENV_FILE"
  echo -e "${GREEN}✓ Created .env file from .env.example${NC}"
fi

# Add connection string to .env file
echo -e "${BLUE}Do you want to add the connection string to the .env file? (y/n)${NC}"
read -p "" ADD_TO_ENV

if [[ $ADD_TO_ENV == "y" || $ADD_TO_ENV == "Y" ]]; then
  if grep -q "APP_INSIGHTS_CONNECTION_STRING=" "$ENV_FILE"; then
    # Update existing line
    sed -i "s|APP_INSIGHTS_CONNECTION_STRING=.*|APP_INSIGHTS_CONNECTION_STRING=$CONNECTION_STRING|g" "$ENV_FILE"
  else
    # Add new line
    echo "APP_INSIGHTS_CONNECTION_STRING=$CONNECTION_STRING" >> "$ENV_FILE"
  fi
  echo -e "${GREEN}✓ Added connection string to .env file${NC}"
else
  echo "Skipped modifying .env file"
fi

echo
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}Application Insights Integration Setup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Ensure redis.conf has logfile set to /var/log/redis/redis.log"
echo "2. Start your containers with: docker-compose up -d"
echo "3. Check App Insights logs in Azure Portal (can take a few minutes to appear)"
echo "4. Visit the Azure Portal to create custom dashboards and alerts"
echo
