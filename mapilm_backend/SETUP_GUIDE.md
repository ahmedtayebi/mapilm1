# دليل إعداد وتشغيل Mapilm

## متطلبات النظام
- Python 3.11+
- Flutter 3.22+
- Git

---

## 1. إعداد Firebase

### 1.1 إنشاء المشروع
1. افتح [console.firebase.google.com](https://console.firebase.google.com)
2. انقر **Add project** → اكتب `mapilm` → أنشئ المشروع

### 1.2 تفعيل Phone Authentication
1. من القائمة الجانبية: **Authentication** → **Sign-in method**
2. انقر **Phone** → فعّله → احفظ

### 1.3 إضافة تطبيق Android
1. من **Project Overview** → انقر أيقونة Android
2. **Package name**: `com.mapilm.app`
3. حمّل `google-services.json`
4. ضعه في: `mapilm_app/android/app/google-services.json`

### 1.4 إضافة تطبيق iOS
1. من **Project Overview** → انقر أيقونة Apple
2. **Bundle ID**: `com.mapilm.app`
3. حمّل `GoogleService-Info.plist`
4. ضعه في: `mapilm_app/ios/Runner/GoogleService-Info.plist`

### 1.5 مفاتيح Firebase Admin (للـ Backend)
1. **Project Settings** → **Service Accounts**
2. انقر **Generate new private key** → حمّل الـ JSON
3. انسخ محتوى الملف → ضعه في متغير `FIREBASE_CREDENTIALS` في `.env` (سطر واحد)

---

## 2. إعداد Cloudinary

1. أنشئ حساباً مجانياً على [cloudinary.com](https://cloudinary.com)
2. من **Dashboard** انسخ:
   - **Cloud Name** → `CLOUDINARY_CLOUD_NAME`
   - **API Key** → `CLOUDINARY_API_KEY`
   - **API Secret** → `CLOUDINARY_API_SECRET`

---

## 3. النشر على Railway

### 3.1 إنشاء المشروع
1. افتح [railway.app](https://railway.app) → **New Project**
2. **Deploy from GitHub repo** → اختر `mapilm_backend`
3. Railway سيكشف `nixpacks.toml` تلقائياً ويبني المشروع

### 3.2 إضافة قاعدة البيانات
1. في لوحة المشروع → **New** → **Database** → **PostgreSQL**
2. Railway سيضيف `DATABASE_URL` تلقائياً كـ variable

### 3.3 إضافة Redis
1. **New** → **Database** → **Redis**
2. Railway سيضيف `REDIS_URL` تلقائياً

### 3.4 إضافة متغيرات البيئة
في تبويب **Variables** أضف المتغيرات التالية (انسخ من `.env.example`):

| المتغير | القيمة |
|---------|--------|
| `SECRET_KEY` | مفتاح عشوائي آمن (استخدم: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`) |
| `DEBUG` | `False` |
| `ALLOWED_HOSTS` | `your-app.railway.app` |
| `CORS_ALLOWED_ORIGINS` | `https://your-app.railway.app` |
| `FIREBASE_CREDENTIALS` | محتوى JSON الـ service account (سطر واحد) |
| `CLOUDINARY_CLOUD_NAME` | اسم الـ cloud |
| `CLOUDINARY_API_KEY` | مفتاح API |
| `CLOUDINARY_API_SECRET` | سر API |
| `FLUTTER_BASE_URL` | `https://your-app.railway.app` |

### 3.5 النطاق (Domain)
بعد النشر، ستجد URL تلقائياً مثل `https://mapilm-production.railway.app`
استخدمه في متغير `BASE_URL` في `.env` تطبيق Flutter.

---

## 4. تشغيل المشروع محلياً

### Backend

```bash
cd mapilm_backend

# إنشاء بيئة افتراضية
python -m venv venv
source venv/bin/activate          # Linux/macOS
# venv\Scripts\activate           # Windows

# تثبيت المكتبات
pip install -r requirements.txt

# إعداد ملف البيئة
cp .env.example .env
# عدّل .env بالقيم الحقيقية

# تشغيل PostgreSQL و Redis محلياً (Docker مثلاً):
# docker run -d -p 5432:5432 -e POSTGRES_DB=mapilm -e POSTGRES_PASSWORD=pass postgres:16
# docker run -d -p 6379:6379 redis:7

# تطبيق migrations
python manage.py migrate

# تشغيل Celery (في terminal منفصل)
celery -A config.celery worker --loglevel=info

# تشغيل الخادم
python manage.py runserver
# أو مع Daphne (WebSocket):
# daphne config.asgi:application --port 8000 --bind 0.0.0.0
```

### Flutter App

```bash
cd mapilm_app

# تثبيت المكتبات
flutter pub get

# إعداد ملف البيئة
cp .env.example .env
# عدّل .env:
# BASE_URL=http://10.0.2.2:8000/api/v1      (Android emulator)
# BASE_URL=http://localhost:8000/api/v1      (iOS simulator)
# WS_URL=ws://10.0.2.2:8000/ws              (Android emulator)
# WS_URL=ws://localhost:8000/ws              (iOS simulator)

# ضع google-services.json في android/app/
# ضع GoogleService-Info.plist في ios/Runner/

# تشغيل التطبيق
flutter run
```

---

## 5. هيكل API

| Endpoint | Method | الوصف |
|----------|--------|-------|
| `/api/v1/auth/verify/` | POST | التحقق من Firebase token وإنشاء JWT |
| `/api/v1/auth/refresh/` | POST | تجديد JWT access token |
| `/api/v1/auth/logout/` | POST | تسجيل الخروج وإلغاء الـ token |
| `/api/v1/users/me/` | GET | بيانات المستخدم الحالي |
| `/api/v1/users/profile/update/` | PUT | تحديث الملف الشخصي |
| `/api/v1/users/search/` | GET | البحث عن مستخدمين |
| `/api/v1/users/fcm-token/` | POST | تسجيل FCM token للإشعارات |
| `/api/v1/contacts/` | GET | قائمة جهات الاتصال |
| `/api/v1/contacts/add/` | POST | إضافة جهة اتصال |
| `/api/v1/contacts/block/<uuid>/` | POST | حظر مستخدم |
| `/api/v1/contacts/unblock/<uuid>/` | DELETE | إلغاء حظر مستخدم |
| `/api/v1/conversations/` | GET | قائمة المحادثات |
| `/api/v1/conversations/private/` | POST | إنشاء محادثة خاصة |
| `/api/v1/conversations/group/` | POST | إنشاء مجموعة |
| `/api/v1/messages/send/` | POST | إرسال رسالة |
| `/api/v1/messages/upload-media/` | POST | رفع ملف وسائط |
| `/api/v1/invite/generate/` | POST | إنشاء رابط دعوة |

### WebSocket
```
wss://your-app.railway.app/ws/chat/<conversation_id>/?token=<firebase_token>
```

---

## 6. API Docs
بعد تشغيل الخادم:
- Swagger: `http://localhost:8000/api/docs/`
- ReDoc: `http://localhost:8000/api/redoc/`
- Schema: `http://localhost:8000/api/schema/`
