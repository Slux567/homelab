#!/usr/bin/env bash
set -euo pipefail

### -------- helpers --------
die() {
  echo "❌ $*" >&2
  exit 1
}

info() {
  echo "▶ $*"
}

### -------- checks --------
command -v git >/dev/null || die "git not found"
command -v flux >/dev/null || die "flux CLI not found"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "Not inside a git repository"

if [[ $# -lt 1 ]]; then
  die "Usage: flux-apply \"commit message\""
fi

MESSAGE="$*"

### -------- git status --------
info "Git status:"
git status --short

if git diff --quiet && git diff --cached --quiet; then
  info "No changes detected, skipping commit and push"
else
  info "Staging all changes"
  git add -A

  info "Creating commit"
  git commit -m "$MESSAGE"

  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  info "Pushing branch: $CURRENT_BRANCH"
  git push origin "$CURRENT_BRANCH"
fi

### -------- flux reconcile --------
info "Reconciling Flux source"
flux reconcile source git flux-system

info "Reconciling configs Kustomization"
flux reconcile kustomization configs \
  --namespace flux-system \
  --with-source

info "Reconciling apps Kustomization"
flux reconcile kustomization apps \
  --namespace flux-system \
  --with-source

info "✅ Flux apply complete"
