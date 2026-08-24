#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Starting Bookstore Deployment (SQLite + UV + runserver)..."

actions /opt/bookstore || exit 1

# Pull latest changes
echo "📦 Pulling latest code..."
git pull origin main

# Backup SQLite database
echo "💾 Backing up SQLite database..."
if [ -f "data/db.sqlite3" ]; then
    mkdir -p /opt/backups
    cp data/db.sqlite3 /opt/backups/db_backup_$(date +%Y%m%d_%H%M%S).sqlite3
    echo "✅ Database backup created"
fi

# Build and start containers
echo "🐳 Building Docker containers..."
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Wait for app to start
echo "⏳ Waiting for application..."
sleep 5

# Run migrations
echo "🗄️ Running database migrations..."
docker exec bookstore_web python manage.py makemigrations
docker exec bookstore_web python manage.py migrate

# Collect static files
echo "📁 Collecting static files..."
docker exec bookstore_web python manage.py collectstatic --noinput

# Health check
echo "🏥 Checking application health..."
sleep 3
if curl -f http://localhost:8000/api/books/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo "📚 Bookstore is running at: http://localhost:8000/api/books/"
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    docker-compose logs --tail=50 web
    exit 1
fi