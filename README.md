# Speech Analysis App

A simple mobile application for analyzing speech audio to predict **age**, **gender**, and **nationality** using AI deep learning models. The app consists of a Python FastAPI backend for AI inference and a Flutter android app.

## Features

### Mobile App (Flutter)
- **Record Audio**: Record speech directly within the app (30-second limit)
- **Upload Audio**: Upload existing audio files (MP3, WAV, M4A)
- **Analysis History**: Browse and manage past analyses
- **Audio Playback**: Built-in audio player for recorded/uploaded files
- **Offline Storage**: Local SQLite database for analysis history

### Backend (Python FastAPI)
- **Age Prediction**: Regression model for age estimation
- **Gender Classification**: Multi-class classification (Male/Female/Child)
- **Language/Nationality Detection**: 256 language identification using Facebook's MMS-LID model

##  Architecture

```
┌─────────────────┐    HTTP/REST API    ┌─────────────────┐
│   Flutter App   │z◄──────────────────►│  Python Backend │
│                 |                     │                 │
│ • Record Audio  │                     │ • AI Models     │
│ • Upload Files  │                     │ • Audio Process │
│ • View Results  │                     │ • FastAPI       │
│ • SQLite DB     │                     │                 |
└─────────────────┘                     └─────────────────┘
```


### Prerequisites

#### For Backend
- Python 3.9 or higher
- pip package manager
- FFmpeg (for audio processing)
- At least 4GB RAM (for AI models)

#### For Flutter App
- Flutter SDK 3.7.2 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Android/iOS device or emulator

#### System Requirements
- **Mobile**: Android 7.0+ (API 24+) or iOS 12.0+

### Installation

## Backend Setup

### 1. Navigate to Backend Directory
```bash
cd backend
```

### 2. Create Virtual Environment
```bash
# Create virtual environment
python -m venv speech_env

# Activate virtual environment
# On Windows:
speech_env\Scripts\activate
# On macOS/Linux:
source speech_env/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Install FFmpeg
**Windows:**
- Download FFmpeg from https://ffmpeg.org/download.html
- Add to system PATH


### 5. Run Backend Server
```bash
# Development server
python main.py

# Or with uvicorn directly
uvicorn main:app --host 0.0.0.0 --port 7860 --reload
```

The backend will start on `http://localhost:7860`

**First Run Note**: Models will be automatically downloaded on first startup (may take 5-10 minutes)

### 6. Verify Backend
Visit `http://localhost:7860` in your browser. You should see:
```json
{
  "message": "Audio Analysis API - Age, Gender & Nationality Prediction",
  "models_loaded": {
    "age_gender": true,
    "nationality": true
  }
}
```

## Flutter App Setup

### 1. Navigate to Flutter Directory
```bash
cd flutter_app
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Configure Backend URL
Edit `lib/data/services/audio_analysis_api_service.dart`:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:7860';

// For iOS Simulator  
static const String baseUrl = 'http://localhost:7860';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.100:7860';
```

if you install the release APK, the default backend url is the following : https://dtrovato997-speechanalysisdemo.hf.space

It might be offline for cost reasons

### 4. Run Flutter App
```bash
# Check connected devices
flutter devices

# Run on connected device/emulator
flutter run

# Or specify platform
flutter run -d android
```

#### API Endpoints
- `GET /` - Health check and model status
- `POST /predict_age_and_gender` - Age and gender prediction
- `POST /predict_nationality` - Language/nationality prediction  
- `POST /predict_all` - Complete analysis

## Technologies and Models

- **Facebook MMS-LID**: Language identification model
- **Wav2Vec2**: Age and gender prediction model  
- **Flutter Team**: Cross-platform framework
- **FastAPI**: Modern Python web framework
