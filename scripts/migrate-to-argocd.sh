#!/bin/bash
set -e

echo "🔄 Migrating n8n deployment to ArgoCD..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    echo "❌ argocd CLI is not installed. Install it from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "executor-role.patch" ]; then
    echo "❌ Please run this script from the n8n-improves repository root"
    exit 1
fi

echo "📋 Migration Checklist:"
echo ""

# Step 1: Build and push image
echo "1️⃣ Building and pushing patched Docker image..."
if [ "$1" = "--skip-build" ]; then
    echo "   ⏭️  Skipping build (--skip-build flag provided)"
else
    ./scripts/build-patched-n8n.sh
    echo "   ✅ Docker image built and ready"
fi

# Step 2: Package Helm chart
echo ""
echo "2️⃣ Packaging Helm chart..."
if command -v helm &> /dev/null; then
    cd k8s
    helm package n8n-patched
    echo "   ✅ Helm chart packaged: $(ls n8n-patched-*.tgz)"
    cd ..
else
    echo "   ⚠️  helm CLI not found. You'll need to package the chart manually."
fi

# Step 3: Registry setup check
echo ""
echo "3️⃣ Checking registry access..."
REGISTRY_URL="${CI_REGISTRY:-git.corp.worldstream.com}"
echo "   📍 Registry: $REGISTRY_URL"

if [ -n "$CI_REGISTRY_PASSWORD" ]; then
    echo "   ✅ Registry credentials available"
else
    echo "   ⚠️  Set CI_REGISTRY_PASSWORD environment variable"
fi

# Step 4: Kubernetes namespace check
echo ""
echo "4️⃣ Checking Kubernetes namespace..."
NAMESPACE="${TARGET_NAMESPACE:-orchestration}"

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "   ✅ Namespace '$NAMESPACE' exists"
else
    echo "   ❓ Creating namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE"
    echo "   ✅ Namespace created"
fi

# Step 5: Registry secret check
echo ""
echo "5️⃣ Checking registry secret..."
SECRET_NAME="gitlab-registry-secret"

if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "   ✅ Registry secret '$SECRET_NAME' exists"
else
    echo "   ❓ Creating registry secret..."
    if [ -n "$CI_REGISTRY_PASSWORD" ] && [ -n "$CI_REGISTRY_USER" ]; then
        kubectl create secret docker-registry "$SECRET_NAME" \
            --docker-server="$REGISTRY_URL" \
            --docker-username="$CI_REGISTRY_USER" \
            --docker-password="$CI_REGISTRY_PASSWORD" \
            --docker-email="${CI_REGISTRY_EMAIL:-devops@worldstream.com}" \
            --namespace="$NAMESPACE"
        echo "   ✅ Registry secret created"
    else
        echo "   ⚠️  Set CI_REGISTRY_USER and CI_REGISTRY_PASSWORD environment variables"
    fi
fi

# Step 6: ArgoCD application check
echo ""
echo "6️⃣ Checking ArgoCD setup..."

if [ -n "$ARGOCD_SERVER" ]; then
    echo "   📍 ArgoCD Server: $ARGOCD_SERVER"

    if argocd app list 2>/dev/null | grep -q "n8n"; then
        echo "   ℹ️  Existing n8n applications found:"
        argocd app list | grep n8n || true
    fi

    echo "   ✅ ArgoCD connection available"
else
    echo "   ⚠️  Set ARGOCD_SERVER environment variable"
fi

# Summary
echo ""
echo "📊 Migration Summary:"
echo ""
echo "✅ Next Steps:"
echo "   1. Update your ArgoCD ApplicationSet:"
echo "      - Replace n8n entry in general-apps.yaml with n8n-patched"
echo "      - Or apply argocd/n8n-patched-applicationset.yaml"
echo ""
echo "   2. Create values override in argocd-resources repo:"
echo "      - mkdir -p prod/helm-private/n8n-patched"
echo "      - Copy values from ARGOCD-INTEGRATION.md"
echo ""
echo "   3. Sync ArgoCD application:"
echo "      - argocd app sync n8n-patched"
echo "      - Or use ArgoCD UI"
echo ""
echo "🌐 Access your patched n8n with the new project:executor role!"
echo ""

# Optional: Backup existing deployment
if kubectl get deployment n8n -n "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Found existing n8n deployment."
    echo "   Consider backing up data before migration:"
    echo "   kubectl get all -n $NAMESPACE -l app=n8n -o yaml > n8n-backup.yaml"
    echo ""
fi

echo "🎉 Migration preparation complete!"
