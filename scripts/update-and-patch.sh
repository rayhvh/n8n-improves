#!/bin/bash
set -e

# Configuration
UPSTREAM_REMOTE="upstream"
PATCH_BRANCH="feat/add-project-executor-role"
MAIN_BRANCH="master"

echo "🔄 Updating and re-applying executor role patch..."
echo ""

# Ensure we're on the right branch
echo "📋 Checking current branch..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "$PATCH_BRANCH" ]]; then
    echo "⚠️  Currently on branch: $CURRENT_BRANCH"
    echo "🔄 Switching to patch branch: $PATCH_BRANCH"
    git checkout $PATCH_BRANCH
fi

# Fetch latest changes from upstream
echo "📥 Fetching latest changes from upstream..."
if git remote | grep -q "^${UPSTREAM_REMOTE}$"; then
    git fetch $UPSTREAM_REMOTE
else
    echo "➕ Adding upstream remote..."
    git remote add $UPSTREAM_REMOTE https://github.com/n8n-io/n8n.git
    git fetch $UPSTREAM_REMOTE
fi

# Backup current patch
echo "💾 Backing up current patch..."
git format-patch HEAD~1 --stdout > executor-role-backup.patch

# Reset to upstream master and reapply patch
echo "🔄 Resetting to latest upstream master..."
git reset --hard $UPSTREAM_REMOTE/$MAIN_BRANCH

echo "🩹 Applying executor role patch..."
if git apply executor-role-backup.patch; then
    echo "✅ Patch applied successfully!"

    # Commit the changes
    echo "📝 Committing updated changes..."
    git add .
    git commit -F- <<EOF
feat: add project:executor role with workflow execution permissions

- Add new project:executor role that extends project:viewer with workflow:execute scope
- Update ProjectRole type definitions and schema validation
- Add comprehensive test coverage for the new role
- Update role mappings and display names

The project:executor role provides a middle ground between project:viewer
(read-only) and project:editor (full edit permissions), allowing users to
view project resources and execute workflows without modification rights.

This enhances granular project permissions by providing a dedicated role
for users who need to execute workflows but should not have edit access.

Updated to latest n8n master: $(git rev-parse --short $UPSTREAM_REMOTE/$MAIN_BRANCH)
EOF

    # Update the main patch file
    git format-patch HEAD~1 --stdout > executor-role.patch

    # Clean up backup
    rm executor-role-backup.patch

    echo ""
    echo "✅ Successfully updated to latest n8n and reapplied patch!"
    echo "🏗️  Ready to rebuild Docker image with latest changes"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review changes: git show"
    echo "   2. Run tests: pnpm test --filter=@n8n/permissions"
    echo "   3. Rebuild image: ./scripts/build-patched-n8n.sh"

else
    echo "❌ Failed to apply patch automatically!"
    echo "🔧 Manual intervention required:"
    echo "   1. Check conflicts: git status"
    echo "   2. Resolve conflicts manually"
    echo "   3. Run: git add . && git commit"
    echo "   4. Update patch: git format-patch HEAD~1 --stdout > executor-role.patch"

    # Restore backup for manual fixing
    echo ""
    echo "📋 Backup patch saved as: executor-role-backup.patch"
    echo "   You can try: git apply --reject executor-role-backup.patch"

    exit 1
fi
