# EyeVLM - Early Disease Detection System

**EyeVLM** is a cross-platform (Android, iOS, Web) Flutter application designed to assist in the early detection of eye diseases, specifically cataracts, using advanced AI-powered image analysis. It combines a user-friendly "Medical Soft UI" with a robust backend to provide instant, secure screening results.

## 📱 Key Features

### 1. **Authentication & User Profiles**
*   **Secure Login/Signup**: Powered by Supabase Authentication.
*   **Modern Login UI**: Features a curved medical-themed header, animations, and clean input fields.
*   **Profile Management**: "My Profile" screen with settings, ethical guidelines access, developer credits, and logout functionality.

### 2. **Core Dashboard (Home Screen)**
*   **"Start Scan" Hero Card**: A prominent, animated call-to-action for immediate screening.
*   **Health Tips**: A horizontal carousel providing essential eye care advice (e.g., "20-20-20 Rule", "Stay Hydrated").
*   **Personalization**: Displays user greeting and notification badge.

### 3. **Smart Submission System**
*   **Auto-Cropping**: Integrated `ImageCropper` forces a square aspect ratio to ensure the eye is perfectly centered for the AI model.
*   **Image Alignment**: Guided UI with an overlay to help users position their eye correctly.
*   **Scanning Animation**: A visual "Scanning..." effect during AI processing enhances user confidence.

### 4. **AI Analysis & Results**
*   **Instant Feedback**: Analyzes uploaded images to detect "Cataract" or "Healthy" conditions.
*   **Confidence Score**: Displays the AI's confidence level (e.g., "98% Confidence").
*   **Detailed Results Screen**: Shows the cropped image, diagnosis, and allows generating a PDF report.

### 5. **Medical History & Reporting**
*   **Visual History**: List of past scans with thumbnail previews and status chips (Healthy/Cataract).
*   **Medical Report Card**: Tapping a history item opens a detailed popup dialog with:
    *   Full analysis summary.
    *   Date and symptoms.
    *   **Share Option**: Easily share the report via standard system share sheet.
    *   **Robust Delete**: Securely deletes both the database record and the stored image file.

---

## 🛠 Tech Stack

### **Frontend (Mobile & Web)**
*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **State Management**: `flutter_riverpod`
*   **Navigation**: `go_router`
*   **Design System**: "Medical Soft UI" (Teal `#009688`, Poppins/Inter fonts, Material Icons).
*   **Key Packages**:
    *   `supabase_flutter`: Authentication & Database.
    *   `image_cropper`: For precise image preparation.
    *   `flutter_animate`: For seamless UI transitions.
    *   `share_plus`: For sharing medical reports.
    *   `printing` / `pdf`: For generating PDF reports.

### **Backend**
*   **Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Python)
*   **Database**: Supabase (PostgreSQL)
*   **Storage**: Supabase Storage (for eye images).
*   **Deployment**: Railway (Backend services).

---

## 🚀 How It Works

1.  **User Logs In**: Authenticates securely via email/password.
2.  **Start Scan**: Taps the "Start Scan" button on the dashboard.
3.  **Capture & Crop**: Takes a photo or selects from the gallery. The app enforces a crop to focus strictly on the eye.
4.  **AI Analysis**: The image is uploaded to the backend, processed by the AI model, and a diagnosis is returned.
5.  **View Result**: The user sees the simple result ("Healthy" or "Cataract") with a confidence score.
6.  **History**: The scan is saved to the medical history for future reference, sharing, or deletion.

---

## 🏗 Setup & Running

### Prerequisites
*   Flutter SDK (3.x)
*   Python 3.10+ (for backend local dev)

### 1. Run Backend (Local)
```bash
cd backend
python -m venv .venv
# Activate venv (Windows: .venv\Scripts\activate, Mac/Linux: source .venv/bin/activate)
pip install -r requirements.txt
uvicorn main:app --reload
```

### 2. Run App (Flutter)
```bash
flutter pub get
flutter run
```

### 3. Assets
Ensure `assets/images/logo.png` exists for branding.

---

**Designed & Developed by Raisul Maharub**
*Version 1.0.0*
