# GenAI Stack - Azure Deployment with Terraform
# Modular, reusable infrastructure as code

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Optional: Remote state storage
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstategenai"
    container_name       = "tfstate"
    key                  = "genai.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}

# Variables
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "1992b163-f828-4887-90c0-b6d26c8ab353"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "genai"
}

variable "deployment_type" {
  description = "Deployment type: aca (Container Apps) or vm (Virtual Machines)"
  type        = string
  default     = "aca"
}

variable "enable_gpu" {
  description = "Enable GPU for AI workloads"
  type        = bool
  default     = false
}

variable "use_azure_openai" {
  description = "Use Azure OpenAI instead of self-hosted LLMs"
  type        = bool
  default     = true
}

# Local variables
locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
  
  services = {
    open_webui = {
      image      = "ghcr.io/open-webui/open-webui:main"
      port       = 8080
      cpu        = 2
      memory     = "4Gi"
      min_replicas = 1
      max_replicas = 3
    }
    n8n = {
      image      = "n8nio/n8n:latest"
      port       = 5678
      cpu        = 1
      memory     = "2Gi"
      min_replicas = 1
      max_replicas = 2
    }
    backend = {
      image      = "${azurerm_container_registry.acr.login_server}/genai-backend:latest"
      port       = 8000
      cpu        = 1
      memory     = "2Gi"
      min_replicas = 1
      max_replicas = 5
    }
    searxng = {
      image      = "searxng/searxng:latest"
      port       = 8080
      cpu        = 0.5
      memory     = "1Gi"
      min_replicas = 1
      max_replicas = 2
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.resource_prefix
  tags                = local.common_tags
}

# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${replace(local.resource_prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.common_tags
}

# Azure Container Apps Environment (if using ACA)
resource "azurerm_container_app_environment" "main" {
  count = var.deployment_type == "aca" ? 1 : 0
  
  name                       = "${local.resource_prefix}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = module.networking.container_apps_subnet_id
  tags                       = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.resource_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# PostgreSQL Flexible Server
module "postgresql" {
  source = "./modules/postgresql"
  
  name                = "${local.resource_prefix}-postgres"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  administrator_login    = "genaidbadmin"
  administrator_password = random_password.postgres.result
  
  sku_name     = "B_Standard_B2ms"
  storage_mb   = 131072  # 128GB
  version      = "15"
  
  delegated_subnet_id = module.networking.postgres_subnet_id
  private_dns_zone_id = module.networking.postgres_dns_zone_id
  
  tags = local.common_tags
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = "${local.resource_prefix}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 1
  family              = "C"
  sku_name            = "Basic"
  
  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
  
  tags = local.common_tags
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "${replace(local.resource_prefix, "-", "")}sto"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = local.common_tags
}

# Container Apps (if using ACA)
module "container_apps" {
  source = "./modules/container-apps"
  count  = var.deployment_type == "aca" ? 1 : 0
  
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  environment_id          = azurerm_container_app_environment.main[0].id
  container_registry_url  = azurerm_container_registry.acr.login_server
  container_registry_user = azurerm_container_registry.acr.admin_username
  container_registry_pass = azurerm_container_registry.acr.admin_password
  
  services = local.services
  
  postgres_host     = module.postgresql.fqdn
  postgres_user     = module.postgresql.administrator_login
  postgres_password = module.postgresql.administrator_password
  
  redis_host = azurerm_redis_cache.main.hostname
  redis_key  = azurerm_redis_cache.main.primary_access_key
  
  storage_account_name = azurerm_storage_account.main.name
  storage_account_key  = azurerm_storage_account.main.primary_access_key
  
  tags = local.common_tags
}

# Azure OpenAI (if enabled)
module "azure_openai" {
  source = "./modules/azure-openai"
  count  = var.use_azure_openai ? 1 : 0
  
  name                = "${local.resource_prefix}-openai"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  deployments = {
    gpt4 = {
      model_name    = "gpt-4"
      model_version = "0613"
      scale_type    = "Standard"
    }
    gpt35 = {
      model_name    = "gpt-35-turbo"
      model_version = "0613"
      scale_type    = "Standard"
    }
    embeddings = {
      model_name    = "text-embedding-ada-002"
      model_version = "2"
      scale_type    = "Standard"
    }
  }
  
  tags = local.common_tags
}

# GPU VM (if enabled)
module "gpu_vm" {
  source = "./modules/gpu-vm"
  count  = var.enable_gpu ? 1 : 0
  
  name                = "${local.resource_prefix}-gpu"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vm_size      = "Standard_NC8as_T4_v3"
  use_spot     = true
  max_bid_price = 0.20
  
  subnet_id = module.networking.gpu_subnet_id
  
  admin_username = "genaiuser"
  ssh_public_key = file("~/.ssh/id_rsa.pub")
  
  tags = local.common_tags
}

# Random password for PostgreSQL
resource "random_password" "postgres" {
  length  = 32
  special = true
}

# Key Vault for secrets
resource "azurerm_key_vault" "main" {
  name                = "${local.resource_prefix}-kv-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  purge_protection_enabled = false
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }
  
  tags = local.common_tags
}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "container_apps_urls" {
  value = var.deployment_type == "aca" ? module.container_apps[0].app_urls : {}
}

output "postgres_fqdn" {
  value     = module.postgresql.fqdn
  sensitive = true
}

output "redis_hostname" {
  value     = azurerm_redis_cache.main.hostname
  sensitive = true
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "azure_openai_endpoint" {
  value = var.use_azure_openai ? module.azure_openai[0].endpoint : null
}

output "gpu_vm_ip" {
  value = var.enable_gpu ? module.gpu_vm[0].public_ip : null
}

output "deployment_info" {
  value = {
    environment     = var.environment
    deployment_type = var.deployment_type
    location        = var.location
    gpu_enabled     = var.enable_gpu
    azure_openai    = var.use_azure_openai
  }
}
