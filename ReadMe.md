# DevOps Portfolio – Michael Redman

This repo contains three showcase projects:
1. **CI/CD App to AKS** (GitHub Actions, Docker, Kubernetes)
2. **IaC Monitoring Stack** (Terraform + Ansible, Prometheus, Grafana)
3. **DevSecOps Scanner** (Nmap + Trivy, scheduled pipeline)

> Configure secrets for GitHub Actions before running pipelines:
- AZURE_CREDENTIALS (JSON from az ad sp create-for-rbac)
- AZURE_CONTAINER_REGISTRY_USERNAME / AZURE_CONTAINER_REGISTRY_PASSWORD
- AKS_RESOURCE_GROUP / AKS_CLUSTER_NAME / ACR_LOGIN_SERVER