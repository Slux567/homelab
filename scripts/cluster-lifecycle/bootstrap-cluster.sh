#!/bin/bash
set -euo pipefail

# Variables
export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "${ROOT_DIR}/scripts/vars.env"

declare -A NODE_CONFIGS=(
  ["$NODE_01"]="$ASGARD_CFG"
  ["$NODE_02"]="$MIDGARD_CFG"
  ["$NODE_03"]="$MUSPELHEIM_CFG"
)

# -----------------------------
# Step 1: Apply Talos Machine Configs
# -----------------------------
if kubectl get nodes >/dev/null 2>&1; then
  echo "✅ Kubernetes cluster already exists. Skipping bootstrap."
else
  echo "🚀 Applying Talos configs..."
  for NODE in "${!NODE_CONFIGS[@]}"; do
    CONFIG="${NODE_CONFIGS[$NODE]}"
    echo "Applying $CONFIG to $NODE..."
    talosctl apply-config \
      --insecure \
      --nodes "$NODE" \
      --file "${ROOT_DIR}/talos/config/$CONFIG"
  done
  echo "✅ Talos configs applied to machines."


# -----------------------------
# Step 2: Bootstrap controlplane node
# -----------------------------
  echo "🧠 Bootstrapping control plane on $NODE_01..."
  for ((i=20; i>=1; i--)); do
      echo -ne "⏳ Waiting $i seconds before bootstrapping...\r"
      sleep 1
  done
  talosctl bootstrap --nodes "$NODE_01"
  echo "✅ Bootstrapping success on $NODE_01."
fi
echo ""

# -----------------------------
# Step 3: Wait for Kubernetes API to be reachable
# -----------------------------
echo "Availability Checks"
dots=""
until kubectl get nodes >/dev/null 2>&1; do
  echo -ne "⏳ Waiting for Kubernetes API to be available${dots}\r"
  sleep 2
  dots+="."  # add one dot every 2 seconds
done
echo "✅ Kubernetes API reachable."

# -----------------------------
# Step 4: Wait for all nodes to be available in "kubectl get nodes"
# -----------------------------
EXPECTED_NODE_COUNT="${#NODE_CONFIGS[@]}"
dots=""
until [[ "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -ge "$EXPECTED_NODE_COUNT" ]]; do
  echo -ne "⏳ Waiting for all nodes to register${dots}\r"
  sleep 2
  dots+="."  # add one dot every 2 seconds
done
echo "✅ Kubernetes Nodes listed."
echo ""

# -----------------------------
# Step 5: Apply CRDs
# -----------------------------
echo "CRD Installation:"
crds=(
    # renovate: datasource=github-releases depName=kubernetes-sigs/external-dns
    https://raw.githubusercontent.com/kubernetes-sigs/external-dns/refs/tags/v0.18.0/config/crd/standard/dnsendpoints.externaldns.k8s.io.yaml
    # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api
    https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
    # renovate: datasource=github-releases depName=prometheus-operator/prometheus-operator
    https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.84.0/stripped-down-crds.yaml
)
for crd in "${crds[@]}"; do
    if kubectl get -f "$crd" >/dev/null 2>&1; then
        echo "✅ CRDs already applied: $(basename "$crd")"
    else
        echo "📦 Applying CRD $(basename "$crd")..."
        if kubectl apply --server-side -f "$crd" >/dev/null 2>&1; then
            echo "✅ Applied $(basename "$crd")"
        else
            echo "❌ Failed to apply $(basename "$crd")"
            exit 1
        fi
    fi
done
echo ""

# -----------------------------
# Step 6: Sync Helm releases
# -----------------------------
echo "⛵ Syncing Helm releases from $HELMFILE..."
if [[ ! -f "${ROOT_DIR}/scripts/cluster-lifecycle/data/$HELMFILE" ]]; then
    echo "❌ Helmfile not found: ${ROOT_DIR}/scripts/cluster-lifecycle/data/$HELMFILE"
    exit 1
fi
if helmfile --file "${ROOT_DIR}/scripts/cluster-lifecycle/data/$HELMFILE" sync --hide-notes; then
    echo "✅ Helm releases synced successfully."
else
    echo "❌ Failed to sync Helm releases."
    exit 1
fi
echo ""

# -----------------------------
# Step 7: Create flux-system namespace and SOPS secret
# -----------------------------
NAMESPACE="flux-system"
SECRET_NAME="sops-age"
AGE_KEY_FILE="${ROOT_DIR}/scripts/cluster-lifecycle/data/age.agekey"

echo "📦 Ensuring Kubernetes namespace '$NAMESPACE' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
    kubectl create namespace "$NAMESPACE"
    echo "✅ Namespace '$NAMESPACE' created."
}
if [[ ! -f "$AGE_KEY_FILE" ]]; then
    echo "❌ Age key file not found: $AGE_KEY_FILE"
    exit 1
fi
echo "🔑 Creating/updating secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl delete secret "$SECRET_NAME" --namespace="$NAMESPACE" >/dev/null 2>&1 || true
cat "$AGE_KEY_FILE" | kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-file=age.agekey=/dev/stdin
echo "✅ Secret '$SECRET_NAME' created in namespace '$NAMESPACE'."
echo ""

# -----------------------------
# Step 8: Bootstrap Flux with GitHub
# -----------------------------
echo "🚀 Bootstrapping Flux into the cluster (GitHub)..."
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "🔐 GITHUB_TOKEN is not set."
    echo "Please enter your GitHub Personal Access Token (input will be hidden):"
    read -s GITHUB_TOKEN
    echo ""
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "❌ GitHub token cannot be empty."
        exit 1
    fi
    export GITHUB_TOKEN
fi
if flux bootstrap github \
    --token-auth \
    --owner=slux567 \
    --repository=homelab \
    --branch=main \
    --path=kubernetes/clusters/homelab \
    --namespace=flux-system \
    --personal; then
    echo "✅ Flux bootstrapped successfully."
else
    echo "❌ Flux bootstrap failed."
    unset GITHUB_TOKEN
    exit 1
fi
# Cleanup token from environment
unset GITHUB_TOKEN
echo ""

# -----------------------------
# Step 9: Success message
# -----------------------------
kubectl get nodes -o wide
echo "🎉 Succesfull Kubernetes Cluster Deployment"