#!/bin/bash

# Official Kubeflow Installation Script (Following README exactly)
set -e

echo "🚀 Installing Kubeflow following official README..."

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

echo "🔧 Creating namespaces with proper security settings..."
# Create namespaces with pod security labels
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: v1
kind: Namespace
metadata:
  name: oauth2-proxy
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged

EOF

echo "✅ Namespaces created"
sleep 5

echo "🔒 Installing cert-manager..."
kustomize build common/cert-manager/base | kubectl apply -f -
kustomize build common/cert-manager/kubeflow-issuer/base | kubectl apply -f -
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
kubectl wait --for=jsonpath='{.subsets[0].addresses[0].targetRef.kind}'=Pod endpoints -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager

echo "🌐 Installing Istio CNI with OAuth2-proxy overlay..."
kustomize build common/istio-cni-1-24/istio-crds/base | kubectl apply -f -
kustomize build common/istio-cni-1-24/istio-namespace/base | kubectl apply -f -
# Use OAuth2-proxy overlay for Istio (this is key!)
kustomize build common/istio-cni-1-24/istio-install/overlays/oauth2-proxy | kubectl apply -f -
echo "Waiting for all Istio Pods to become ready..."
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout 300s

echo "🔐 Installing OAuth2-proxy (FIRST!)..."
# This is the critical step we were missing!
kustomize build common/oauth2-proxy/overlays/m2m-dex-only/ | kubectl apply -f -
kubectl wait --for=condition=Ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy

echo "🆔 Installing Dex with OAuth2-proxy overlay..."
# Use the OAuth2-proxy overlay, not base!
kustomize build common/dex/overlays/oauth2-proxy | kubectl apply -f -
kubectl wait --for=condition=Ready pods --all --timeout=180s -n auth

# echo "🌊 Installing Knative..."
# kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
# kustomize build common/istio-cni-1-24/cluster-local-gateway/base | kubectl apply -f -

echo "📁 Installing Kubeflow Namespace..."
kustomize build common/kubeflow-namespace/base | kubectl apply -f -

echo "🔒 Installing Network Policies..."
kustomize build common/networkpolicies/base | kubectl apply -f -

echo "👤 Installing Kubeflow Roles..."
kustomize build common/kubeflow-roles/base | kubectl apply -f -

echo "🌐 Installing Kubeflow Istio Resources..."
# This creates the kubeflow-gateway and proper routing
kustomize build common/istio-cni-1-24/kubeflow-istio-resources/base | kubectl apply -f -

echo "📊 Installing Central Dashboard with OAuth2-proxy overlay..."
# Use OAuth2-proxy overlay, not the kserve overlay!
kustomize build apps/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -

echo "🔌 Installing Admission Webhook..."
kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -

echo "📝 Installing Jupyter components..."
kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -

echo "👤 Installing Profiles + KFAM..."
kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -

echo "💾 Installing Volumes Web App..."
kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -

echo "📈 Installing Tensorboard components..."
kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -

# echo "🔧 Installing Training Operator..."
# kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply --server-side --force-conflicts -f -

echo "🤖 Installing Katib..."
kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -

echo "📊 Installing Kubeflow Pipelines (Multi-User)..."
# This installs the full multi-user pipelines with authentication integration
kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -

echo "⏳ Waiting for Pipeline components to be ready..."
echo "This may take 5-10 minutes as pipelines has many components..."

# Wait for key pipeline components
echo "Waiting for Pipeline API Server..."
kubectl wait --for=condition=available deployment/ml-pipeline -n kubeflow --timeout=600s || echo "⚠️ Pipeline API Server taking longer than expected"

echo "Waiting for Pipeline Frontend..."
kubectl wait --for=condition=available deployment/ml-pipeline-ui -n kubeflow --timeout=600s || echo "⚠️ Pipeline UI taking longer than expected"

echo "Waiting for Pipeline Persistence Agent..."
kubectl wait --for=condition=available deployment/ml-pipeline-persistenceagent -n kubeflow --timeout=600s || echo "⚠️ Persistence Agent taking longer than expected"

echo "Waiting for Pipeline Scheduledworkflow..."
kubectl wait --for=condition=available deployment/ml-pipeline-scheduledworkflow -n kubeflow --timeout=600s || echo "⚠️ Scheduled Workflow taking longer than expected"

echo "Waiting for Workflow Controller..."
kubectl wait --for=condition=available deployment/workflow-controller -n kubeflow --timeout=600s || echo "⚠️ Workflow Controller taking longer than expected"

# echo "🚀 Installing KServe..."
# kustomize build apps/kserve/kserve | kubectl apply --server-side --force-conflicts -f -
# kustomize build apps/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -

echo "👤 Creating User Namespace..."
kustomize build common/user-namespace/base | kubectl apply -f -

echo "⏳ Waiting for key components to be ready..."
kubectl wait --for=condition=available deployment/centraldashboard -n kubeflow --timeout=600s || echo "⚠️ Central Dashboard taking longer than expected"
kubectl wait --for=condition=available deployment/profiles-deployment -n kubeflow --timeout=600s || echo "⚠️ Profiles taking longer than expected"

echo "✅ Installation completed!"

echo ""
echo "🔍 Verifying authentication setup..."
echo "OAuth2-proxy pods:"
kubectl get pods -n oauth2-proxy
echo ""
echo "Dex pods:"
kubectl get pods -n auth
echo ""
echo "Central Dashboard pods:"
kubectl get pods -n kubeflow | grep centraldashboard

echo ""
echo "🌐 To access Kubeflow:"
echo "1. Run: kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
echo "2. Open: http://localhost:8080"
echo "3. Login with:"
echo "   📧 Email: user@example.com"
echo "   🔑 Password: 12341234"
echo ""
echo "✅ You should now see the Dex login page instead of 401 errors!"