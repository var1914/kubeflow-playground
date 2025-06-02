#!/bin/bash

echo "🧹 Cleaning up current Kubeflow installation..."

# echo "Removing authentication components..."
# kubectl delete namespace auth --ignore-not-found=true
# kubectl delete namespace oauth2-proxy --ignore-not-found=true

echo "Removing Kubeflow components..."
kubectl delete namespace kubeflow --ignore-not-found=true

echo "Removing Kubeflow user namespaces..."
kubectl delete namespace kubeflow-user-example-com --ignore-not-found=true

echo "Removing Istio components..."
kubectl delete namespace istio-system --ignore-not-found=true

echo "Removing Knative components..."
kubectl delete namespace knative-serving --ignore-not-found=true

echo "Removing cert-manager..."
kubectl delete namespace cert-manager --ignore-not-found=true

echo "Removing CRDs..."
kubectl delete crd --all --ignore-not-found=true 2>/dev/null || true

echo "Waiting for cleanup to complete..."
sleep 30

echo "✅ Cleanup completed! Ready for fresh installation."