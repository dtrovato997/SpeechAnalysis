import os
import json
import numpy as np
import pandas as pd
import torch
import onnxruntime as ort
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from tqdm import tqdm
from sklearn.metrics import (
    accuracy_score, 
    classification_report, 
    confusion_matrix,
    precision_recall_fscore_support
)
import matplotlib.pyplot as plt
import seaborn as sns
import pickle
import time
from datetime import datetime
import librosa
import warnings
from datasets import load_dataset, Dataset
warnings.filterwarnings('ignore')


class EmotionRecognitionEvaluator:
    
    EMOTION_LABELS = {
        0: 'angry',
        1: 'calm', 
        2: 'disgust',
        3: 'fearful',
        4: 'happy',
        5: 'neutral',
        6: 'sad',
        7: 'surprised'
    }
    
    SSI_TO_MODEL_MAPPING = {
        'ANG': 'angry',
        'DIS': 'disgust',
        'FEA': 'fearful',
        'HAP': 'happy',
        'NEU': 'neutral',
        'SAD': 'sad',
        'CAL': 'calm',
        'SUR': 'surprised'
    }
    
    def __init__(
        self, 
        model_path: str,
        output_dir: str = "./evaluation_results",
        checkpoint_file: str = "checkpoint.pkl",
        sample_rate: int = 16000,
        dev_mode: bool = False,
        dev_samples: int = 50
    ):
        self.model_path = model_path
        self.output_dir = output_dir
        self.checkpoint_path = os.path.join(output_dir, checkpoint_file)
        self.sample_rate = sample_rate
        self.dev_mode = dev_mode
        self.dev_samples = dev_samples
        
        os.makedirs(output_dir, exist_ok=True)
        
        print(f"Loading model: {model_path}")
        self.session = ort.InferenceSession(
            model_path,
            providers=['CPUExecutionProvider']
        )
        
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name
        print(f"✓ Model loaded (CPU)")
        
        print(f"\nLoading SSI dataset...")
        self.dataset = self._load_dataset()
        
        print(f"\n{'='*60}")
        print(f"Evaluator initialized")
        print(f"Dev mode: {dev_mode}")
        if dev_mode:
            print(f"Samples: {dev_samples}")
        print(f"{'='*60}\n")
    
    def _load_dataset(self):
        ds = load_dataset("stapesai/ssi-speech-emotion-recognition")
        dataset = ds['validation']
        
        print(f"✓ Loaded validation split: {len(dataset)} samples")
        
        if self.dev_mode:
            dataset = dataset.select(range(min(self.dev_samples, len(dataset))))
            print(f"  Dev mode: {len(dataset)} samples")
        
        return dataset
    
    def _preprocess_audio(self, audio_array: np.ndarray, original_sr: int) -> np.ndarray:
        if original_sr != self.sample_rate:
            audio_array = librosa.resample(
                audio_array, 
                orig_sr=original_sr, 
                target_sr=self.sample_rate
            )
        
        if np.abs(audio_array).max() > 0:
            audio_array = audio_array / np.abs(audio_array).max()
        
        return audio_array
    
    def _predict_emotion(self, audio_array: np.ndarray) -> Tuple[int, np.ndarray]:
        input_values = audio_array.astype(np.float32).reshape(1, -1)
        outputs = self.session.run([self.output_name], {self.input_name: input_values})
        logits = outputs[0][0]
        predicted_emotion = int(np.argmax(logits))
        return predicted_emotion, logits
    
    def evaluate(self) -> Dict:
        print(f"\n{'='*60}")
        print("STARTING EVALUATION")
        print(f"{'='*60}\n")
        
        predictions = []
        ground_truth = []
        all_logits = []
        failed_samples = []
        
        start_time = time.time()
        
        for idx, sample in enumerate(tqdm(self.dataset, desc="Evaluating")):
            try:
                audio_data = sample['file_path']
                
                if isinstance(audio_data, dict) and 'array' in audio_data:
                    audio_array = np.array(audio_data['array'])
                    audio_sr = audio_data['sampling_rate']
                else:
                    failed_samples.append(idx)
                    continue
                
                ssi_emotion_label = sample['emotion']
                
                if ssi_emotion_label not in self.SSI_TO_MODEL_MAPPING:
                    failed_samples.append(idx)
                    continue
                
                model_emotion_name = self.SSI_TO_MODEL_MAPPING[ssi_emotion_label]
                emotion_name_to_id = {v: k for k, v in self.EMOTION_LABELS.items()}
                true_emotion = emotion_name_to_id[model_emotion_name]
                
                processed_audio = self._preprocess_audio(audio_array, audio_sr)
                pred_emotion, logits = self._predict_emotion(processed_audio)
                
                predictions.append(pred_emotion)
                ground_truth.append(true_emotion)
                all_logits.append(logits)
                
            except Exception as e:
                print(f"\n⚠️  Error on sample {idx}: {e}")
                failed_samples.append(idx)
                continue
        
        end_time = time.time()
        eval_time = end_time - start_time
        
        results = self._calculate_metrics(
            predictions, ground_truth, all_logits, eval_time, failed_samples
        )
        
        return results
    
    def _calculate_metrics(
        self, 
        predictions: List[int], 
        ground_truth: List[int],
        all_logits: List[np.ndarray],
        eval_time: float,
        failed_samples: List[int]
    ) -> Dict:
        
        accuracy = accuracy_score(ground_truth, predictions)
        
        precision, recall, f1, support = precision_recall_fscore_support(
            ground_truth, predictions, average=None,
            labels=list(range(len(self.EMOTION_LABELS)))
        )
        
        precision_weighted, recall_weighted, f1_weighted, _ = precision_recall_fscore_support(
            ground_truth, predictions, average='weighted'
        )
        
        precision_macro, recall_macro, f1_macro, _ = precision_recall_fscore_support(
            ground_truth, predictions, average='macro'
        )
        
        cm = confusion_matrix(ground_truth, predictions)
        
        class_report = classification_report(
            ground_truth, predictions,
            target_names=[self.EMOTION_LABELS[i] for i in range(len(self.EMOTION_LABELS))],
            output_dict=True
        )
        
        return {
            'overall': {
                'accuracy': float(accuracy),
                'precision_weighted': float(precision_weighted),
                'recall_weighted': float(recall_weighted),
                'f1_weighted': float(f1_weighted),
                'precision_macro': float(precision_macro),
                'recall_macro': float(recall_macro),
                'f1_macro': float(f1_macro),
            },
            'per_class': {
                self.EMOTION_LABELS[i]: {
                    'precision': float(precision[i]),
                    'recall': float(recall[i]),
                    'f1': float(f1[i]),
                    'support': int(support[i])
                }
                for i in range(len(self.EMOTION_LABELS))
            },
            'confusion_matrix': cm.tolist(),
            'classification_report': class_report,
            'predictions': predictions,
            'ground_truth': ground_truth,
            'logits': [l.tolist() for l in all_logits],
            'metadata': {
                'total_samples': len(predictions),
                'failed_samples': len(failed_samples),
                'failed_indices': failed_samples,
                'evaluation_time_seconds': eval_time,
                'samples_per_second': len(predictions) / eval_time if eval_time > 0 else 0,
                'dev_mode': self.dev_mode,
                'model_path': self.model_path,
                'timestamp': datetime.now().isoformat()
            }
        }
    
    def save_results(self, results: Dict, filename: str = 'results.json'):
        output_path = os.path.join(self.output_dir, filename)
        results_for_json = results.copy()
        results_for_json.pop('logits', None)
        
        with open(output_path, 'w') as f:
            json.dump(results_for_json, f, indent=2)
        
        print(f"✓ Results saved: {output_path}")
    
    def save_detailed_csv(self, results: Dict, filename: str = 'detailed_results.csv'):
        output_path = os.path.join(self.output_dir, filename)
        
        df = pd.DataFrame({
            'sample_index': range(len(results['predictions'])),
            'predicted_emotion': [self.EMOTION_LABELS[p] for p in results['predictions']],
            'true_emotion': [self.EMOTION_LABELS[t] for t in results['ground_truth']],
            'predicted_id': results['predictions'],
            'true_id': results['ground_truth'],
            'correct': [p == t for p, t in zip(results['predictions'], results['ground_truth'])]
        })
        
        df.to_csv(output_path, index=False)
        print(f"✓ CSV saved: {output_path}")
    
    def plot_confusion_matrix(self, results: Dict, filename: str = 'confusion_matrix.png'):
        output_path = os.path.join(self.output_dir, filename)
        
        cm = np.array(results['confusion_matrix'])
        emotion_names = [self.EMOTION_LABELS[i] for i in range(len(self.EMOTION_LABELS))]
        
        plt.figure(figsize=(12, 10))
        sns.heatmap(
            cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=emotion_names, yticklabels=emotion_names
        )
        plt.title('Emotion Recognition - Confusion Matrix', fontsize=16, pad=20)
        plt.ylabel('True Emotion', fontsize=12)
        plt.xlabel('Predicted Emotion', fontsize=12)
        plt.xticks(rotation=45, ha='right')
        plt.yticks(rotation=0)
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✓ Confusion matrix: {output_path}")
    
    def plot_per_class_metrics(self, results: Dict, filename: str = 'per_class_metrics.png'):
        output_path = os.path.join(self.output_dir, filename)
        
        emotions = [self.EMOTION_LABELS[i] for i in range(len(self.EMOTION_LABELS))]
        per_class = results['per_class']
        
        precisions = [per_class[e]['precision'] for e in emotions]
        recalls = [per_class[e]['recall'] for e in emotions]
        f1_scores = [per_class[e]['f1'] for e in emotions]
        
        x = np.arange(len(emotions))
        width = 0.25
        
        fig, ax = plt.subplots(figsize=(14, 8))
        ax.bar(x - width, precisions, width, label='Precision', alpha=0.8)
        ax.bar(x, recalls, width, label='Recall', alpha=0.8)
        ax.bar(x + width, f1_scores, width, label='F1-Score', alpha=0.8)
        
        ax.set_xlabel('Emotion', fontsize=12)
        ax.set_ylabel('Score', fontsize=12)
        ax.set_title('Per-Class Metrics: Emotion Recognition', fontsize=16, pad=20)
        ax.set_xticks(x)
        ax.set_xticklabels(emotions, rotation=45, ha='right')
        ax.legend()
        ax.grid(True, alpha=0.3, axis='y')
        ax.set_ylim([0, 1.05])
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✓ Per-class metrics: {output_path}")
    
    def generate_summary_report(self, results: Dict):
        print("\n" + "="*60)
        print("EVALUATION SUMMARY")
        print("="*60)
        
        print(f"\nOVERALL METRICS:")
        print(f"{'-'*60}")
        overall = results['overall']
        print(f"{'Accuracy':<30} {overall['accuracy']:<20.4f}")
        print(f"{'Precision (Weighted)':<30} {overall['precision_weighted']:<20.4f}")
        print(f"{'Recall (Weighted)':<30} {overall['recall_weighted']:<20.4f}")
        print(f"{'F1-Score (Weighted)':<30} {overall['f1_weighted']:<20.4f}")
        print(f"{'Precision (Macro)':<30} {overall['precision_macro']:<20.4f}")
        print(f"{'Recall (Macro)':<30} {overall['recall_macro']:<20.4f}")
        print(f"{'F1-Score (Macro)':<30} {overall['f1_macro']:<20.4f}")
        
        print(f"\nPER-CLASS METRICS:")
        print(f"{'-'*60}")
        print(f"{'Emotion':<15} {'Precision':<15} {'Recall':<15} {'F1-Score':<15} {'Support':<10}")
        print(f"{'-'*60}")
        
        for emotion_id in range(len(self.EMOTION_LABELS)):
            emotion = self.EMOTION_LABELS[emotion_id]
            metrics = results['per_class'][emotion]
            print(f"{emotion:<15} {metrics['precision']:<15.4f} {metrics['recall']:<15.4f} "
                  f"{metrics['f1']:<15.4f} {metrics['support']:<10}")
        
        print(f"\nEVALUATION METADATA:")
        print(f"{'-'*60}")
        meta = results['metadata']
        print(f"{'Total Samples':<30} {meta['total_samples']}")
        print(f"{'Failed Samples':<30} {meta['failed_samples']}")
        print(f"{'Evaluation Time':<30} {meta['evaluation_time_seconds']:.2f} seconds")
        print(f"{'Samples per Second':<30} {meta['samples_per_second']:.2f}")
        
        print("="*60 + "\n")


def main():
    DEV_MODE = False
    DEV_SAMPLES = 50
    
    MODEL_PATH = "emotion_recognition_quantized.onnx"
    OUTPUT_DIR = "./evaluation_results"
    
    print("\n" + "="*60)
    print("EMOTION RECOGNITION EVALUATION")
    print("="*60)
    print(f"Dataset: SSI Speech Emotion Recognition")
    print(f"Dev mode: {DEV_MODE}")
    if DEV_MODE:
        print(f"Samples: {DEV_SAMPLES}")
    print("="*60 + "\n")
    
    evaluator = EmotionRecognitionEvaluator(
        model_path=MODEL_PATH,
        output_dir=OUTPUT_DIR,
        dev_mode=DEV_MODE,
        dev_samples=DEV_SAMPLES
    )
    
    results = evaluator.evaluate()
    
    evaluator.save_results(results, 'results.json')
    evaluator.save_detailed_csv(results, 'detailed_results.csv')
    evaluator.plot_confusion_matrix(results, 'confusion_matrix.png')
    evaluator.plot_per_class_metrics(results, 'per_class_metrics.png')
    evaluator.generate_summary_report(results)
    
    print("\n" + "="*60)
    print("EVALUATION COMPLETE")
    print(f"Results: {OUTPUT_DIR}")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()