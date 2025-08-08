Param(
  [string]$Root = "C:\DATA\gitlab\devops_portfolio"
)

# Utility: ensure directory exists
function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

# Utility: write file (UTF8, no BOM)
function Write-File {
  param(
    [string]$Path,
    [string]$Content
  )
  $dir = Split-Path -Parent $Path
  Ensure-Dir -Path $dir
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  Write-Host "Wrote: $Path"
}

Write-Host "Creating DevOps portfolio at $Root ..." -ForegroundColor Cyan
Ensure-Dir -Path $Root

# -------------------------
# README (portfolio root)
# -------------------------
$rootReadme = @"
# DevOps Portfolio – Michael Redman

This repo contains three showcase projects:
1. **CI/CD App to AKS** (GitHub Actions, Docker, Kubernetes)
2. **IaC Monitoring Stack** (Terraform + Ansible, Prometheus, Grafana)
3. **DevSecOps Scanner** (Nmap + Trivy, scheduled pipeline)

> Configure secrets for GitHub Actions before running pipelines:
- AZURE_CREDENTIALS (JSON from az ad sp create-for-rbac)
- AZURE_CONTAINER_REGISTRY_USERNAME / AZURE_CONTAINER_REGISTRY_PASSWORD
- AKS_RESOURCE_GROUP / AKS_CLUSTER_NAME / ACR_LOGIN_SERVER
"@
Write-File -Path (Join-Path $Root "README.md") -Content $rootReadme

# =========================
# Project 1: CI/CD App
# =========================
$proj1 = Join-Path $Root "project1_cicd_app"
Ensure-Dir $proj1
Ensure-Dir (Join-Path $proj1 "src")
Ensure-Dir (Join-Path $proj1 "k8s")
Ensure-Dir (Join-Path $proj1 ".github\workflows")

# app.py
$appPy = @"
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from DevOps Portfolio App!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
"@
Write-File (Join-Path $proj1 "src\app.py") $appPy

# requirements.txt
$reqTxt = @"
flask==2.3.3
"@
Write-File (Join-Path $proj1 "requirements.txt") $reqTxt

# Dockerfile (build context = project1_cicd_app)
$dockerfile = @"
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ /app
EXPOSE 5000
CMD ["python", "app.py"]
"@
Write-File (Join-Path $proj1 "Dockerfile") $dockerfile

# Kubernetes manifests
$deployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-portfolio-app
  labels:
    app: devops-portfolio-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: devops-portfolio-app
  template:
    metadata:
      labels:
        app: devops-portfolio-app
    spec:
      containers:
        - name: web
          image: REPLACE_WITH_ACR/devops-app:latest
          ports:
            - containerPort: 5000
          readinessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 20
"@
Write-File (Join-Path $proj1 "k8s\deployment.yaml") $deployment

$service = @"
apiVersion: v1
kind: Service
metadata:
  name: devops-portfolio-svc
spec:
  selector:
    app: devops-portfolio-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: LoadBalancer
"@
Write-File (Join-Path $proj1 "k8s\service.yaml") $service

# GitHub Actions workflow
$ghaMain = @"
name: CI/CD Pipeline

on:
  push:
    branches: [ 'main' ]
  workflow_dispatch:

env:
  ACR: `${{ secrets.ACR_LOGIN_SERVER }}
  IMAGE_NAME: devops-app

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: `${{ secrets.AZURE_CREDENTIALS }}

      - name: Docker Login to ACR
        run: echo `${{ secrets.AZURE_CONTAINER_REGISTRY_PASSWORD }} | docker login `${{ env.ACR }} -u `${{ secrets.AZURE_CONTAINER_REGISTRY_USERNAME }} --password-stdin

      - name: Build & Push Image
        run: |
          docker build -t `${{ env.ACR }}/`${{ env.IMAGE_NAME }}:`${{ github.sha }} project1_cicd_app
          docker push `${{ env.ACR }}/`${{ env.IMAGE_NAME }}:`${{ github.sha }}
          docker tag `${{ env.ACR }}/`${{ env.IMAGE_NAME }}:`${{ github.sha }} `${{ env.ACR }}/`${{ env.IMAGE_NAME }}:latest
          docker push `${{ env.ACR }}/`${{ env.IMAGE_NAME }}:latest

      - name: Get AKS Credentials
        uses: azure/aks-set-context@v3
        with:
          resource-group: `${{ secrets.AKS_RESOURCE_GROUP }}
          cluster-name: `${{ secrets.AKS_CLUSTER_NAME }}

      - name: Deploy Manifests
        run: |
          kubectl apply -f project1_cicd_app/k8s/deployment.yaml
          kubectl apply -f project1_cicd_app/k8s/service.yaml

      - name: Update Image Tag
        run: |
          kubectl set image deployment/devops-portfolio-app web=`${{ env.ACR }}/`${{ env.IMAGE_NAME }}:`${{ github.sha }} --record
"@
Write-File (Join-Path $proj1 ".github\workflows\main.yml") $ghaMain

# =========================
# Project 2: IaC Monitoring
# =========================
$proj2 = Join-Path $Root "project2_iac_monitoring"
Ensure-Dir $proj2
Ensure-Dir (Join-Path $proj2 "terraform")
Ensure-Dir (Join-Path $proj2 "ansible")

$proj2Readme = @"
# Project 2 – IaC Monitoring Stack (Azure)

- Terraform provisions resource group, VNet, subnet, NSG, and a VM.
- Ansible installs Prometheus and Grafana on the VM and configures a basic dashboard.

## Quick Start
1. az login
2. terraform init && terraform apply
3. ansible-playbook -i <vm_public_ip>, --user <user> --private-key <key> ansible/install_prometheus.yml
4. ansible-playbook -i <vm_public_ip>, --user <user> --private-key <key> ansible/install_grafana.yml
"@
Write-File (Join-Path $proj2 "README.md") $proj2Readme

$tfMain = @"
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "East US"
}

variable "prefix" {
  type    = string
  default = "devops-monitor"
}

resource "azurerm_resource_group" "rg" {
  name     = "\${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "\${var.prefix}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "\${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "\${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGrafana"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "\${var.prefix}-pip"
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "\${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "\${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1ms"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}
"@
Write-File (Join-Path $proj2 "terraform\main.tf") $tfMain

$ansProm = @"
- hosts: all
  become: yes
  gather_facts: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Prometheus
      apt:
        name: prometheus
        state: present

    - name: Ensure Prometheus running
      service:
        name: prometheus
        state: started
        enabled: yes
"@
Write-File (Join-Path $proj2 "ansible\install_prometheus.yml") $ansProm

$ansGraf = @"
- hosts: all
  become: yes
  gather_facts: yes
  tasks:
    - name: Add Grafana APT key
      apt_key:
        url: https://packages.grafana.com/gpg.key
        state: present

    - name: Add Grafana repo
      apt_repository:
        repo: deb https://packages.grafana.com/oss/deb stable main
        state: present
        filename: grafana

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Grafana
      apt:
        name: grafana
        state: present

    - name: Ensure Grafana running
      service:
        name: grafana-server
        state: started
        enabled: yes
"@
Write-File (Join-Path $proj2 "ansible\install_grafana.yml") $ansGraf

# =========================
# Project 3: DevSecOps Scanner
# =========================
$proj3 = Join-Path $Root "project3_devsecops_scanner"
Ensure-Dir $proj3
Ensure-Dir (Join-Path $proj3 "scripts")
Ensure-Dir (Join-Path $proj3 "docker")
Ensure-Dir (Join-Path $proj3 ".github\workflows")

$proj3Readme = @"
# Project 3 – DevSecOps Scanner

- Runs Nmap network scan (lab range) and Trivy image scan.
- Scheduled daily and on push.

## Notes
- Requires nmap installed in runner (job installs it).
- Set \`ACR_LOGIN_SERVER\` or change image reference for Trivy.
"@
Write-File (Join-Path $proj3 "README.md") $proj3Readme

$scanPy = @"
import json
import subprocess
import sys

# Simple, runner-friendly scan using nmap CLI.
# Adjust CIDR for your lab as needed.
CIDR = "192.168.0.0/24"

def run(cmd):
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout)
        print(res.stderr, file=sys.stderr)
        sys.exit(res.returncode)
    return res.stdout

if __name__ == "__main__":
    xml_out = "nmap_results.xml"
    json_out = "nmap_summary.json"

    run(["nmap", "-T4", "-F", "-oX", xml_out, CIDR])

    summary = {"scanned": CIDR, "xml_file": xml_out}
    with open(json_out, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"Scan complete. XML: {xml_out}  JSON: {json_out}")
"@
Write-File (Join-Path $proj3 "scripts\scan.py") $scanPy

$dockerScan = @"
# Optional: containerized scan environment if desired
FROM python:3.10-slim
RUN apt-get update && apt-get install -y nmap && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY scripts/ /app/scripts
CMD ["python", "/app/scripts/scan.py"]
"@
Write-File (Join-Path $proj3 "docker\Dockerfile") $dockerScan

$ghaSec = @"
name: Security Scan

on:
  push:
    branches: [ 'main' ]
  schedule:
    - cron: '0 3 * * *'
  workflow_dispatch:

env:
  ACR: `${{ secrets.ACR_LOGIN_SERVER }}
  APP_IMAGE: devops-app:latest

jobs:
  nmap-and-trivy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Nmap & Python deps
        run: |
          sudo apt-get update
          sudo apt-get install -y nmap python3-pip
          python -V

      - name: Run Nmap scan (lab CIDR)
        run: python project3_devsecops_scanner/scripts/scan.py

      - name: Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: `${{ env.ACR }}/`${{ env.APP_IMAGE }}
          format: 'table'
          exit-code: '0'     # don't fail pipeline on findings (demo)
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'
"@
Write-File (Join-Path $proj3 ".github\workflows\security.yml") $ghaSec

Write-Host "`nAll done. Portfolio scaffold created at: $Root" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1) Initialize a git repo and push to your remote (GitHub/GitLab)."
Write-Host "2) Add GitHub Action secrets: AZURE_CREDENTIALS, AKS_RESOURCE_GROUP, AKS_CLUSTER_NAME, ACR_LOGIN_SERVER,"
Write-Host "   AZURE_CONTAINER_REGISTRY_USERNAME, AZURE_CONTAINER_REGISTRY_PASSWORD."
Write-Host "3) Update k8s/deployment.yaml image placeholder (REPLACE_WITH_ACR) or rely on pipeline 'kubectl set image'."
