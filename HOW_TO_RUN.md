# MedSense - Project Setup and Run Guide

This project consists of two main components:
1.  **Frontend**: Flutter Mobile Application (`med_sense_application`)
2.  **Backend**: FastAPI Server (`med_sense_backend`)

---

## 🛠️ Prerequisites

Ensure you have the following installed on your system:
- **Flutter SDK** (Version 3.27.0 or higher recommended)
- **Python 3.10+**
- **Git** (optional, for cloning)
- **Android Studio** or **VS Code** (with Flutter/Dart & Python extensions)

---

## 🚀 1. Backend Setup (FastAPI)

The backend handles AI processing and additional logic for the application.

1.  Open your terminal and navigate to the backend directory:
    ```bash
    cd med_sense_backend
    ```
2.  (Optional but recommended) Create a virtual environment:
    ```bash
    python -m venv venv
    # Activate on Windows:
    .\venv\Scripts\activate
    # Activate on Mac/Linux:
    source venv/bin/activate
    ```
3.  Install the required dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4.  **Environment Variables**: Ensure the `enviroment.env` file is present in the `med_sense_backend` folder. This file contains the Supabase URL and Keys necessary for connection.
5.  Start the server:
    ```bash
    uvicorn app.main:app --reload
    ```
    The backend should now be running at `http://127.0.0.1:8000`.

---

## 📱 2. Frontend Setup (Flutter)

1.  Open a new terminal window and navigate to the application directory:
    ```bash
    cd med_sense_application
    ```
2.  Download the necessary Flutter packages:
    ```bash
    flutter pub get
    ```
3.  Ensure you have an emulator running (Android or iOS) or a physical device connected.
4.  Run the application:
    ```bash
    flutter run
    ```

---

## 🗄️ 3. Database (Supabase)

The project uses **Supabase** as the primary database. 
- The application is already configured to connect to the live development database via the keys provided in the code and environment files.
- If you wish to inspect the database structure, the SQL schema is provided in: `med_sense_application/SupabaseTableSchema`.

---

## 📁 Submission Folder Structure

For a complete run, ensure the following folders are included in your submission:
- `med_sense_application/` - The mobile app source code.
- `med_sense_backend/` - The Python API server.
- `README.md` - General project overview.
- `HOW_TO_RUN.md` - This guide.

---
**Note:** Please ensure your internet connection is active as the application connects to a remote Supabase instance.
