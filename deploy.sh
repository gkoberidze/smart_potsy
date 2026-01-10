#!/bin/bash
# ===========================================
# GREENHOUSE IOT - PRODUCTION DEPLOYMENT
# ===========================================

set -e

echo "🌱 Greenhouse IoT - Production Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy.sh)"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "📝 Copy .env.production.example to .env and fill in values:"
    echo "   cp .env.production.example .env"
    echo "   nano .env"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" == "CHANGE_ME_STRONG_PASSWORD_HERE" ]; then
    echo "❌ Please set a strong DB_PASSWORD in .env"
    exit 1
fi

if [ -z "$JWT_SECRET" ] || [ "$JWT_SECRET" == "CHANGE_ME_GENERATE_WITH_OPENSSL_RAND_HEX_64" ]; then
    echo "❌ Please set JWT_SECRET in .env"
    echo "   Generate with: openssl rand -hex 64"
    exit 1
fi

if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "yourdomain.com" ]; then
    echo "❌ Please set your DOMAIN in .env"
    exit 1
fi

if [ -z "$SSL_EMAIL" ] || [ "$SSL_EMAIL" == "your@email.com" ]; then
    echo "❌ Please set SSL_EMAIL in .env"
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
mkdir -p certbot/conf certbot/www nginx/ssl backups

# Update nginx.conf with domain
sed -i "s/\${DOMAIN}/$DOMAIN/g" nginx/nginx.conf

# Create initial nginx config for SSL certificate
cat > nginx/nginx-init.conf << 'EOF'
events { worker_connections 1024; }
http {
    server {
        listen 80;
        server_name _;
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        location / {
            return 200 'Greenhouse IoT - Getting SSL certificate...';
            add_header Content-Type text/plain;
        }
    }
}
EOF

echo "🔐 Getting SSL certificate..."

# Start nginx with init config
docker run -d --name nginx-init \
    -p 80:80 \
    -v $(pwd)/nginx/nginx-init.conf:/etc/nginx/nginx.conf:ro \
    -v $(pwd)/certbot/www:/var/www/certbot:ro \
    nginx:alpine

# Get SSL certificate
docker run --rm \
    -v $(pwd)/certbot/conf:/etc/letsencrypt \
    -v $(pwd)/certbot/www:/var/www/certbot \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $SSL_EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN

# Stop init nginx
docker stop nginx-init && docker rm nginx-init

echo "✅ SSL certificate obtained"

# Build and start production containers
echo "🚀 Starting production containers..."
docker-compose -f docker-compose.prod.yml up -d --build

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Your API is available at: https://$DOMAIN"
echo "📡 MQTT Broker: $DOMAIN:1883"
echo ""
echo "📱 Update Flutter app baseUrl to:"
echo "   https://$DOMAIN"
echo ""
echo "🔧 Useful commands:"
echo "   View logs:     docker-compose -f docker-compose.prod.yml logs -f"
echo "   Restart:       docker-compose -f docker-compose.prod.yml restart"
echo "   Stop:          docker-compose -f docker-compose.prod.yml down"
echo "   Backup DB:     ./backup.sh"
echo ""
