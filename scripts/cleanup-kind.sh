#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-sre-demo}"

echo "Deleting kind cluster: $CLUSTER_NAME..."
kind delete cluster --name $CLUSTER_NAME

echo ""
echo "To completely clean up, you can also remove any remaining resources:"
echo "  kubectl delete namespace dev --ignore-not-found=true"
echo "  kubectl delete namespace prod --ignore-not-found=true"
echo "  kubectl delete namespace observability --ignore-not-found=true"
echo "  kubectl delete namespace argocd --ignore-not-found=true"
