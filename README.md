# Speech Analysis App

An Android application writte in Flutter for analyzing speech audio to predict **age**, **gender**, **nationality**, and **emotion** using on-device AI inference with ONNX Runtime.

## Features

### Mobile App (Flutter)
- **Record Audio**: Record speech directly within the app (30-second limit)
- **Upload Audio**: Upload existing audio files (MP3, WAV, M4A)
- **On-Device Analysis**: Local inference using ONNX Runtime - no data leaves the device
- **Analysis History**: Browse and manage past analyses
- **Audio Playback**: Built-in audio player for recorded/uploaded files
- **Offline Storage**: Local SQLite database for analysis history
- **Dark/Light Themes**: Multiple theme options with accessibility support

### AI Models (Local Inference)
- **Age Prediction**: Regression model for age estimation (0-100 years)
- **Gender Classification**: Multi-class classification (Male/Female/Child)
- **Language/Nationality Detection**: 99+ language identification using Whisper
- **Emotion Recognition**: 8-emotion classification (angry, happy, sad, neutral, etc.)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                  │
├─────────────────────────────────────────────────────────┤
│  • Record/Upload Audio     • Analysis History          │
│  • Local Audio Processing • Results Visualization      │
│  • SQLite Database        • Theme Management           │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│              ONNX Runtime (On-Device)                  │
├─────────────────────────────────────────────────────────┤
│  • Age & Gender Model     • Emotion Recognition        │
│  • Whisper Language Model • Audio Preprocessing        │
│  • FFmpeg Audio Pipeline  • Real-time Inference       │
└─────────────────────────────────────────────────────────┘
```

## Model Citations

This project uses pre-trained models from Hugging Face:

### Age & Gender Recognition
**audeering/wav2vec2-large-robust-6-ft-age-gender**  
- Repository: https://huggingface.co/audeering/wav2vec2-large-robust-6-ft-age-gender
- Fine-tuned Wav2Vec2 model for age and gender prediction from speech
- License: CC-BY-4.0

### Emotion Recognition  
**Dpngtm/wav2vec2-emotion-recognition**
- Repository: https://huggingface.co/Dpngtm/wav2vec2-emotion-recognition  
- Wav2Vec2 model fine-tuned for emotion classification
- Supports 8 emotion classes: angry, calm, disgust, fearful, happy, neutral, sad, surprised

### Language Detection
**openai/whisper-tiny**
- Repository: https://huggingface.co/openai/whisper-tiny
- Lightweight Whisper model for multilingual speech recognition and language identification
- Supports 99+ languages with high accuracy
- License: MIT

## Prerequisites

### For Flutter App
- Flutter SDK 3.7.2 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Android device or emulator

### System Requirements
- **Mobile**: Android 7.0+ (API 24+) or iOS 12.0+
- **Storage**: ~500MB for models and app data
- **RAM**: 4GB+ recommended for optimal performance

## Installation

### 1. Clone Repository
```bash
git clone <repository-url>
cd speech-analysis-app
```

### 2. Navigate to Flutter Directory
```bash
cd flutter_app
```

### 3. Install Flutter Dependencies
```bash
flutter pub get
```

### 4. Download Model Assets
The ONNX models are stored using Git LFS. Ensure you have Git LFS installed:
```bash
git lfs pull
```

### 5. Run Flutter App
```bash
# Check connected devices
flutter devices

# Run on connected device/emulator
flutter run

# Or specify platform
flutter run -d android
```

## Technical Details

### Audio Processing Pipeline
1. **Input**: Record (30s max) or upload audio file (MP3, WAV, M4A)
2. **Preprocessing**: FFmpeg conversion to 16kHz mono PCM
3. **Feature Extraction**: Wav2Vec2 feature encoding
4. **Inference**: ONNX Runtime model execution
5. **Results**: Age, gender, language, and emotion predictions

### Model Performance
- **Age Prediction**: Mean Absolute Error ~6 years
- **Gender Classification**: 95%+ accuracy  
- **Language Detection**: 99+ languages supported
- **Emotion Recognition**: 8-class emotion detection

## License

This project is licensed under the MIT License. See individual model repositories for their respective licenses.

## Acknowledgments

- **Hugging Face** for providing pre-trained models
- **ONNX Runtime** for cross-platform inference
- **Flutter** team for the mobile framework
- **FFmpeg** for audio processing capabilities
