# Age & Gender Model Evaluation

Evaluation script for the quantized Age & Gender recognition model on the Mozilla Common Voice dataset.

---

## Overview

This script evaluates a **wav2vec2-based Age & Gender model** (quantized to INT8) to measure its accuracy in:
- **Age prediction**: Estimating speaker age in years
- **Gender classification**: Classifying speaker gender (female, male, child)

The model is based on the research paper:
> Burkhardt, F., Arias, J. P. A., Erzigkeit, M., Duran, J. A., Rodrigo, D. H., Karas, V., & Müller, S. (2023). *wav2vec 2.0 for Voice Type, Age, and Gender Recognition.*

---

## Dataset

**Mozilla Common Voice (German)**
- **Source**: Common Voice Corpus (latest version)
- **Language**: German (de)
- **Test Split**: 1,110 samples
- **Audio Format**: MP3, 16kHz sample rate
- **Metadata**: Includes age and gender labels for each speaker

### Download Dataset

1. **Download Common Voice Corpus (German)**:
   - Visit: https://commonvoice.mozilla.org/datasets
   - Select language: **German (Deutsch)**
   - Download the latest version (e.g., `cv-corpus-XX.X-YYYY-MM-DD-de.tar.gz`)

2. **Extract the dataset**:
   ```bash
   tar -xzf cv-corpus-*.tar.gz
   ```

3. **Locate audio files**:
   - Audio clips path: `cv-corpus-*/de/clips/`
   - This is the directory you'll pass to `--audio-dir`
   - Example: `cv-corpus-22.0-2025-06-20/de/clips/`

The test split CSV (`mozillacommonvoice.test.csv`) was provided by the original model authors and represents the same evaluation set used in their paper.

---

## Model Details

**Architecture**: wav2vec2-large-robust (6 layers)
- **Input**: 16kHz mono audio (variable length)
- **Outputs**:
  - Age: Continuous value (0-100 years)
  - Gender: 3 classes (female, male, child)
- **Quantization**: INT8 (from FP32)
- **Framework**: ONNX Runtime

---

## Requirements

### Prerequisites

1. **Download the dataset** (see [Dataset](#dataset) section above)
2. **Python 3.11+**
3. **Test CSV file**: `mozillacommonvoice.test.csv` (provided with evaluation script)

### Installation

1. **Create Python environment** (Python 3.11+):
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
python evaluation_age_gender.py --audio-dir /path/to/cv-corpus-*/de/clips
```

**Example with full path (Windows)**:
```bash
python evaluation_age_gender.py --audio-dir "D:\cv-corpus-22.0-2025-06-20\de\clips"
```

**Example with full path (Linux/macOS)**:
```bash
python evaluation_age_gender.py --audio-dir "/home/user/datasets/cv-corpus-22.0-2025-06-20/de/clips"
```

> **Note**: Replace `cv-corpus-*` with your actual downloaded version number.

### Development Mode (Quick Test)

```bash
python evaluation_age_gender.py \
    --audio-dir /path/to/clips \
    --dev \
    --dev-samples 50
```

### Command-Line Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--audio-dir` | Yes | - | Path to directory containing audio files |
| `--model` | No | `age_and_gender_model_quantized.onnx` | Path to ONNX model |
| `--csv` | No | `mozillacommonvoice.test.csv` | Path to test CSV file |
| `--output` | No | `./evaluation_results` | Output directory |
| `--dev` | No | False | Run in development mode |
| `--dev-samples` | No | 50 | Number of samples for dev mode |

---

## Evaluation Results

### Performance Metrics

| Metric | Paper (FP32) | This Evaluation (INT8) | Delta |
|--------|--------------|------------------------|-------|
| **Age MAE** | 8.80 years | 10.55 years | +1.75 years |
| **Gender Accuracy** | 99.2% | 96.3% | -2.9% |

### Age Prediction
- **Mean Absolute Error (MAE)**: 10.55 years
- **Samples**: 1,110
- The quantized model shows a small degradation of 1.75 years compared to the original FP32 model

### Gender Classification

**Overall Accuracy**: 96.3%

**Per-Class Performance**:

| Class | Precision | Recall | F1-Score | Support |
|-------|-----------|--------|----------|---------|
| **Female** | 99.1% | 94.4% | 96.7% | 602 |
| **Male** | 93.6% | 98.6% | 96.1% | 508 |
| **Child** | 0.0% | 0.0% | 0.0% | 0 |

**Confusion Matrix**:
```
              Predicted
              Female  Male  Child
True  Female    568    34     0
      Male        5   501     2
      Child       0     0     0
```

**Notes**:
- No "child" samples present in test set
- Model shows high precision for female classification (99.1%)
- Model shows high recall for male classification (98.6%)
- Minor confusion between male/female (39 misclassifications out of 1,110)

## Performance Notes

### Quantization Impact

The INT8 quantized model shows acceptable performance degradation:
- **Age prediction**: +1.75 years MAE (19.9% increase)
- **Gender classification**: -2.9% accuracy (small decrease)

### Trade-offs
-  **Model size**: ~93% reduction (FP32 → INT8)
-  **Inference speed**: Faster on mobile devices
-  **Accuracy**: Slight degradation in both tasks
-  **Overall**: Good balance for mobile deployment