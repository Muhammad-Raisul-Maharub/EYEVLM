# 👁️ EyeVLM - AI-Powered Eye Disease Detection

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.95%2B-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20DB-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Render](https://img.shields.io/badge/Render-Deployed-46E3B7?logo=render&logoColor=white)](https://render.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Thesis Project:** Computer-Aided Diagnosis system for early detection of ocular diseases using Vision-Language Models.

EyeVLM is a cross-platform (Mobile & Web) application designed to assist in the early detection of eye diseases using advanced AI. It captures eye images, processes them via a secure backend, and provides instant analysis with confidence scores.

---

## 📥 **Try It Now**

| Platform | Status | Action |
| :--- | :--- | :--- |
| **Android App** | ✅ **v1.0 Stable** | [![Download APK](https://img.shields.io/badge/Download-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://drive.google.com/file/d/1hwTOH1jhE8sWYBv5xYmM31JhQx5eoaYQ/view?usp=sharing) |
| **Web App** | ✅ **Live** | [![Launch Web App](https://img.shields.io/badge/Launch-Web_App-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://eyevlm-web.vercel.app) |
| **Backend API** | ✅ **Live** | [View API Status](https://eyevlm-backend.onrender.com/docs) |

---

## 📱 **Screenshots**

| Home Screen | Analysis Result | Dark Mode |
|:---:|:---:|:---:|
| <img src="assets/screenshots/home.png" width="200" alt="Home Screen" /> | <img src="assets/screenshots/result.png" width="200" alt="Result" /> | <img src="assets/screenshots/dark.png" width="200" alt="Dark Mode" /> |

*(Note: Add screenshots to your `assets/screenshots/` folder to display them here)*

---

## 🚀 **Key Features**

* **🖼️ High-Fidelity Capture:** Preserves full-resolution images for accurate clinical annotation and future model training.
* **📷 Dual Capture Mode:** Support for both Camera and Gallery uploads with auto-cropping.
* **📊 Comprehensive Diagnosis:** Detects **Cataract**, **Keratitis**, **Uveitis**, **Pterygium**, and **Conjunctivitis**.
* **📂 Cloud History:** Securely stores scan history with robust, instant deletion (Optimistic UI).
* **📄 Medical Reports:** "Download PDF" feature to generate professional reports for doctors.
* **🌙 Adaptive UI:** Beautiful, instantly switching Dark/Light themes.
* **🔒 Enterprise Security:** Built with **Supabase** Authentication & Storage (RLS enabled).

---

## 🛠 **Tech Stack & Architecture**

### **Frontend (Mobile & Web)**
* **Framework:** Flutter (Dart)
* **State Management:** Riverpod
* **Navigation:** GoRouter
* **Animations:** Flutter Animate

### **Backend (Server)**
* **Framework:** Python FastAPI (Uvicorn)
* **Deployment:** Render (Cloud Hosting)
* **Storage:** Supabase Buckets

### **AI Core**
* **Model:** Custom PyTorch Vision Model
* **Inference:** Real-time processing via REST API

---

## 📦 **Installation & Setup (Local Dev)**

### **Prerequisites**
* Flutter SDK (3.0+)
* Python 3.8+
* Supabase Account

### **1. Clone the Repository**
```bash
git clone https://github.com/Muhammad-Raisul-Maharub/EYEVLM.git
cd EYEVLM
```

### **2. Backend Setup**
Navigate to the backend directory and install dependencies:
```bash
cd backend
pip install -r requirements.txt
```
Run the backend server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Note: Update `lib/core/constants.dart` with your machine's IP address if testing on a physical device.*

### **3. Frontend Setup**
Install Flutter dependencies:
```bash
flutter pub get
```
Run the app:
```bash
# For Web
flutter run -d chrome

# For Mobile
flutter run
```

---

## ⚠️ **Medical Disclaimer**

**EyeVLM is an early indication tool, NOT a replacement for professional medical diagnosis.** This software is intended for research and educational purposes only. Always consult a certified ophthalmologist for clinical diagnosis and treatment.

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
