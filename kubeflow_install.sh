#!/bin/bash

set -e

echo "🚀 Installing Kubeflow"

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v kustomize &> /dev/null; then
    echo "❌ kustomize not found. Please install kustomize first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    exit 1
fi

# Clone manifests if not exists
if [ ! -d "manifests" ]; then
    echo "📥 Cloning Kubeflow manifests..."
    git clone https://github.com/kubeflow/manifests.git
fi

cd manifests
git checkout v1.10.1  # Use a stable version

# Apply the manifests
while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 20; done

echo "✅ Kubeflow manifests applied successfully."
echo ""
echo "🌐 To access Kubeflow (NO AUTHENTICATION):"
echo "1. Run: kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
echo "2. Open: http://localhost:8080"
echo "3. ✅ You should now access Kubeflow directly without login!"
echo ""
echo "⚠️  WARNING: This setup has NO AUTHENTICATION - only use for development/testing!"