#!/bin/bash

# 3D Human Motion Comparison System - Docker Deployment Script

echo "================================================"
echo "  3D Motion Comparison System - Docker Setup"
echo "================================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed."
    exit 1
fi

echo ""
echo "✅ Docker is installed"
echo ""

# Stop and remove existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Build the Docker image
echo ""
echo "🔨 Building Docker image..."
docker-compose build

# Start the services
echo ""
echo "🚀 Starting services..."
docker-compose up -d

# Wait for database to be ready
echo ""
echo "⏳ Waiting for database to be ready..."
sleep 10

# Check service status
echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "================================================"
echo "  ✅ Deployment Complete!"
echo "================================================"
echo ""
echo "Services running:"
echo "  - PostgreSQL Database: localhost:5432"
echo "  - Application: localhost:8000"
echo ""
echo "Useful commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Stop services: docker-compose down"
echo "  - Restart services: docker-compose restart"
echo "  - Access database: docker-compose exec db psql -U postgres -d motion_compare_db"
echo ""
