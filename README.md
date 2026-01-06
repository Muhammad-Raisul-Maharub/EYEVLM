# 👁️ EyeVLM - AI-Powered Eye Disease Detection

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20DB-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Vercel](https://img.shields.io/badge/Vercel-Deployed-000000?logo=vercel&logoColor=white)](https://vercel.com)
[![Render](https://img.shields.io/badge/Render-Backend-46E3B7?logo=render&logoColor=white)](https://render.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Thesis Project:** Computer-Aided Diagnosis system for early detection of ocular diseases using Vision-Language Models.

EyeVLM is a cross-platform (Mobile & Web) application designed to assist in the early detection of eye diseases using advanced AI. It captures eye images via Smart Camera with ML Kit face detection, collects clinical data, and provides AI-powered analysis through a FastAPI backend.

---

## 📥 **Download & Try**

| Platform | Version | Download |
|:---------|:--------|:---------|
| **Android App** | ✅ **v1.3.0** | [📱 Download APK](https://github.com/Muhammad-Raisul-Maharub/EYEVLM/releases/latest) |
| **Web App** | ✅ **Live** | [🌐 Launch Web App](https://eyevlm-app.vercel.app) |
| **Backend API** | ✅ **Live** | [🔗 API Status](https://eyevlm-backend.onrender.com) |

---

## 🆕 **What's New in v1.3.0**

- 📸 **Multi-Image Capture** - Capture up to 5 images per scan
- ✂️ **Manual Cropping** - Tap any image to crop (no auto-crop)
- 🔄 **Auto-Update Engine** - App checks GitHub for new versions
- 📶 **Offline Mode** - Scans saved locally when offline
- 🟢 **Connectivity Status** - Visual ONLINE/OFFLINE indicator
- 🎨 **New Splash Screen** - Branded teal theme

---

## 🚀 **Key Features**

### Smart Camera System
- **Real-time Face Detection** using Google ML Kit
- **Multi-image capture** (up to 5 images per scan)
- **Manual cropping** - tap to crop any image
- **Eye Open Probability** checking

### AI-Powered Analysis
- **Vision-Language Model** for eye disease detection
- **Multi-class Prediction** with confidence scores
- **Explainable AI** providing reasoning for predictions

### Clinical Data Collection
- **Patient Demographics** (age, gender)
- **Disease Category** dropdown
- **Symptom Checkboxes**
- **File Attachments**

### Auto-Update System
- Automatic update checks on app start
- Browser-based APK download from GitHub Releases
- Clear 3-step installation instructions

---

## 🛠 **Tech Stack**

| Frontend | Backend |
|----------|---------|
| Flutter 3.x | FastAPI (Python) |
| Riverpod | Supabase (Auth, DB, Storage) |
| GoRouter | PostgreSQL + JSONB |
| Google ML Kit | Render (hosting) |

---

## 📦 **Project Structure**

```
lib/
├── main.dart                    # App entry point
├── app_router.dart              # Navigation routes
├── core/
│   ├── theme/                   # AppTheme, AppTokens
│   ├── widgets/                 # Reusable UI components
│   ├── providers/               # Riverpod providers
│   ├── services/                # UpdateService, OfflineSync, PDF
│   └── utils/                   # Camera utilities
└── features/
    ├── scan/                    # Smart Camera + Clinical Form
    ├── history/                 # Scan history + CSV export
    ├── home/                    # Dashboard
    ├── auth/                    # Login/Signup
    └── profile/                 # Settings, Privacy
```

---

## 🔧 **Local Development**

```bash
# Clone
git clone https://github.com/Muhammad-Raisul-Maharub/EYEVLM.git
cd EYEVLM

# Install dependencies
flutter pub get

# Run
flutter run -d chrome    # Web
flutter run              # Mobile

# Build APK
flutter build apk --release
```

---

## 📊 **Database Schema**

### `scans` table
| Column | Type | Description |
|--------|------|-------------|
| id | int8 | Primary key |
| user_id | uuid | User reference |
| image_url | text | Primary image URL |
| image_urls | jsonb | Array of all image URLs |
| prediction | text | AI prediction result |
| confidence | float8 | Confidence score |
| clinical_data | jsonb | Symptoms, notes, AI explanation |

---

## ⚠️ **Medical Disclaimer**

**EyeVLM is an early indication tool, NOT a replacement for professional medical diagnosis.** This software is intended for research and educational purposes only. Always consult a certified ophthalmologist for clinical diagnosis and treatment.

---

## 👨‍💻 **Author**

**Muhammad Raisul Maharub**  
Computer Science & Engineering Student

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
