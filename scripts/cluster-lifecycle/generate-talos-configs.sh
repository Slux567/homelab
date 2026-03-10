#!/bin/bash
set -euo pipefail

export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "${ROOT_DIR}/scripts/vars.env"

# Configuration
CONTROL_PLANE_IP=("$NODE_01" "$NODE_02" "$NODE_03")
export CLUSTER_NAME=sluxcloud
export YOUR_ENDPOINT=kube.sluxcloud.internal
export SECRET_BUNDLE_NAME=secrets.yaml

# # -----------------------------
# # Step 1: Generate secrets (one-time)
# # -----------------------------
echo "🔐 Generating secrets for the cluster..."
mkdir -p "${ROOT_DIR}/talos/secrets"
SECRET_PATH="${ROOT_DIR}/talos/secrets/${SECRET_BUNDLE_NAME}"
if [ -f "$SECRET_PATH" ]; then
  echo "⚠️  Secrets already exist at $SECRET_PATH"
  echo "Skipping generation to avoid overwriting existing cluster secrets."
else
  talosctl gen secrets -o "$SECRET_PATH"
  echo "✅ Secrets generated at $SECRET_PATH"
fi
echo ""

# -----------------------------
# Step 2: Generate base machine configurations
# -----------------------------
echo "⚙️ Generating base machine configurations..."
mkdir -p ${ROOT_DIR}/talos/config
talosctl gen config $CLUSTER_NAME https://$YOUR_ENDPOINT:6443 \
    --with-secrets ${ROOT_DIR}/talos/secrets/$SECRET_BUNDLE_NAME \
    -o ${ROOT_DIR}/talos/config/ \
    --config-patch ${ROOT_DIR}/talos/patches/cluster/cni.yaml \
    --force
talosctl --talosconfig=${ROOT_DIR}/talos/config/talosconfig \
    config endpoint $NODE_01 $NODE_02 $NODE_03
# -----------------------------
# Step 3: Patch machine configs
# -----------------------------
echo "🛠️ Patching machine configurations..."
talosctl machineconfig patch ${ROOT_DIR}/talos/config/controlplane.yaml \
    --patch ${ROOT_DIR}/talos/patches/machines/asgard.yaml \
    --output ${ROOT_DIR}/talos/config/$ASGARD_CFG

talosctl machineconfig patch ${ROOT_DIR}/talos/config/controlplane.yaml \
    --patch ${ROOT_DIR}/talos/patches/machines/midgard.yaml \
    --output ${ROOT_DIR}/talos/config/$MIDGARD_CFG

talosctl machineconfig patch ${ROOT_DIR}/talos/config/controlplane.yaml \
    --patch ${ROOT_DIR}/talos/patches/machines/muspelheim.yaml \
    --output ${ROOT_DIR}/talos/config/$MUSPELHEIM_CFG
echo "Done"
# -----------------------------
# Step 4: Cleanup old configs
# -----------------------------
rm -f ${ROOT_DIR}/talos/config/controlplane.yaml ${ROOT_DIR}/talos/config/worker.yaml