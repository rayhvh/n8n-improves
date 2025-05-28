#!/bin/bash
set -e

# Configuration
IMAGE_NAME="n8n-patched"
IMAGE_TAG="latest"
N8N_VERSION=${1:-"master"}  # Allow specifying n8n version as first argument

echo "🚀 Building patched n8n Docker image..."
echo "📋 Configuration:"
echo "   - Base n8n version: ${N8N_VERSION}"
echo "   - Image name: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Create patch if it doesn't exist or if requested
if [[ ! -f "executor-role.patch" ]] || [[ "$2" == "--refresh-patch" ]]; then
    echo "📦 Creating fresh patch file..."
    git format-patch HEAD~1 --stdout > executor-role.patch
    echo "✅ Patch file created/updated"
fi

# Build the Docker image
echo "🔨 Building Docker image..."
docker build \
    --build-arg N8N_VERSION=${N8N_VERSION} \
    -f Dockerfile.patched \
    -t ${IMAGE_NAME}:${IMAGE_TAG} \
    -t ${IMAGE_NAME}:${N8N_VERSION} \
    .

echo ""
echo "✅ Build completed successfully!"
echo "📋 Available images:"
docker images | grep ${IMAGE_NAME}
echo ""
echo "🚀 To run the patched n8n:"
echo "   docker-compose up -d"
echo ""
echo "🌐 n8n will be available at: http://localhost:5678"
echo "   Username: admin"
echo "   Password: admin"
