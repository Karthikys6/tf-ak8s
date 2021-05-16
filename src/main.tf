terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.48.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
}

provider "azurerm" {
  features {}
}

##
# Creates Resource Group 
##
resource "azurerm_resource_group" "rg" {
  name   = "k8s-rg-${var.env}"
  location = "westus"
}


##
# Creates Vnet
##
resource "azurerm_virtual_network" "vnet_cluster" {
  name                = "vnet-cluster-${var.env}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

##
# Creates Subnet
##
resource "azurerm_subnet" "snet_public" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_cluster.name
  address_prefixes     = ["10.1.0.0/24"]
}


resource "azurerm_subnet" "snet_private_aks" {
  name                 = "snet-private-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_cluster.name
  address_prefixes     = ["10.1.1.0/24"]
  # Enforce network policies to allow Private Endpoint to be added to the subnet
 # enforce_private_link_endpoint_network_policies = true
}


##
# Creates AKS Cluster
##
resource "azurerm_kubernetes_cluster" "ak8s_cluster" {
  name                = "ak8scluster-${var.env}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "ak8scluster-${var.env}"


# Prevents network collision with Vnet
  network_profile {
    network_plugin     = "kubenet"
    docker_bridge_cidr = "192.167.0.1/16"
    dns_service_ip     = "192.168.1.1"
    service_cidr       = "192.168.0.0/16"
    pod_cidr           = "172.16.0.0/22"
  }  

##
# Deploys a node in the appropriate subnet
##
  default_node_pool {
    name       = "default"
    node_count = "1"
    vm_size    = "standard_d2_v2"
    vnet_subnet_id = azurerm_subnet.snet_private_aks.id
  }

  identity {
    type = "SystemAssigned"
  }

}


##
# Preparing for App deployment into Cluster
##

data "azurerm_kubernetes_cluster" "cluster" {
  name                 = azurerm_kubernetes_cluster.ak8s_cluster.name
  resource_group_name  = azurerm_resource_group.rg.name
}


provider "kubernetes" {
  host = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
  
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
}


##
# Creates namespace as per the Env
##
resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx-${var.env}"
  }
}


##
# Deploys Nginx App into the namespace
# Official nginx image from Docker Hub has been customised and pushed to my personal Registry with following tags (dev, qa, prod)
##

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.nginx.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          image = "karthikys/nginxenv:${var.env}"
          name  = "nginx-container"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}


##
#Creates loadbalancer service and assigns a public IP to the frontend configuration of public load balancer 
##

resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-${var.env}"
  }
  spec {
    selector = {
      App = kubernetes_deployment.nginx.spec.0.template.0.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

##
# Publishes IP as output to access nginx service
##

output "Env_IP" {
  value = kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.ip
}
