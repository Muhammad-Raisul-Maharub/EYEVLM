# 👁️ EyeVLM - AI-Powered Eye Disease Detection

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20DB-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Vercel](https://img.shields.io/badge/Vercel-Deployed-000000?logo=vercel&logoColor=white)](https://vercel.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Thesis Project:** Computer-Aided Diagnosis system for early detection of ocular diseases using Vision-Language Models.

EyeVLM is a cross-platform (Mobile & Web) application designed to assist in the early detection of eye diseases using advanced AI. It captures eye images via Smart Camera with ML Kit face detection, collects clinical data, and stores everything securely in Supabase.

---

## 📥 **Try It Now**

| Platform | Status | Action |
| :--- | :--- | :--- |
| **Android App** | ✅ **v1.0 Stable** | [Download APK](https://drive.google.com/file/d/1hwTOH1jhE8sWYBv5xYmM31JhQx5eoaYQ/view?usp=sharing) |
| **Web App** | ✅ **Live** | [Launch Web App](https://eyevlm-web.vercel.app) |

---

## 🚀 **Key Features**

### Smart Camera System
- **Real-time Face Detection** using Google ML Kit
- **Eye Open Probability** checking (auto-captures when eyes are open)
- **Auto-capture** after detecting stable, valid frames
- **Manual capture** fallback button

### Clinical Data Collection
- **Patient Demographics** (age, gender)
- **Disease Category** dropdown (Cataract, Glaucoma, Diabetic Retinopathy, etc.)
- **Symptom Checkboxes** (Blurred Vision, Eye Pain, Redness, etc.)
- **Additional Notes** text field
- **JSONB Storage** for flexible data analysis

### Data Management
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
| Supabase | Auth, Database, Storage |
| PostgreSQL | Data storage with JSONB |
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
    ├── scan/                    # Smart Camera + Clinical Form
    ├── history/                 # Scan history + CSV export
    ├── home/                    # Dashboard
    ├── auth/                    # Login/Signup
    ├── profile/                 # Settings, Privacy, Ethics
    └── onboarding/              # Welcome screens
```

---

## 🔧 **Local Development**

### Prerequisites
- Flutter SDK 3.0+
- Supabase Account

### Setup
```bash
# Clone
git clone https://github.com/Muhammad-Raisul-Maharub/EYEVLM.git
cd EYEVLM

# Install dependencies
flutter pub get

# Run
flutter run -d chrome    # Web
flutter run              # Mobile
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
| id | uuid | Primary key |
| user_id | uuid | User reference |
| image_url | text | Supabase storage URL |
| prediction | text | AI prediction result |
| confidence | float | Confidence score |
| patient_age | int | Patient age |
| patient_gender | text | Male/Female/Other |
| suspected_disease | text | Disease category |
| clinical_data | jsonb | Symptoms + notes JSON |

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
