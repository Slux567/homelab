#!/bin/bash

# Configuration
CONTROL_PLANE_IP=("10.0.30.10" "10.0.30.11" "10.0.30.12")
export CLUSTER_NAME=sluxcloud
export YOUR_ENDPOINT=kube.sluxcloud.internal
export SECRET_BUNDLE_NAME=secrets.yaml

# # -----------------------------
# # Step 1: Generate secrets (one-time)
# # -----------------------------
# echo "Generating secrets for the cluster..."
# mkdir -p ./secrets
# talosctl gen secrets -o ./secrets/$SECRET_BUNDLE_NAME
# echo "Secrets generated at ./secrets/$SECRET_BUNDLE_NAME"

# -----------------------------
# Step 2: Generate base machine configurations
# -----------------------------
echo "Generating base machine configurations..."
mkdir -p ./config
talosctl gen config $CLUSTER_NAME https://$YOUR_ENDPOINT:6443 \
    --with-secrets ./secrets/$SECRET_BUNDLE_NAME \
    -o ./config/ \
    --config-patch @patches/cluster/cni.yaml \
    --force
talosctl --talosconfig=./config/talosconfig \
    config endpoint 10.0.30.10 10.0.30.11 10.0.30.12

# -----------------------------
# Step 3: Patch machine configs
# -----------------------------
echo "Patching machine configurations..."
talosctl machineconfig patch ./config/controlplane.yaml \
    --patch @patches/machines/asgard.yaml \
    --output ./config/asgard.yaml

talosctl machineconfig patch ./config/controlplane.yaml \
    --patch @patches/machines/midgard.yaml \
    --output ./config/midgard.yaml

talosctl machineconfig patch ./config/controlplane.yaml \
    --patch @patches/machines/muspelheim.yaml \
    --output ./config/muspelheim.yaml

# -----------------------------
# Step 4: Cleanup old configs
# -----------------------------
rm -f ./config/controlplane.yaml ./config/worker.yaml