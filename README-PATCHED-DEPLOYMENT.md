# 🚀 Automated n8n Deployment with Project Executor Role

This repository provides an automated solution to deploy n8n with a custom `project:executor` role patch that cannot wait for upstream approval.

## 📋 Overview

The `project:executor` role provides a middle ground between `project:viewer` (read-only) and `project:editor` (full edit permissions), allowing users to:
- ✅ View all project resources (workflows, credentials, folders)
- ✅ Execute workflows
- ❌ Edit or modify workflows
- ❌ Create new workflows
- ❌ Manage project settings

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitLab CI/CD  │───▶│  Docker Registry │───▶│  Production     │
│                 │    │                  │    │  Environment    │
│ • Test patch    │    │ • Store images   │    │ • Auto-deploy   │
│ • Build image   │    │ • Version tags   │    │ • Health checks │
│ • Auto-deploy   │    │                  │    │ • Rollback      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🛠️ Setup Instructions

### 1. Prerequisites

- GitLab instance with CI/CD enabled
- Docker Registry access
- Target servers with Docker and Docker Compose
- SSH access to deployment servers

### 2. GitLab Variables Configuration

Set these variables in your GitLab project's CI/CD settings:

#### Required Variables:
```bash
# Docker Registry (usually auto-configured)
CI_REGISTRY_USER          # GitLab username
CI_REGISTRY_PASSWORD      # GitLab access token
CI_REGISTRY               # Your GitLab registry URL

# Staging Environment
STAGING_HOST              # staging.yourdomain.com
STAGING_USER              # deployment user on staging
STAGING_SSH_PRIVATE_KEY   # SSH private key for staging

# Production Environment
PRODUCTION_HOST           # n8n.yourdomain.com
PRODUCTION_USER           # deployment user on production
PRODUCTION_SSH_PRIVATE_KEY # SSH private key for production

# Git Configuration
GITLAB_USER_EMAIL         # your.email@company.com
GITLAB_USER_NAME          # Your Name
```

### 3. Server Setup

On each target server, create the deployment directory:

```bash
# Create deployment directory
sudo mkdir -p /opt/n8n-patched
sudo chown $USER:$USER /opt/n8n-patched
cd /opt/n8n-patched

# Copy docker-compose.yml from this repository
# Customize environment variables as needed
```

### 4. Local Development Setup

```bash
# Clone the repository
git clone <your-gitlab-repo-url>
cd n8n-improves

# Install dependencies
pnpm install

# Test the patch
pnpm test --filter=@n8n/permissions

# Build patched Docker image locally
chmod +x scripts/build-patched-n8n.sh
./scripts/build-patched-n8n.sh

# Run locally
docker-compose up -d
```

## 🔄 Automated Workflows

### GitLab CI/CD Pipeline

The pipeline consists of 3 stages:

#### 1. **Test Stage** 🧪
- Validates patch compatibility
- Runs permission tests
- Ensures code quality

#### 2. **Build Stage** 🏗️
- Creates Docker image with patch applied
- Pushes to GitLab Container Registry
- Tags with commit SHA and 'latest'

#### 3. **Deploy Stage** 🚀
- **Staging**: Auto-deploy for testing (manual trigger)
- **Production**: Deploy to production (manual trigger)
- Includes health checks and rollback capabilities

### Automatic Updates 📅

A scheduled job runs weekly to:
1. Fetch latest n8n changes from upstream
2. Attempt to reapply the executor role patch
3. Create new commit if successful
4. Trigger new build pipeline

## 🚀 Usage

### Quick Start

1. **Push to patch branch:**
   ```bash
   git push origin feat/add-project-executor-role
   ```

2. **Pipeline runs automatically:**
   - Tests pass ✅
   - Docker image builds ✅
   - Ready for deployment 🚀

3. **Deploy to staging:**
   - Go to GitLab CI/CD → Pipelines
   - Click "▶️" on `deploy-staging` job
   - Test at `https://your-staging-host:5678`

4. **Deploy to production:**
   - Go to GitLab CI/CD → Pipelines
   - Click "▶️" on `deploy-production` job
   - Available at `https://your-production-host:5678`

### Manual Commands

```bash
# Build locally
./scripts/build-patched-n8n.sh

# Update patch with latest n8n
./scripts/update-and-patch.sh

# Deploy with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f n8n-patched
```

## 🛡️ Security Considerations

- 🔐 All credentials stored as GitLab CI/CD variables
- 🔑 SSH keys used for secure server access
- 📦 Images stored in private GitLab registry
- 🩺 Health checks ensure deployment success
- ↩️ Automatic rollback on failure

## 📊 Monitoring

### Health Checks

The Docker container includes built-in health checks:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1
```

### Logging

View application logs:
```bash
# All services
docker-compose logs -f

# n8n only
docker-compose logs -f n8n-patched

# PostgreSQL only
docker-compose logs -f postgres
```

## 🔧 Troubleshooting

### Common Issues

1. **Pipeline fails on test stage:**
   ```bash
   # Run tests locally
   pnpm test --filter=@n8n/permissions
   ```

2. **Docker build fails:**
   ```bash
   # Check patch file
   git apply --check executor-role.patch

   # Rebuild locally
   ./scripts/build-patched-n8n.sh
   ```

3. **Deployment fails:**
   ```bash
   # Check server connectivity
   ssh user@server "docker --version"

   # Check image availability
   docker pull $CI_REGISTRY_IMAGE/n8n-patched:latest
   ```

4. **Patch conflicts with new n8n version:**
   ```bash
   # Manual update process
   git fetch upstream
   git rebase upstream/master
   # Resolve conflicts manually
   git add .
   git commit
   ```

### Update Patch for New n8n Version

If automatic updates fail:

1. **Manual conflict resolution:**
   ```bash
   ./scripts/update-and-patch.sh
   # If conflicts occur, resolve manually:
   git status
   # Edit conflicted files
   git add .
   git commit
   git format-patch HEAD~1 --stdout > executor-role.patch
   ```

2. **Test updated patch:**
   ```bash
   pnpm install --frozen-lockfile
   pnpm build
   pnpm test --filter=@n8n/permissions
   ```

3. **Deploy updated version:**
   ```bash
   git push origin feat/add-project-executor-role
   # Pipeline will run automatically
   ```

## 📈 Benefits

✅ **Immediate deployment** - Don't wait for upstream approval
✅ **Automated updates** - Stay current with n8n releases
✅ **Production ready** - Health checks, rollbacks, monitoring
✅ **GitLab integrated** - Seamless CI/CD workflow
✅ **Reproducible** - Consistent deployments across environments

## 🤝 Contributing

1. Make changes to the patch in your branch
2. Test locally: `pnpm test --filter=@n8n/permissions`
3. Update patch: `git format-patch HEAD~1 --stdout > executor-role.patch`
4. Push and let CI/CD handle the rest!

## 📄 Files Overview

- `Dockerfile.patched` - Multi-stage Docker build with patch
- `docker-compose.yml` - Production deployment configuration
- `executor-role.patch` - Git patch with executor role changes
- `.gitlab-ci.yml` - GitLab CI/CD pipeline configuration
- `scripts/build-patched-n8n.sh` - Local build script
- `scripts/update-and-patch.sh` - Automatic update script

---

🎉 **Ready to deploy your patched n8n with the project:executor role!**
