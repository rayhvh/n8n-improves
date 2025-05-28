# 🚀 ArgoCD Integration for Patched n8n

This guide explains how to integrate your patched n8n (with the `project:executor` role) into your existing ArgoCD setup.

## 📋 Current State Analysis

Your current ArgoCD configuration shows:

```yaml
- name: n8n
  namespace: orchestration
  repoURL: "8gears.container-registry.com/library"
  chart: n8n
  targetRevision: 1.0.6
  valuesOverridePath: prod/helm-public/n8n
```

This deploys the **standard n8n** without your executor role patch.

## 🔄 Migration Strategy

### Option 1: Replace Existing n8n (Recommended)

Replace the current n8n entry in your `general-apps.yaml` with:

```yaml
- name: n8n-patched
  namespace: orchestration
  repoURL: "oci://git.corp.worldstream.com/worldstream/levi9/n8n-improves/charts"
  chart: n8n-patched
  targetRevision: "latest"
  valuesOverridePath: prod/helm-private/n8n-patched
  ServerSideApply: ServerSideApply=false
```

### Option 2: Side-by-Side Deployment

Keep both versions running and gradually migrate:

1. **Add patched version** alongside existing n8n
2. **Test with limited users** on the patched version
3. **Migrate gradually** and remove old version

## 🛠️ Setup Steps

### 1. Create Helm Values Override

Create the values override file in your argocd-resources repository:

```bash
# In your argocd-resources repo
mkdir -p prod/helm-private/n8n-patched
```

**File: `prod/helm-private/n8n-patched/values-override.yaml`**

```yaml
# Image configuration
image:
  repository: git.corp.worldstream.com/worldstream/levi9/n8n-improves/n8n-patched
  tag: latest
  pullPolicy: Always

imagePullSecrets:
  - name: gitlab-registry-secret

# Ingress configuration
ingress:
  enabled: true
  className: "apisix"
  annotations:
    k8s.apisix.apache.org/tls-redirect: "true"
    k8s.apisix.apache.org/http-to-https: "true"
  hosts:
    - host: n8n.corp.worldstream.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: n8n-tls
      hosts:
        - n8n.corp.worldstream.com

# Database configuration
n8n:
  config:
    database:
      host: postgres-n8n.orchestration.svc.cluster.local
      password: ${DATABASE_PASSWORD}
    security:
      basicAuth:
        password: ${BASIC_AUTH_PASSWORD}

# Resources for production
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi

# PostgreSQL (reuse existing or create new)
postgresql:
  enabled: false  # Use external CloudNative-PG cluster

# Redis configuration
redis:
  enabled: true
  auth:
    password: ${REDIS_PASSWORD}
```

### 2. Update ArgoCD ApplicationSet

**Option A: Modify existing `general-apps.yaml`**

Replace the n8n entry:

```yaml
# Replace this entry in prod/argocd/applicationsets/general-apps.yaml
- name: n8n-patched
  namespace: orchestration
  repoURL: "oci://git.corp.worldstream.com/worldstream/levi9/n8n-improves/charts"
  chart: n8n-patched
  targetRevision: "latest"
  valuesOverridePath: prod/helm-private/n8n-patched
  ServerSideApply: ServerSideApply=false
```

**Option B: Create separate ApplicationSet**

Apply the provided `argocd/n8n-patched-applicationset.yaml` for more control.

### 3. Create Registry Secrets

Create GitLab registry access secret:

```bash
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=git.corp.worldstream.com \
  --docker-username=gitlab-ci-token \
  --docker-password=$CI_JOB_TOKEN \
  --docker-email=devops@worldstream.com \
  --namespace=orchestration
```

### 4. Configure GitLab CI/CD Variables

Add these variables to your GitLab project:

```bash
# ArgoCD integration
ARGOCD_SERVER=argocd.corp.worldstream.com
ARGOCD_USERNAME=ci-deploy
ARGOCD_PASSWORD=<argocd-token>

# Registry configuration (auto-configured usually)
CI_REGISTRY=git.corp.worldstream.com
CI_REGISTRY_IMAGE=git.corp.worldstream.com/worldstream/levi9/n8n-improves
```

## 🔄 Deployment Workflow

### Automated Pipeline

1. **Code Changes** → Push to `feat/add-project-executor-role` branch
2. **GitLab CI/CD** → Tests, builds Docker image, packages Helm chart
3. **Registry** → Stores Docker image and Helm chart
4. **ArgoCD Sync** → Manual trigger via GitLab or automatic via ArgoCD
5. **Kubernetes** → Deploys patched n8n with executor role

### Manual Deployment

```bash
# 1. Trigger GitLab pipeline
git push origin feat/add-project-executor-role

# 2. Sync via ArgoCD CLI
argocd login argocd.corp.worldstream.com
argocd app sync n8n-patched
argocd app wait n8n-patched --health

# 3. Or sync via ArgoCD UI
# Go to ArgoCD UI → Applications → n8n-patched → Sync
```

## 🔍 Verification

### Check Deployment Status

```bash
# Check ArgoCD application
argocd app get n8n-patched

# Check Kubernetes resources
kubectl get all -n orchestration -l app.kubernetes.io/name=n8n-patched

# Check logs
kubectl logs -n orchestration deployment/n8n-patched -f
```

### Test Executor Role

1. **Access n8n** at https://n8n.corp.worldstream.com
2. **Create a project** and add users with different roles
3. **Verify executor role** allows:
   - ✅ View workflows and credentials
   - ✅ Execute workflows
   - ❌ Edit workflows (should be blocked)

### Monitor Health

```bash
# Check health endpoint
curl -k https://n8n.corp.worldstream.com/healthz

# Check ArgoCD sync status
argocd app wait n8n-patched --health --timeout 300
```

## 🚨 Migration Considerations

### Database Migration

If migrating from existing n8n:

```bash
# 1. Backup existing database
kubectl exec -n orchestration postgres-n8n-0 -- pg_dump -U n8n n8n > n8n_backup.sql

# 2. Deploy patched version with same database
# 3. Verify data integrity and role functionality
```

### User Permissions

After migration, update user roles:

```sql
-- Update existing users to use new executor role
UPDATE user_shared_workflow
SET role = 'project:executor'
WHERE role = 'project:viewer'
  AND user_id IN (SELECT id FROM users WHERE should_have_execute_access = true);
```

### Rollback Plan

```bash
# Quick rollback to original n8n
argocd app sync n8n-original --force
argocd app wait n8n-original --health

# Or update ApplicationSet to use original image
kubectl patch applicationset general-apps -n argocd --type='merge' -p='{"spec":{"template":{"spec":{"sources":[{"helm":{"parameters":[{"name":"image.repository","value":"8gears.container-registry.com/library/n8n"}]}}]}}}}'
```

## 📊 Benefits of ArgoCD Integration

✅ **GitOps Workflow** - All changes tracked in Git
✅ **Automated Deployments** - CI/CD triggers ArgoCD sync
✅ **Rollback Capability** - Easy rollback via ArgoCD
✅ **Multi-Environment** - Staging and production with same process
✅ **Monitoring** - ArgoCD health checks and notifications
✅ **Security** - Registry credentials and RBAC via Kubernetes

## 🔧 Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check registry secret
   kubectl get secret gitlab-registry-secret -n orchestration -o yaml

   # Update secret if needed
   kubectl delete secret gitlab-registry-secret -n orchestration
   kubectl create secret docker-registry gitlab-registry-secret --docker-server=...
   ```

2. **ArgoCD Sync Failures**
   ```bash
   # Check ArgoCD logs
   kubectl logs -n argocd deployment/argocd-application-controller

   # Force refresh
   argocd app refresh n8n-patched --hard
   ```

3. **Health Check Failures**
   ```bash
   # Check n8n logs
   kubectl logs -n orchestration deployment/n8n-patched -f

   # Check database connectivity
   kubectl exec -n orchestration deployment/n8n-patched -- wget -qO- http://localhost:5678/healthz
   ```

---

🎉 **Your patched n8n with project:executor role is now fully integrated with ArgoCD!**
