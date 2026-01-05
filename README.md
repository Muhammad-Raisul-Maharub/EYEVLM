# 👁️ EyeVLM - AI-Powered Eye Disease Detection

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20DB-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Vercel](https://img.shields.io/badge/Vercel-Deployed-000000?logo=vercel&logoColor=white)](https://vercel.com)
[![Render](https://img.shields.io/badge/Render-Backend-46E3B7?logo=render&logoColor=white)](https://render.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Thesis Project:** Computer-Aided Diagnosis system for early detection of ocular diseases using Vision-Language Models.

EyeVLM is a cross-platform (Mobile & Web) application designed to assist in the early detection of eye diseases using advanced AI. It captures eye images via Smart Camera with ML Kit face detection, collects clinical data, and provides AI-powered analysis through a FastAPI backend.

---

## 📥 **Try It Now**

| Platform | Version | Action |
| :--- | :--- | :--- |
| **Web App** | ✅ **Live** | [Launch Web App](https://eyevlm-app.vercel.app) |
| **Android App** | ✅ **v1.1** | [Download APK](https://drive.google.com/file/d/1eaExq4f8d7wmSyTdqM-86el766NOwlCo/view?usp=sharing) |
| **Backend API** | ✅ **Live** | [API Status](https://eyevlm-backend.onrender.com) |

---

## 🚀 **Key Features**

### Smart Camera System
- **Real-time Face Detection** using Google ML Kit
- **Eye Open Probability** checking (auto-captures when eyes are open)
- **Auto-capture** after detecting stable, valid frames
- **Free-form Image Cropping** for precise selection

### AI-Powered Analysis
- **Vision-Language Model** for eye disease detection
- **Multi-class Prediction** with confidence scores
- **Explainable AI** providing reasoning for predictions
- **JWT-authenticated** backend requests

### Clinical Data Collection
- **Patient Demographics** (age, gender)
- **Disease Category** dropdown (Cataract, Glaucoma, Diabetic Retinopathy, etc.)
- **Symptom Checkboxes** (Blurred Vision, Eye Pain, Redness, etc.)
- **File Attachments** (medical records, reports)
- **JSONB Storage** for flexible data analysis

### Data Management
- **Session-based Storage** (`scans/{sessionId}/`)
- **Complete Delete** (removes all files + database record)
- **Cloud History** with instant deletion (optimistic UI)
- **CSV Export** for thesis data analysis
- **Secure Storage** via Supabase with Row Level Security

### UI/UX
- **Modern Teal Theme** with light/dark mode
- **Responsive Design** works on mobile and web
- **Professional Onboarding** flow
- **Glassmorphism Effects** and animations

---

## 🛠 **Tech Stack**

### Frontend
| Technology | Purpose |
|------------|---------|
| Flutter 3.x | Cross-platform UI |
| Riverpod | State Management |
| GoRouter | Navigation |
| Google ML Kit | Face Detection |
| Flutter Animate | Animations |

### Backend
| Technology | Purpose |
|------------|---------|
| FastAPI (Python) | AI Inference API |
| Supabase | Auth, Database, Storage |
| PostgreSQL | Data storage with JSONB |
| Render | Backend hosting |
| Vercel | Web hosting |

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
│   └── utils/                   # Camera utilities
└── features/
    ├── scan/                    # Smart Camera + Clinical Form + Repository
    ├── history/                 # Scan history + CSV export
    ├── home/                    # Dashboard
    ├── auth/                    # Login/Signup
    ├── profile/                 # Settings, Privacy, Ethics
    └── onboarding/              # Welcome screens

backend/
├── main.py                      # FastAPI server
├── auth.py                      # JWT verification
└── requirements.txt             # Python dependencies
```

---

## 🔧 **Local Development**

### Prerequisites
- Flutter SDK 3.0+
- Python 3.9+ (for backend)
- Supabase Account

### Setup
```bash
# Clone
git clone https://github.com/Muhammad-Raisul-Maharub/EYEVLM.git
cd EYEVLM

# Install Flutter dependencies
flutter pub get

# Run Frontend
flutter run -d chrome    # Web
flutter run              # Mobile
```

### Backend Setup
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --reload --port 8080
```

### Build
```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release
```

---

## 📊 **Database Schema**

### `scans` table
| Column | Type | Description |
|--------|------|-------------|
| id | int8 | Primary key |
| user_id | uuid | User reference |
| created_at | timestamptz | Scan timestamp |
| image_url | text | Supabase storage URL |
| prediction | text | AI prediction result |
| confidence | float8 | Confidence score |
| symptoms | text | Disease category |
| clinical_data | jsonb | Symptoms, notes, attachments, AI explanation |
| patient_age | int4 | Patient age |
| patient_gender | text | Male/Female/Other |
| suspected_disease | text | Disease category |

### Storage Structure
```
eye-images/
└── scans/
    └── {userId}_{timestamp}/
        ├── eye_image.jpg
        └── attachments/
            └── report.pdf
```

---

## 🌐 **Deployment**

### Web (Vercel)
```bash
flutter build web --release
cd build/web
vercel deploy --prod
```

### Backend (Render)
Deploy from GitHub with environment variable:
- `SUPABASE_JWT_SECRET` - Your Supabase JWT secret

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
