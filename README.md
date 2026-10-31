# azure-platform

Terraform for everything the MERN platform runs on **Microsoft Azure** — a **standby** cloud. Its AKS cluster is fully configured but normally **stopped**; it is started automatically when the primary cloud (GCP) fails.

**Region:** `centralindia` · **Terraform** 1.16 · **Remote state:** Azure Storage `rg-tfstate / sttfstate… / tfstate` (Entra ID auth, versioned)

## Stacks

Each folder is its own Terraform stack with its own state. Apply them in this order.

| Stack | Creates | Lifetime |
|---|---|---|
| `bootstrap/` | state storage account, GitHub OIDC plan/apply identities, subscription budget | once |
| `environments/prod/foundation/` | resource group `rg-prod-foundation`, ACR `acrmern…` (+ mirrors of the External Secrets and OpenCost images), Key Vault `kv-mern-…`, backup storage with lifecycle policy, identities: CI push `id-gha-push`, backup (write-only custom role) and restore, failover `id-gha-failover` (custom role: read + start AKS only), Jenkins deployer federated from GKE | permanent |
| `environments/prod/cluster/` | VNet + node subnet, NAT gateway with static egress IP, AKS `prod-aks` (Free tier, Azure CNI Overlay, Cilium network policy, Entra ID RBAC, workload identity, API allow-list), 2 × `Standard_D2as_v5`, static ingress IP | per session |
| `environments/prod/addons/` | Envoy Gateway, External Secrets (+ Key Vault access), kube-prometheus-stack, Loki, Alloy, OpenCost, platform-config chart, role assignments for Jenkins and the failover identity | per session |

Reusable modules: `modules/network`, `modules/aks`.

## Dependencies

| Depends on | For |
|---|---|
| [gcp-platform](https://github.com/ppmcad16a-cloud-platform/gcp-platform) | `gke_egress_ip` from its foundation state → AKS API allow-list (Jenkins runs in GKE) |
| [observability-platform](https://github.com/ppmcad16a-cloud-platform/observability-platform) | alert rules module (`?ref=v1.1.0`) |
| [global-platform](https://github.com/ppmcad16a-cloud-platform/global-platform) | app secrets in Key Vault |

| Used by | For |
|---|---|
| [global-platform](https://github.com/ppmcad16a-cloud-platform/global-platform) | ingress/egress IPs → DNS, load-balancer pool, Atlas allow-list |
| [platform-automation](https://github.com/ppmcad16a-cloud-platform/platform-automation) | session start/end; `standby.yml` / `wake.yml` stop and start AKS; `failover-wake.yml` starts it automatically |
| [platform-deployments](https://github.com/ppmcad16a-cloud-platform/platform-deployments) | Jenkins deploys into namespace `mern` |

## Usage

Normally driven by `platform-automation`. By hand:

```bash
az login --tenant <tenant-id> && az account set --subscription <subscription-id>
cd environments/prod/foundation && terraform init && terraform plan && terraform apply
echo "admin_cidr = \"$(curl -s https://api.ipify.org)/32\"" > ../cluster/terraform.tfvars
cp ../cluster/terraform.tfvars ../addons/terraform.tfvars
cd ../cluster && terraform init && terraform apply
az aks get-credentials -g rg-prod-cluster -n prod-aks && kubelogin convert-kubeconfig -l azurecli
cd ../addons && terraform init && terraform apply
```

Stop / start the standby: `az aks stop -g rg-prod-cluster -n prod-aks` / `az aks start …` (or the playbooks).

## Rules

* Plain `terraform init`, committed lock files, no secrets in git, `terraform.tfvars` holds only your IP.
* AKS pulls the External Secrets and OpenCost images from ACR because pulls from ghcr.io are very slow in Azure; `up.yml` imports missing mirrors with `az acr import`.
* Don't stop AKS while a start is still in progress (`provisioningState` must be `Succeeded`).
