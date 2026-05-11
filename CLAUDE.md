# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

GitOps homelab managing a 3-node Talos Kubernetes cluster (`sluxcloud`) via Flux. Nodes: `asgard` (10.0.30.10), `midgard` (10.0.30.11), `muspelheim` (10.0.30.12). Cluster endpoint: `kube.sluxcloud.internal`.

## Key Commands

```bash
# Cluster lifecycle
scripts/cluster-lifecycle/generate-talos-configs.sh   # Generate Talos machine configs (one-time)
scripts/cluster-lifecycle/bootstrap-cluster.sh         # Bootstrap a fresh cluster

# Secrets (SOPS/age)
sops --encrypt --in-place <file.yaml>                  # Encrypt a file in-place
sops --decrypt <file.yaml>                             # Decrypt to stdout

# Flux reconciliation
flux reconcile kustomization apps --with-source
flux reconcile helmrelease <name> -n <namespace>
flux get all -A                                        # Check overall sync status

# Talos
talosctl --talosconfig=talos/config/talosconfig <command> --nodes <ip>
```

## Repository Layout

```
ansible/           # Ansible for Proxmox/k3s (not currently used for the Talos cluster)
kubernetes/
  clusters/homelab/           # Flux entry point — DO NOT modify flux-system/gotk-*.yaml
    flux-entry.yaml           # Defines root Kustomizations: configs (runs first) then apps
  configs/
    cluster-config.yaml       # SOPS-encrypted ConfigMap; values injected into all apps via ${VAR}
  apps/<namespace>/<appname>/ # One directory per app
    ks.yaml                   # Flux Kustomization pointing to ./app
    app/
      kustomization.yaml
      ocirepository.yaml      # Declares the Helm chart OCI source
      helmrelease.yaml        # Helm values; uses chartRef to ocirepository
      storage.yaml            # PVCs (when needed)
  components/repositories/    # Shared OCIRepository definitions (e.g. app-template)
  vaulted-apps/               # Apps that were previously behind Traefik (legacy grouping)
scripts/cluster-lifecycle/
  data/                       # Required runtime files: age.agekey, git-token-auth.yaml, helmfile.yaml
talos/
  config/                     # Generated Talos machine configs (gitignored secrets)
  patches/                    # Per-machine and cluster patches applied during config generation
  secrets/secrets.yaml        # Talos secret bundle (keep this safe)
```

## Architecture Patterns

### GitOps Flow
Flux watches `main` and syncs in dependency order:
1. `configs` — applies `kubernetes/configs/` (cluster-config ConfigMap with encrypted vars)
2. `apps` — applies `kubernetes/apps/`, depends on `configs`, gets `${VAR}` substitution from cluster-config

Every `HelmRelease` automatically gets `install.crds: CreateReplace`, retry-on-failure, and rollback cleanup via a patch in `flux-entry.yaml`.

### Adding a New App
Follow this pattern for each new application:
1. Create `kubernetes/apps/<namespace>/<appname>/ks.yaml` — Flux Kustomization
2. Create `kubernetes/apps/<namespace>/<appname>/app/` with:
   - `kustomization.yaml` — lists all resources
   - `ocirepository.yaml` — declares the Helm chart OCI source
   - `helmrelease.yaml` — Helm values using `chartRef` to the OCIRepository
3. Add the `ks.yaml` to the parent namespace's `kustomization.yaml`
4. Add any namespace-specific network access to `kubernetes/apps/<namespace>/networkpolicies.yaml`

Most apps use `bjw-s/app-template` (defined in `kubernetes/components/repositories/app-template/`). Reference it in `ocirepository.yaml` and use `chartRef.kind: OCIRepository` in `helmrelease.yaml`.

### Secrets
- **SOPS/age**: Used for secrets checked into the repo (only `data`/`stringData` fields are encrypted per `.sops.yaml`). Age recipient key: `age1e37dddpcd83kdc45xsle36a9dxc492t0xnpsakyk7478zlga5agsrqjdad`.
- **1Password + External Secrets Operator**: Used for runtime secrets. `ClusterSecretStore` is configured in `kubernetes/apps/security/onepassword/config/`.
- **cluster-config**: SOPS-encrypted ConfigMap providing cluster-wide variables (`${DOMAIN_01}`, `${TIMEZONE}`, node IPs, etc.) substituted into all app manifests.

### Networking
- **CNI**: Cilium with BGP for LoadBalancer IP advertisement
- **Ingress**: Envoy Gateway with two Gateways — `internal` (LAN only) and `external` (Cloudflare tunnel via cloudflared)
- **Network Policies**: CiliumNetworkPolicy per namespace (`networkpolicies.yaml`) with a global baseline deny-egress policy (except to cluster pods and internet, excluding home/storage VLANs). Every namespace must opt-in to allow specific ingress.
- **Routing**: Apps expose routes via the `route:` section in their HelmRelease (app-template pattern), referencing the `internal` or `external` Gateway in the `envoy-gateway` namespace.
- **DNS**: ExternalDNS updates Cloudflare (external) and Unifi (internal) based on Gateway annotations.

### Ansible
Playbooks in `ansible/` target Proxmox nodes and k3s nodes (legacy). The Talos cluster is managed exclusively via `talosctl` and the scripts in `scripts/cluster-lifecycle/`.
