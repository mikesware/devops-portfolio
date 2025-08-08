# Project 2 – IaC Monitoring Stack (Azure)

- Terraform provisions resource group, VNet, subnet, NSG, and a VM.
- Ansible installs Prometheus and Grafana on the VM and configures a basic dashboard.

## Quick Start
1. az login
2. terraform init && terraform apply
3. ansible-playbook -i <vm_public_ip>, --user <user> --private-key <key> ansible/install_prometheus.yml
4. ansible-playbook -i <vm_public_ip>, --user <user> --private-key <key> ansible/install_grafana.yml