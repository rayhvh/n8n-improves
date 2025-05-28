#!/bin/bash
set -e

echo "🚀 Deploying patched n8n locally..."
echo ""

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Build and start
echo "🏗️ Building and starting n8n with executor role patch..."
docker-compose up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check health
echo "🩺 Checking service health..."
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "✅ n8n deployment successful!"
    echo ""
    echo "📋 Access your patched n8n instance:"
    echo "   🌐 URL: http://localhost:5678"
    echo "   👤 Username: admin"
    echo "   🔑 Password: admin"
    echo ""
    echo "📊 Available roles:"
    echo "   • project:viewer - View only"
    echo "   • project:executor - View + Execute workflows ⭐ NEW!"
    echo "   • project:editor - Full edit permissions"
    echo "   • project:admin - Full admin permissions"
    echo ""
    echo "📝 View logs with: docker-compose logs -f n8n-patched"
    echo "🛑 Stop with: docker-compose down"
else
    echo "❌ Deployment failed. Check logs with: docker-compose logs"
    exit 1
fi
