#!/bin/bash
# ===========================================
# GREENHOUSE IOT - IP-ONLY DEPLOYMENT (NO DOMAIN)
# ===========================================

set -e

echo "🌱 Greenhouse IoT - IP-Only Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy-ip-only.sh)"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "📝 Creating .env from template..."
    cat > .env << EOF
# Database
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# JWT Secret
JWT_SECRET=$(openssl rand -hex 64)

# Server IP (update this)
SERVER_IP=161.35.219.50
EOF
    echo "✅ Created .env file. Please review and update SERVER_IP if needed."
    echo "   nano .env"
    read -p "Press Enter to continue after reviewing .env..."
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Please set DB_PASSWORD in .env"
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    echo "❌ Please set JWT_SECRET in .env"
    echo "   Generate with: openssl rand -hex 64"
    exit 1
fi

echo "✅ Environment variables validated"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker installed"

# Create directories
mkdir -p backups

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 80/tcp   # HTTP
ufw allow 3000/tcp # Backend (direct access)
ufw allow 1883/tcp # MQTT
ufw allow 22/tcp  # SSH (keep this!)

# Build and start containers
echo "🚀 Starting containers..."
docker-compose -f docker-compose.ip-only.yml up -d --build

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Your API is available at:"
echo "   http://${SERVER_IP:-161.35.219.50}:3000 (direct)"
echo "   http://${SERVER_IP:-161.35.219.50} (via nginx, if configured)"
echo ""
echo "📡 MQTT Broker: ${SERVER_IP:-161.35.219.50}:1883"
echo ""
echo "📱 Flutter app baseUrl should be:"
echo "   http://${SERVER_IP:-161.35.219.50}:3000"
echo ""
echo "🔧 Useful commands:"
echo "   View logs:     docker-compose -f docker-compose.ip-only.yml logs -f"
echo "   Restart:       docker-compose -f docker-compose.ip-only.yml restart"
echo "   Stop:          docker-compose -f docker-compose.ip-only.yml down"
echo ""
echo "🧪 Test API:"
echo "   curl http://${SERVER_IP:-161.35.219.50}:3000/health"
echo ""
