#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 Starting Deployment..."

# ============================================
# ১. সঠিক ডিরেক্টরিতে যান
# ============================================
cd /opt/actions || exit 1   # 👈 আপনার প্রজেক্টের নাম দিন

# ============================================
# ২. Latest code pull করুন
# ============================================
echo "📦 Pulling latest code..."
git pull origin main || git pull origin master

# ============================================
# ৩. SQLite Database Backup
# ============================================
echo "💾 Backing up database..."
if [ -f "db.sqlite3" ]; then
    mkdir -p /opt/backups
    cp db.sqlite3 /opt/backups/db_backup_$(date +%Y%m%d_%H%M%S).sqlite3
    echo "✅ Database backup created"
elif [ -f "data/db.sqlite3" ]; then
    mkdir -p /opt/backups
    cp data/db.sqlite3 /opt/backups/db_backup_$(date +%Y%m%d_%H%M%S).sqlite3
    echo "✅ Database backup created"
else
    echo "⚠️  No SQLite database found"
fi

# ============================================
# ৪. Docker containers বিল্ড ও রান
# ============================================
echo "🐳 Building Docker containers..."
docker-compose down --remove-orphans || true
docker-compose build --no-cache
docker-compose up -d

# ============================================
# ৫. App start হওয়ার জন্য অপেক্ষা
# ============================================
echo "⏳ Waiting for application to start..."
sleep 10

# ============================================
# ৬. Container নাম খুঁজে বের করুন
# ============================================
CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -E "web|app|actions" | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ No running container found!"
    docker-compose logs --tail=50
    exit 1
fi

echo "🐳 Using container: $CONTAINER_NAME"

# ============================================
# ৭. Database Migrations
# ============================================
echo "🗄️ Running database migrations..."
docker exec $CONTAINER_NAME python manage.py makemigrations || true
docker exec $CONTAINER_NAME python manage.py migrate --noinput

# ============================================
# ৮. Collect static files
# ============================================
echo "📁 Collecting static files..."
docker exec $CONTAINER_NAME python manage.py collectstatic --noinput || true

# ============================================
# ৯. Health Check (সঠিক URL দিয়ে)
# ============================================
echo "🏥 Checking application health..."
sleep 5

# বিভিন্ন possible URL চেক করুন
if curl -f http://localhost:8000/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo "🌐 Application is running at: http://localhost:8000"
elif curl -f http://localhost:8000/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo "🌐 API is running at: http://localhost:8000/api/"
elif curl -f http://localhost:8000/admin/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo "🌐 Admin is running at: http://localhost:8000/admin/"
else
    echo -e "${YELLOW}⚠️  Health check failed! Checking logs...${NC}"
    docker-compose logs --tail=50
    exit 1
fi

# ============================================
# ১০. Container status দেখান
# ============================================
echo ""
echo "📊 Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"