# 👁️ EyeVLM - AI-Powered Eye Disease Detection System

> **A Computer-Aided Diagnosis (CAD) system leveraging Vision-Language Models for early detection of ocular diseases.**

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/FastAPI-Python-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Database](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🌍 The Problem
Access to specialized eye care is a significant challenge in many parts of the world.
- **Limited resources:** Ophthalmologists are scarce in rural and underserved areas.
- **Late diagnosis:** Many eye diseases (Cataracts, Glaucoma, etc.) are preventable if detected early, but often go unnoticed until vision is permanently impaired.
- **Language barriers:** Medical advice is not always available in the patient's native language.

## 💡 The Solution: EyeVLM
**EyeVLM** bridges the gap between patients and early diagnosis. By combining the power of mobile technology and advanced AI (Vision-Language Models), it provides an accessible, instant, and explainable preliminary screening tool.

It empowers users to:
1.  **Capture** high-quality eye images using a smart, guided camera interface.
2.  **Analyze** the image for signs of common eye diseases.
3.  **Understand** the results through AI-generated explanations in their native language.

---

## 🚀 Key Features

### 📸 Smart Scanning System
- **Auto-Capture:** Detects the eye region and automatically captures when focus and alignment are perfect.
- **Quality Checks:** Real-time lighting and blur detection ensures only usable images are processed.
- **Adaptive Zoom:** Automatic 2x-4x zoom to capture detailed macro shots of the eye.

### 🧠 Advanced Analysis
- **Disease Detection:** Identifies potential indicators of Cataracts, Conjunctivitis, and more.
- **Explainable AI:** Doesn't just give a label; provides a text explanation of *why* the AI made that prediction.
- **Multi-confirmatory:** Uses a confidence scoring system to reduce false positives.

### 🌐 Universal Accessibility
- **Multi-Language Support:** Full translation of UI and AI reports (English, Bengali, Spanish, etc.).
- **Offline-First Architecture:** Works without internet. Scans are saved locally and synced when connection is restored.
- **Text-to-Speech:** Reads reports aloud for visually impaired users.

### 📊 Comprehensive History
- **Medical Records:** Securely stores past scans and reports.
- **PDF Reports:** Generates professional-grade medical reports for sharing with doctors.

---

## 🛠️ Technical Architecture

This project is built with **Clean Architecture** principles to ensure scalability, testability, and maintainability.

### **Frontend (Mobile App)**
- **Framework:** [Flutter](https://flutter.dev) (Dart) - Cross-platform performance.
- **State Management:** [Riverpod](https://riverpod.dev) - Robust, compile-time safe state handling.
- **Hardware Integration:** `camera`, `sensors_plus` for device-level interactions.
- **Local Storage:** `Isar` / `Hive` for offline caching.

### **Backend & Infrastructure**
- **API Engine:** [FastAPI](https://fastapi.tiangolo.com) (Python) - High-performance async API.
- **Database & Auth:** [Supabase](https://supabase.com) - Real-time database, Storage, and Authentication.
- **CI/CD:** GitHub Actions for automated building, testing, and release generation.

### **AI Pipeline**
- **Client-Side:** ROI (Region of Interest) cropping and image quality assessment.
- **Server-Side:** Integration with Vision Language Models for inference and natural language explanation generation.

---

## 📥 Download & Installation

| Platform | Latest Version | Link |
|:---------|:---------------|:-----|
| **Android App** | ✅ **v1.4.7** | [📱 **Download APK**](https://github.com/Muhammad-Raisul-Maharub/EYEVLM/releases/latest) |
| **Web App** | ✅ **Live** | [🌐 **Launch Web App**](https://eyevlm-app.vercel.app) |

---

## ⚠️ Medical Disclaimer
**EyeVLM is a screening and educational tool, NOT a replacement for professional medical diagnosis.**
The results provided by this application are early indications based on AI analysis. Always consult a certified ophthalmologist for clinical diagnosis and treatment planning.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

© 2024-2026 EyeVLM Team. Built with ❤️ for better vision.
