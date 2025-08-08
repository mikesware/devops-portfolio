Param(
  [string]$Root = "C:\DATA\gitlab\devops_portfolio"
)

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Write-File([string]$Path, [string]$Content) {
  Ensure-Dir (Split-Path -Parent $Path)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  Write-Host "Wrote: $Path"
}

function Append-File([string]$Path, [string]$Content) {
  Ensure-Dir (Split-Path -Parent $Path)
  if (-not (Test-Path $Path)) { Write-File $Path $Content; return }
  Add-Content -LiteralPath $Path -Value "`r`n`r`n$Content"
  Write-Host "Updated: $Path"
}

# --------------------------
# 1) .gitignore (repo root)
# --------------------------
$gitignore = @"
# OS / Editor
Thumbs.db
Desktop.ini
.DS_Store
.vscode/
.idea/
*.code-workspace

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.venv/
env/
venv/
pip-wheel-metadata/
.pytest_cache/
.coverage*
dist/
build/

# Node / Frontend (if added later)
node_modules/
npm-debug.log*
yarn-error.log*

# Docker
*.pid
*.log
*.tar
**/.dockerignore

# Terraform
**/.terraform/
**/.terraform.lock.hcl
**/terraform.tfstate
**/terraform.tfstate.*
**/*.tfvars
**/*.tfvars.json
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ansible
*.retry

# Secrets / creds (add patterns you use)
secrets.*
*.key
*.pem
*.pfx
*.pub
*.cert
.env
.env.*

# Build artifacts & misc
*.iml
*.swp
*.swo
*.tmp
*.bak
*.old

# macOS/Linux crap (cross-platform insurance)
._*
.Spotlight-V100
.Trashes
"@
Write-File -Path (Join-Path $Root ".gitignore") -Content $gitignore

# --------------------------
# 2) Root README diagrams
# --------------------------
$rootReadmeDiagrams = @"
## Architecture Overview

### Portfolio Map
```mermaid
flowchart TD
  A[Dev Workstation] -->|git push| B[GitHub]
  B -->|Actions| C{Pipelines}
  C -->|Project 1| D[AKS Deploy]
  C -->|Project 2| E[Terraform + Ansible]
  C -->|Project 3| F[Security Scans]
  D --> G[AKS Cluster]
  E --> H[Azure VM + Prometheus/Grafana]
  F --> I[Nmap/Trivy Reports]
```
"@