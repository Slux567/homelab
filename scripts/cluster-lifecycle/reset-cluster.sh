#!/bin/bash
set -euo pipefail

# Variables
export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "${ROOT_DIR}/scripts/vars.env"

NODES=(
  "$NODE_03"
  "$NODE_02"
  "$NODE_01"
)

# -----------------------------
# Step 1: Destroy cluster
# -----------------------------
echo "⚠️  Destroying Talos cluster..."
read -rp "Are you sure? This will WIPE all nodes (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

for NODE in "${NODES[@]}"; do
  echo "Resetting node $NODE..."
  talosctl reset \
    -n "$NODE" \
    --system-labels-to-wipe STATE \
    --system-labels-to-wipe EPHEMERAL \
    --graceful=false \
    --reboot=true
done
echo "✅ Cluster destroyed"
echo ""