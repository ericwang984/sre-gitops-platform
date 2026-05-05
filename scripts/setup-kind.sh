#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-sre-demo}"

echo "Creating kind cluster: $CLUSTER_NAME"

# Create cluster with extra port mappings for ingress
cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.29.0
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.29.0
- role: worker
  image: kindest/node:v1.29.0
EOF

echo "Cluster created. Waiting for nodes to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=5m

echo "Labeling nodes for ingress..."
kubectl label nodes --all ingress-ready=true

echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=5m

echo "Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "Cluster setup complete!"
echo "Access the cluster via: kubectl get nodes"
