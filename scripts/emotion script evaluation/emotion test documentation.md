# Emotion Recognition Model Evaluation

Evaluation script for the quantized Emotion Recognition model on the SSI Speech Emotion Recognition dataset.

---

## Overview

This script evaluates a **wav2vec2-based Emotion Recognition model** (quantized to INT8) to measure its accuracy in classifying 8 different emotions from speech audio:
- Angry
- Calm
- Disgust
- Fearful
- Happy
- Neutral
- Sad
- Surprised

---

## Dataset

**SSI Speech Emotion Recognition Dataset**
- **Source**: Hugging Face Hub (`stapesai/ssi-speech-emotion-recognition`)
- **Split Used**: Validation split (1,999 samples)
- **Audio Format**: WAV files, variable sample rates (resampled to 16kHz)
- **Emotions**: 8 classes (angry, calm, disgust, fearful, happy, neutral, sad, surprised)
- **Language**: English

### Dataset Download

The dataset is automatically downloaded from Hugging Face Hub when running the script.

**Important**: The dataset is quite large. By default, it will be downloaded to:
- **Linux/macOS**: `~/.cache/huggingface/datasets/`
- **Windows**: `C:\Users\<username>\.cache\huggingface\datasets\`

### Custom Download Location

To change the download location, set the `HF_HOME` environment variable:

**Linux/macOS**:
```bash
export HF_HOME=/path/to/your/custom/location
python evaluation_emotion.py
```

**Windows (PowerShell)**:
```powershell
$env:HF_HOME="D:\my_datasets\huggingface"
python evaluation_emotion.py
```

**Windows (CMD)**:
```cmd
set HF_HOME=D:\my_datasets\huggingface
python evaluation_emotion.py
```

**Permanent configuration**:
```bash
# Add to ~/.bashrc (Linux) or ~/.zshrc (macOS)
export HF_HOME=/path/to/your/custom/location

# Or create/edit ~/.bash_profile
echo 'export HF_HOME=/path/to/datasets' >> ~/.bash_profile
```

---

## Model Details

**Architecture**: wav2vec2-large-robust
- **Input**: 16kHz mono audio (variable length)
- **Output**: 8 emotion classes (softmax probabilities)
- **Quantization**: INT8 (from FP32)
- **Framework**: ONNX Runtime

---

## Requirements

### Prerequisites

1. **Python 3.11+**
2. **Internet connection** (for automatic dataset download)

### Installation

1. **Create Python environment**:
```bash
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate  # Windows
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

---

## Usage

### Basic Usage

```bash
python evaluation_emotion.py
```

The script will:
1. Load the ONNX model
2. Automatically download the SSI dataset (if not cached)
3. Run evaluation on all 1,999 samples
4. Save results and generate visualizations


```bash
python evaluation_emotion.py
```

### Configuration

Edit the `main()` function in the script to configure:

```python
def main():
    DEV_MODE = False  # Set True for quick testing
    DEV_SAMPLES = 50  # Number of samples in dev mode
    
    MODEL_PATH = "emotion_recognition_quantized.onnx"
    OUTPUT_DIR = "./evaluation_results"
```

---

## Evaluation Results

### Performance Metrics

| Metric | Value |
|--------|-------|
| **Overall Accuracy** | 82.14% |
| **Precision (Weighted)** | 82.76% |
| **Recall (Weighted)** | 82.14% |
| **F1-Score (Weighted)** | 82.08% |
| **Precision (Macro)** | 83.70% |
| **Recall (Macro)** | 84.21% |
| **F1-Score (Macro)** | 83.64% |

### Per-Class Performance

| Emotion | Precision | Recall | F1-Score | Support |
|---------|-----------|--------|----------|---------|
| **Angry** | 83.4% | 93.5% | 88.1% | 306 |
| **Calm** | 82.1% | 91.4% | 86.5% | 35 |
| **Disgust** | 71.4% | 85.4% | 77.7% | 321 |
| **Fearful** | 83.9% | 70.2% | 76.4% | 305 |
| **Happy** | 89.1% | 73.9% | 80.8% | 322 |
| **Neutral** | 88.4% | 85.4% | 86.9% | 287 |
| **Sad** | 76.5% | 79.2% | 77.8% | 308 |
| **Surprised** | 94.8% | 94.8% | 94.8% | 115 |

### Key Observations

 **Best Performance**:
- **Surprised**: 94.8% F1-score (highest performance)
- **Angry**: 88.1% F1-score (high recall at 93.5%)
- **Neutral**: 86.9% F1-score (balanced performance)

 **Challenging Emotions**:
- **Fearful**: 76.4% F1-score (lowest recall at 70.2%)
- **Disgust**: 77.7% F1-score (lowest precision at 71.4%)
- **Happy**: 80.8% F1-score (moderate recall at 73.9%)


## Output Files

After evaluation, the following files are generated in `./evaluation_results/`:

1. **results.json**: Complete evaluation metrics in JSON format
2. **detailed_results.csv**: Per-sample predictions with emotion labels
3. **confusion_matrix.png**: 8x8 confusion matrix heatmap
4. **per_class_metrics.png**: Bar chart comparing precision, recall, and F1-score for each emotion

---
## Performance Notes

### Quantization Impact

The INT8 quantized model maintains competitive performance:
- ✅ **Overall accuracy**: 82.14% (good for 8-class problem)
- ✅ **Model size**: ~93% reduction (FP32 → INT8)
- ✅ **Inference speed**: Suitable for real-time processing
- ⚠️ **Challenging emotions**: Fear and disgust show lower performance

### Model Strengths

- High accuracy on distinct emotions (surprised, angry, neutral)
- Balanced performance across most emotion classes
- Fast inference suitable for mobile deployment

### Model Limitations

- Confusion between similar valence emotions (fear/sad, disgust/angry)
- Lower performance on less represented classes
- Acoustic similarity between certain emotion pairs

---

## Troubleshooting

### Common Issues

**Issue**: "Out of memory during dataset download"
- **Solution**: Ensure you have at least 5 GB of free disk space
- Set `HF_HOME` to a drive with more space

