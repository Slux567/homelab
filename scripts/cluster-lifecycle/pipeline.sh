#!/bin/bash
set -euo pipefail

# Variables
export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "${ROOT_DIR}/scripts/vars.env"

# Prompt for GitHub PAT once
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "🔐 Please enter your GitHub Personal Access Token (input will be hidden):"
    read -s GITHUB_TOKEN
    echo ""
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "❌ GitHub token cannot be empty."
        exit 1
    fi
    export GITHUB_TOKEN
fi

# Reset the cluster
bash "${ROOT_DIR}/scripts/cluster-lifecycle/reset-cluster.sh"

# Generate Talos Configs
bash "${ROOT_DIR}/scripts/cluster-lifecycle/generate-talos-configs.sh"

# Bootstrap new cluster
bash "${ROOT_DIR}/scripts/cluster-lifecycle/bootstrap-cluster.sh"