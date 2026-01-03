# EyeVLM - AI-Powered Eye Disease Detection

EyeVLM is a cross-platform (Mobile & Web) application designed to assist in the early detection of eye diseases using advanced AI. It captures eye images, processes them via a secure backend, and provides instant analysis with confidence scores.

## 🚀 Key Features

*   **⚡ Instant Analysis**: Sub-2s processing time with smart image compression (1024px, 80% Q).
*   **📷 Dual Capture Mode**: Support for both Camera and Gallery uploads with auto-cropping.
*   **📊 Comprehensive Results**: Detects **Cataract**, **Keratitis**, **Uveitis**, **Pterygium**, and **Conjunctivitis**.
*   **📂 Cloud History**: Securely stores scan history with robust, instant deletion (Optimistic UI).
*   **📄 Medical Reports**: "Download PDF" feature to generate professional reports for doctors.
*   **🌙 Dark Mode**: Beautiful, instantly switching UI themes.
*   **🔒 Secure**: Built with **Supabase** Authentication & Storage (RLS enabled).

## 🛠 Tech Stack

*   **Frontend**: Flutter (Riverpod, GoRouter, Google Fonts, Flutter Animate)
*   **Backend**: Python FastAPI (Uvicorn)
*   **Database & Auth**: Supabase
*   **AI/ML**: Custom PyTorch Model (Integrated via Backend API)

## 📦 Installation & Setup

### Prerequisites
*   Flutter SDK (3.0+)
*   Python 3.8+
*   Supabase Account

### 1. Clone the Repository
```bash
git clone https://github.com/Muhammad-Raisul-Maharub/EYEVLM.git
cd EYEVLM
```

### 2. Backend Setup
Navigate to the backend directory and install dependencies:
```bash
cd backend
pip install fastapi uvicorn supabase python-multipart
```
Run the backend server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Note: Update `lib/core/constants/app_constants.dart` with your machine's IP address if running on a physical device.*

### 3. Frontend Setup
Install Flutter dependencies:
```bash
flutter pub get
```
Run the app (Web):
```bash
flutter run -d chrome
```
Run the app (Mobile):
```bash
flutter run
```

## 📱 Usage Guide

1.  **Sign Up/Login**: Create an account to securely save your history.
2.  **Home**: Tap "Start New Scan".
3.  **Capture**: Take a photo or pick from gallery. Crop to center the eye.
4.  **Analyze**: Tap "Analyze Scan". Results appear instantly.
5.  **History**: View past scans, download PDF reports, or swipe to delete.

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## 📄 License
This project is licensed under the MIT License.

## ⚠️ Disclaimer
**EyeVLM is an early indication tool, NOT a replacement for professional medical diagnosis.** Always consult a certified ophthalmologist.
