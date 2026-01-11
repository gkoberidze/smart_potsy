# ===========================================
# 🌱 GREENHOUSE IOT - PRODUCTION DEPLOYMENT GUIDE
# ===========================================

## 📋 წინაპირობები

- Ubuntu 22.04 სერვერი (მინ. 2GB RAM, 25GB SSD)
- დომენის სახელი (მაგ: greenhouse.yourdomain.com)
- დომენის A record მიმართული სერვერის IP-ზე

---

## 🚀 სწრაფი Deploy (5 წუთი)

### 1. სერვერზე შესვლა
```bash
ssh root@your-server-ip
```

### 2. პროექტის გადმოწერა
```bash
git clone https://github.com/gkoberidze/greenhouse-iot.git
cd greenhouse-iot
```

### 3. Environment-ის კონფიგურაცია
```bash
cp .env.production.example .env
nano .env
```

შეავსე შემდეგი მნიშვნელობები:
```
DB_PASSWORD=YourStrongPassword123!
JWT_SECRET=<გენერირება: openssl rand -hex 64>
DOMAIN=yourdomain.com
SSL_EMAIL=your@email.com
```

### 4. Deploy-ის გაშვება
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

---

## ✅ Deploy-ის შემდეგ

### API შემოწმება:
```bash
curl https://yourdomain.com/health
```

### MQTT შემოწმება:
```bash
mosquitto_pub -h yourdomain.com -t "greenhouse/TEST-0001-0001/status" -m "online"
```

---

## 📱 Flutter App-ის განახლება

შეცვალე `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'https://yourdomain.com';
```

### APK Build:
```bash
cd smart_potsy
flutter build apk --release
```

APK მდებარეობა: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔧 სასარგებლო ბრძანებები

| ბრძანება | აღწერა |
|----------|--------|
| `docker-compose -f docker-compose.prod.yml logs -f` | ლოგების ნახვა |
| `docker-compose -f docker-compose.prod.yml restart` | რესტარტი |
| `docker-compose -f docker-compose.prod.yml down` | გაჩერება |
| `./backup.sh` | Database backup |

---

## 🔐 უსაფრთხოება

- ✅ HTTPS/SSL (Let's Encrypt)
- ✅ Rate Limiting (nginx)
- ✅ Security Headers
- ✅ Password Hashing (bcrypt 12 rounds)
- ✅ JWT ავთენტიფიკაცია (24h expiry)

---

## 📡 MQTT Topics

| Topic | აღწერა |
|-------|--------|
| `greenhouse/{deviceId}/telemetry` | სენსორების მონაცემები |
| `greenhouse/{deviceId}/status` | მოწყობილობის სტატუსი |

**Device ID ფორმატი:** `GH-XXXX-XXXX`

---

## 🆘 პრობლემების მოგვარება

### SSL არ მუშაობს
```bash
docker-compose -f docker-compose.prod.yml logs nginx
certbot certificates
```

### Backend არ იწყება
```bash
docker-compose -f docker-compose.prod.yml logs backend
```

### Database კავშირის პრობლემა
```bash
docker-compose -f docker-compose.prod.yml logs db
```
