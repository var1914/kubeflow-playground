#!/bin/bash

# Kubeflow Central Dashboard Installation Script
set -e

echo "🚀 Installing Kubeflow Central Dashboard..."

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Check if kustomize is available
if ! command -v kustomize &> /dev/null; then
    echo "⚠️  kustomize not found. Installing kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
fi

# Clone manifests if not exists
if [ ! -d "manifests" ]; then
    echo "📥 Cloning Kubeflow manifests..."
    git clone https://github.com/kubeflow/manifests.git
fi

cd manifests

echo "🔧 Installing core components..."

# Install common components
echo "Installing cert-manager..."
kubectl apply -k common/cert-manager/base
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s

echo "Installing Istio..."
kubectl apply -k common/cert-manager/kubeflow-issuer/base
kubectl apply -k common/istio-1-24/istio-crds/base
kubectl apply -k common/istio-1-24/istio-namespace/base
kubectl apply -k common/istio-1-24/istio-install/base
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s

echo "🌐 Installing Kubeflow Istio resources (Gateway, VirtualService, etc.)..."
# This is the missing piece that creates the kubeflow-gateway!
kustomize build common/istio-1-24/kubeflow-istio-resources/base | kubectl apply -f -


echo "Installing authentication components..."
kubectl apply -k common/dex/base
kubectl apply -k common/oauth2-proxy/base

# echo "Installing Knative..."
# kubectl apply -k common/knative/knative-serving/overlays/gateways

echo "🎯 Installing Central Dashboard and core applications..."

# Install Central Dashboard
kubectl apply -k apps/centraldashboard/upstream/overlays/kserve

# Install Profiles (user management)
kubectl apply -k apps/profiles/upstream/overlays/kubeflow

# Install Jupyter Web App
kubectl apply -k apps/jupyter/jupyter-web-app/upstream/overlays/istio

# Install Volumes Web App
kubectl apply -k apps/volumes-web-app/upstream/overlays/istio

# Install Tensorboards Web App
kubectl apply -k apps/tensorboard/tensorboards-web-app/upstream/overlays/istio

echo "🤖 Installing ML components..."

# # Install Training Operator
# kubectl apply -k apps/training-operator/upstream/overlays/kubeflow

# Install Katib (AutoML)
kubectl apply -k apps/katib/upstream/installs/katib-with-kubeflow

# Install KServe (Model Serving)
kubectl apply -k apps/kserve/models-web-app/overlays/kubeflow

echo "⏳ Waiting for all components to be ready..."

# Wait for key components
echo "Waiting for Central Dashboard..."
kubectl wait --for=condition=available deployment/centraldashboard -n kubeflow --timeout=300s

echo "Waiting for Profiles controller..."
kubectl wait --for=condition=available deployment/profiles-deployment -n kubeflow --timeout=300s

echo "✅ Installation completed!"

echo "🌐 To access the Central Dashboard:"
echo "1. Run: kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
echo "2. Open: http://localhost:8080"
echo ""
echo "📊 Default login (if authentication is enabled):"
echo "   Email: user@example.com"
echo "   Password: 12341234"
echo ""
echo "🔍 Check installation status:"
echo "   kubectl get pods -n kubeflow"
echo "   kubectl get pods -n istio-system"

# Show current status
echo ""
echo "📋 Current status:"
kubectl get pods -n kubeflow | head -10