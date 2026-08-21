#!/bin/bash
# Cleans up Part 3 (k3d + Argo CD).
# Removes the cluster and everything running inside it.
# Docker, k3d, kubectl and helm binaries are kept.

set -u   # no set -e: cleanup must continue even if something is already gone

CLUSTER_NAME="part3"

echo "=========================================="
echo " Part 3 cleanup"
echo " Removes the k3d cluster and its contents."
echo " Tools (docker, k3d, kubectl) are kept."
echo "=========================================="

# ---------- 1. Argo CD Application ----------
# Deleting the Application first lets Argo CD prune the app it manages in 'dev'.
echo ""
echo "--- Removing Argo CD Application ---"
if command -v kubectl &>/dev/null; then
    kubectl delete application playground -n argocd --ignore-not-found 2>/dev/null \
        || echo "  no application found (cluster may already be gone)"
fi

# ---------- 2. k3d cluster ----------
# This removes the cluster's containers, its network and its volumes.
echo ""
echo "--- Removing k3d cluster '$CLUSTER_NAME' ---"
if command -v k3d &>/dev/null; then
    k3d cluster delete "$CLUSTER_NAME" 2>/dev/null \
        || echo "  cluster '$CLUSTER_NAME' not found"
else
    echo "  k3d not installed, nothing to delete"
fi

# ---------- 3. Leftover kubeconfig context ----------
# k3d normally cleans this up itself, but remove a stale entry just in case.
echo ""
echo "--- Cleaning kubeconfig context ---"
if command -v kubectl &>/dev/null; then
    kubectl config delete-context "k3d-${CLUSTER_NAME}" 2>/dev/null || true
    kubectl config delete-cluster "k3d-${CLUSTER_NAME}" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo " Done."
echo " Cluster removed. Docker and tools untouched."
echo "=========================================="
