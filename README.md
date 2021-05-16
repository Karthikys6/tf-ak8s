# AKS Cluster deployment using Terraform

Creates AKS Cluster with multiple environments and deploys a sample nginx App


## Prerequisites
* Azure CLI (To login to Azure)
* Terraform v0.15.1+

## Project layout
```
Project/
    src/
       variables.tf   --> To Manage dev, qa, prod Environments
       main.tf        --> Creates Resource group, Vnet, subnets, AKS cluster, nginx App service , Load balancer
       output.tf      --> Outputs KubeConfig file to login to the cluster (for each environment)
    main.tf           --> This resource is to define environments 
    
```

## Steps to execute project

```
terraform init

terraform apply

```
