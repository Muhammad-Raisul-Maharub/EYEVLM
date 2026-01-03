# Setup and Testing Guide for EyeVLM

This document provides step-by-step instructions to set up, run, and test the EyeVLM application on your local machine.

## 1. Prerequisites

Before starting, ensure you have the following installed:
- **Flutter SDK** (Version 3.0.0 or higher)
- **Python** (Version 3.10 or higher) for the backend
- **Android Studio** (for Android Emulator) or **Xcode** (for iOS Simulator, Mac only)
- **Visual Studio Code** (Recommended IDE)

## 2. Backend Setup (Local)

The backend is built with FastAPI and handles AI image analysis.

1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Create a virtual environment:
    ```bash
    python -m venv .venv
    ```
3.  Activate the virtual environment:
    - **Windows**: `.\.venv\Scripts\activate`
    - **Mac/Linux**: `source .venv/bin/activate`
4.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
5.  Run the server:
    ```bash
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
    ```
    *The server will start at `http://0.0.0.0:8000`.*

## 3. App Setup (Flutter)

1.  Navigate to the project root:
    ```bash
    cd "c:\Users\rmaha\OneDrive\Desktop\Projects\EyeVLM Flutter APP"
    ```
2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```
    *(Note: If you see warnings about dependencies, don't worry. The build has been verified to work.)*
3.  Add Assets:
    - Place your logo at `assets/images/logo.png`.
    - (Optional) Place a Lottie animation at `assets/animations/empty_state.json`.

## 4. Running the App

### Option A: Run on Web (Chrome)
```bash
flutter run -d chrome
```

### Option B: Run on Android Emulator
1.  Open Android Studio and launch a Virtual Device (AVD).
2.  Run the command:
    ```bash
    flutter run
    ```

## 5. Manual Testing Checklist

| Feature | Action to Test | Expected Outcome |
| :--- | :--- | :--- |
| **Login** | Enter valid email/password and tap Login | Navigates to Home Screen with "Welcome Back" message. |
| **Cropping** | Tap "Start Scan" -> Select Image | Crop UI appears. Image is forced to square. |
| **Analysis** | Submit the cropped image | "Analyzing..." animation plays, then Result Screen appears. |
| **Result** | View Result Screen | Shows "Healthy" or 'Cataract' with confidence %. |
| **PDF** | Tap PDF icon on Result Screen | PDF report is generated/previewed. |
| **History** | Go to History tab | List of past scans with thumbnails. |
| **Details** | Tap a History item | **Popup Dialog** opens with "Share" and "Delete" options. |
| **Share** | Tap "Share Report" in Dialog | System share sheet opens. |
| **Profile** | Go to Profile tab | Shows "Designed & Developed by Raisul Maharub". |
| **Logout** | Tap "Log Out" on Profile | Returns to Login Screen. |

## 6. Troubleshooting

*   **Result Screen Error**: If the result screen shows an error, ensure your backend server is running (`uvicorn ...`).
*   **Image Upload Fails**: Check `lib/core/constants/app_constants.dart`. If running on Android Emulator, `baseUrl` should be `http://10.0.2.2:8000`. If on Web/Device, use your PC's local IP (e.g., `http://192.168.1.5:8000`).
*   **Dependency Error**: If `flutter pub get` fails on `phosphor_flutter`, run `flutter pub upgrade` or check that you are using the latest code which uses Material Icons.
