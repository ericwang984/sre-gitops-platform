#!/bin/bash
set -e

echo "Installing Argo CD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=5m

echo ""
echo "Argo CD installed successfully!"
echo ""
echo "To access Argo CD UI, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: (get with: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo ""
