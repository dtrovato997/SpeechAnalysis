# Whisper Language Identification Model Evaluation

Evaluation script for the quantized Whisper-tiny language identification model on the FLEURS dataset.

---

## Overview

This script evaluates a **Whisper-tiny language identification model** (quantized to INT8) to measure its accuracy in identifying languages from speech audio across:
- **82 high-resource languages** (languages with >1000h training data)
- **102 total languages** (including zero-shot languages)

The model is based on OpenAI's Whisper architecture:
> Radford, A., Kim, J. W., Xu, T., Brockman, G., McLeavey, C., & Sutskever, I. (2022). *Robust Speech Recognition via Large-Scale Weak Supervision.*

---

## Dataset

**FLEURS (Few-shot Learning Evaluation of Universal Representations of Speech)**
- **Source**: Hugging Face Hub (`google/fleurs`)
- **Test Split**: 63,344 samples across 82 languages
- **Audio Format**: Variable length, automatically resampled to 16kHz
- **Coverage**: 102 languages total (82 overlap with Whisper training data)

### Dataset Download

The dataset is automatically downloaded from Hugging Face Hub when running the script.

**Important**: The FLEURS dataset is quite large. By default, it will be downloaded to:
- **Linux/macOS**: `~/.cache/huggingface/datasets/`
- **Windows**: `C:\Users\<username>\.cache\huggingface\datasets\`

### Custom Download Location

To change the download location, set the `HF_HOME` environment variable:

**Linux/macOS**:
```bash
export HF_HOME=/path/to/your/custom/location
python evaluation_whisper.py
```

**Windows (PowerShell)**:
```powershell
$env:HF_HOME="D:\my_datasets\huggingface"
python evaluation_whisper.py
```

**Windows (CMD)**:
```cmd
set HF_HOME=D:\my_datasets\huggingface
python evaluation_whisper.py
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

**Architecture**: Whisper-tiny (two-stage pipeline)
- **Preprocessor**: Converts audio to mel-spectrogram features
- **Detector**: Language classification head
- **Input**: 16kHz mono audio (up to 30 seconds)
- **Output**: 99 language classes (model trained on 99 languages)
- **Quantization**: INT8 (from FP32)
- **Framework**: ONNX Runtime

**Model Files Required**:
- `whisper_preprocessor.onnx`: Audio feature extraction
- `whisper_lang_detector.onnx`: Language classification

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

### Basic Usage (82 Languages)

```bash
python evaluation_whisper.py
```

The script will:
1. Load both ONNX models (preprocessor + detector)
2. Automatically download FLEURS dataset (if not cached)
3. Evaluate on 82 high-resource languages
4. Save results and generate visualizations

### Interactive Controls

During evaluation, you can use keyboard controls:
- **'p' + ENTER**: Pause evaluation
- **'r' + ENTER**: Resume evaluation
- **'q' + ENTER**: Quit and save progress

---

## Evaluation Results

### 82 High-Resource Languages

| Metric | Value |
|--------|-------|
| **Overall Accuracy** | 55.97% |
| **Samples Evaluated** | 63,344 |
| **Languages** | 82 |
| **Precision (Macro)** | 58.06% |
| **Recall (Macro)** | 55.98% |
| **F1-Score (Macro)** | 49.67% |

### Performance by Language Category

**Top Performing Languages** (>90% accuracy):
- **Mandarin Chinese**: 87.9% precision, 100.0% recall → 93.6% F1
- **Catalan**: 99.4% precision, 53.4% recall → 69.5% F1
- **Danish**: 97.8% precision, 84.7% recall → 90.8% F1
- **Filipino**: 89.7% precision, 98.7% recall → 94.0% F1
- **Vietnamese**: 85.9% precision, 99.5% recall → 92.2% F1
- **Japanese**: 79.7% precision, 99.8% recall → 88.7% F1

**Good Performance** (70-90% F1):
- Finnish, Hungarian, Swedish, Czech, Greek, Hebrew
- Dutch, Italian, Korean, Malay, Norwegian, Polish

**Challenging Languages** (<50% F1):
- **Gujarati**: 89.0% precision, 14.6% recall → 25.1% F1
- **Pashto**: 89.4% precision, 33.0% recall → 48.2% F1
- **Welsh**: 98.2% precision, 48.5% recall → 64.9% F1
- **Georgian**: 96.7% precision, 51.5% recall → 67.2% F1

**Zero Performance** (0% F1-score):
- Belarusian, Hausa, Javanese, Lao, Lingala, Luxembourgish
- Macedonian, Maltese, Sindhi, Tajik, Uzbek

### Key Observations

✅ **Strengths**:
- Excellent performance on major languages (English, Chinese, Spanish, French)
- High precision across most languages
- Strong recall for widely-used languages

⚠️ **Weaknesses**:
- Significant confusion between similar languages (e.g., Hindi/Urdu, Croatian/Bosnian/Serbian)
- Low recall for low-resource languages
- Some languages never predicted (11 languages with 0% recall)

## Comparison with Paper Results

| Metric | Paper (Whisper Large v2, FP32) | This Eval (Whisper Tiny, INT8) | Delta |
|--------|--------------------------------|--------------------------------|-------|
| **82 Languages** | 80.3% | 55.97% | -24.33% |
| **Model Size** | ~3 GB (FP32) | ~40 MB (INT8) | -98.7% |

**Note**: The significant accuracy drop is due to:
1. Model size: Tiny (39M params) vs Large (1.5B params) = 38x smaller
2. Quantization: INT8 vs FP32
3. Trade-off: 98.7% size reduction for mobile deployment

---

## Output Files

After evaluation, the following files are generated in `./evaluation_results/`:

1. **results_82_languages.json**: Complete evaluation metrics
2. **results_82_languages_detailed.csv**: Per-sample predictions with confidence scores
3. **confusion_matrix_82_langs.png**: Top 20 languages confusion matrix
4. **confusion_matrix_82_complete_groupX.png**: Complete confusion matrices (split into groups of 25 languages)

If 102-language evaluation is enabled:
5. **results_102_languages.json**: Full dataset metrics
6. **confusion_matrix_102_langs.png**: 102-language confusion matrix
7. **comparison_report.txt**: Comparison between 82-lang and 102-lang evaluations

---

## Performance Notes

### Quantization Impact

The INT8 Whisper-tiny model shows significant performance trade-offs:
- ⚠️ **Accuracy**: 55.97% (vs 80.3% in paper with Whisper Large)
- ✅ **Model size**: ~40 MB (98.7% reduction from FP32 Large)
- ✅ **Inference speed**: Suitable for mobile devices
- ✅ **Memory footprint**: Minimal RAM usage

### Model Limitations

- **Low-resource languages**: Poor performance or zero predictions
- **Similar languages**: High confusion between related languages
- **Size/accuracy trade-off**: Tiny model sacrifices accuracy for size
- **Quantization degradation**: INT8 reduces precision

### Recommended Use Cases

✅ **Good for**:
- Mobile applications with storage constraints
- Real-time language detection for major languages
- Privacy-sensitive applications (on-device processing)

⚠️ **Not recommended for**:
- High-accuracy requirements (>80%)
- Rare or low-resource languages
- Critical applications requiring near-perfect accuracy
