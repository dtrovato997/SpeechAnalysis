import os
import json
import numpy as np
import pandas as pd
import torch
import onnxruntime as ort
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from tqdm import tqdm
from sklearn.metrics import mean_absolute_error, accuracy_score, classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns
import pickle
import time
from datetime import datetime
import librosa
import warnings
warnings.filterwarnings('ignore')


class AgeGenderEvaluator:
    
    def __init__(
        self, 
        model_path: str,
        csv_path: str,
        audio_base_dir: str,
        output_dir: str = "./age_gender_evaluation_results",
        checkpoint_file: str = "checkpoint.pkl",
        sample_rate: int = 16000,
        dev_mode: bool = False,
        dev_samples: int = 50
    ):
        self.model_path = model_path
        self.csv_path = csv_path
        self.audio_base_dir = audio_base_dir
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
        self.age_output_name = self.session.get_outputs()[1].name
        self.gender_output_name = self.session.get_outputs()[2].name
        print(f"✓ Model loaded (CPU)")
        
        print(f"\nLoading test data: {csv_path}")
        self.test_df = pd.read_csv(csv_path)
        
        if dev_mode:
            self.test_df = self.test_df.head(dev_samples)
            print(f"  Dev mode: {len(self.test_df)} samples")
        else:
            print(f"  Total samples: {len(self.test_df)}")
        
        self.gender_map = {0: 'female', 1: 'male', 2: 'child'}
        self.reverse_gender_map = {'female': 0, 'male': 1, 'child': 2}
    
    def load_and_preprocess_audio(self, audio_path: str) -> Optional[np.ndarray]:
        try:
            audio, sr = librosa.load(audio_path, sr=self.sample_rate, mono=True)
            return audio.astype(np.float32)
        except Exception as e:
            print(f"Error loading {audio_path}: {e}")
            return None
    
    def predict(self, audio: np.ndarray) -> Tuple[Optional[float], Optional[str], Optional[Dict]]:
        try:
            audio_input = audio.reshape(1, -1)
            
            outputs = self.session.run(
                [self.age_output_name, self.gender_output_name],
                {self.input_name: audio_input}
            )
            
            age_logits = outputs[0]
            gender_logits = outputs[1]
            
            predicted_age = float(age_logits[0][0] * 100)
            
            gender_probs = self._softmax(gender_logits[0])
            predicted_gender_idx = np.argmax(gender_probs)
            predicted_gender = self.gender_map[predicted_gender_idx]
            
            gender_prob_dict = {
                self.gender_map[i]: float(gender_probs[i]) 
                for i in range(len(gender_probs))
            }
            
            return predicted_age, predicted_gender, gender_prob_dict
            
        except Exception as e:
            print(f"Prediction error: {e}")
            return None, None, None
    
    @staticmethod
    def _softmax(x: np.ndarray) -> np.ndarray:
        exp_x = np.exp(x - np.max(x))
        return exp_x / exp_x.sum()
    
    def load_checkpoint(self) -> Optional[Dict]:
        if os.path.exists(self.checkpoint_path):
            try:
                with open(self.checkpoint_path, 'rb') as f:
                    checkpoint = pickle.load(f)
                print(f"\n✓ Resuming from sample {checkpoint['last_processed_idx'] + 1}/{len(self.test_df)}")
                return checkpoint
            except Exception as e:
                print(f"  Checkpoint load error: {e}")
                return None
        return None
    
    def save_checkpoint(self, data: Dict):
        try:
            checkpoint_data = {**data, 'timestamp': time.time()}
            with open(self.checkpoint_path, 'wb') as f:
                pickle.dump(checkpoint_data, f)
        except Exception as e:
            print(f"  Checkpoint save error: {e}")
    
    def evaluate(self) -> Dict:
        print(f"\n{'='*60}")
        print("STARTING EVALUATION")
        print(f"{'='*60}\n")
        
        checkpoint = self.load_checkpoint()
        
        if checkpoint:
            age_predictions = checkpoint['age_predictions']
            age_ground_truth = checkpoint['age_ground_truth']
            gender_predictions = checkpoint['gender_predictions']
            gender_ground_truth = checkpoint['gender_ground_truth']
            gender_confidences = checkpoint['gender_confidences']
            start_idx = checkpoint['last_processed_idx'] + 1
            skipped_files = checkpoint.get('skipped_files', [])
        else:
            age_predictions = []
            age_ground_truth = []
            gender_predictions = []
            gender_ground_truth = []
            gender_confidences = []
            start_idx = 0
            skipped_files = []
        
        for idx in tqdm(range(start_idx, len(self.test_df)), 
                       desc="Evaluating", 
                       initial=start_idx, 
                       total=len(self.test_df)):
            
            row = self.test_df.iloc[idx]
            
            file_path_wav = row['file']
            file_path_mp3 = file_path_wav.replace('.wav', '.mp3')
            filename = os.path.basename(file_path_mp3)
            audio_path = os.path.join(self.audio_base_dir, filename)
            
            if not os.path.exists(audio_path):
                skipped_files.append(audio_path)
                continue
            
            audio = self.load_and_preprocess_audio(audio_path)
            if audio is None:
                skipped_files.append(audio_path)
                continue
            
            pred_age, pred_gender, gender_probs = self.predict(audio)
            if pred_age is None or pred_gender is None:
                skipped_files.append(audio_path)
                continue
            
            age_predictions.append(pred_age)
            age_ground_truth.append(row['age'])
            gender_predictions.append(pred_gender)
            gender_ground_truth.append(row['gender'])
            gender_confidences.append(gender_probs)
            
            if (idx + 1) % 50 == 0:
                self.save_checkpoint({
                    'age_predictions': age_predictions,
                    'age_ground_truth': age_ground_truth,
                    'gender_predictions': gender_predictions,
                    'gender_ground_truth': gender_ground_truth,
                    'gender_confidences': gender_confidences,
                    'last_processed_idx': idx,
                    'skipped_files': skipped_files
                })
        
        mae_age = mean_absolute_error(age_ground_truth, age_predictions)
        gender_accuracy = accuracy_score(gender_ground_truth, gender_predictions)
        
        gender_report = classification_report(
            gender_ground_truth, 
            gender_predictions,
            output_dict=True
        )
        
        gender_cm = confusion_matrix(
            gender_ground_truth,
            gender_predictions,
            labels=['female', 'male', 'child']
        )
        
        results = {
            'dev_mode': self.dev_mode,
            'num_samples': len(age_predictions),
            'num_skipped': len(skipped_files),
            'age': {
                'mae': float(mae_age),
                'predictions': age_predictions,
                'ground_truth': age_ground_truth
            },
            'gender': {
                'accuracy': float(gender_accuracy),
                'predictions': gender_predictions,
                'ground_truth': gender_ground_truth,
                'confidences': gender_confidences,
                'classification_report': gender_report,
                'confusion_matrix': gender_cm.tolist()
            },
            'skipped_files': skipped_files,
            'timestamp': datetime.now().isoformat()
        }
        
        print(f"\n{'='*60}")
        print("EVALUATION RESULTS")
        print(f"{'='*60}")
        print(f"Samples processed: {len(age_predictions)}")
        print(f"Skipped files: {len(skipped_files)}")
        print(f"\nAGE PREDICTION:")
        print(f"  MAE: {mae_age:.2f} years")
        print(f"\nGENDER CLASSIFICATION:")
        print(f"  Accuracy: {gender_accuracy*100:.2f}%")
        for gender_class in ['female', 'male', 'child']:
            if gender_class in gender_report:
                metrics = gender_report[gender_class]
                print(f"    {gender_class.capitalize()}: P={metrics['precision']:.3f}, "
                      f"R={metrics['recall']:.3f}, F1={metrics['f1-score']:.3f}")
        print(f"{'='*60}\n")
        
        if os.path.exists(self.checkpoint_path):
            os.remove(self.checkpoint_path)
            print("✓ Checkpoint removed")
        
        return results
    
    def save_results(self, results: Dict, filename: str = 'results.json'):
        output_path = os.path.join(self.output_dir, filename)
        
        json_results = {
            'dev_mode': results['dev_mode'],
            'num_samples': results['num_samples'],
            'num_skipped': results['num_skipped'],
            'age': {'mae': results['age']['mae']},
            'gender': {
                'accuracy': results['gender']['accuracy'],
                'classification_report': results['gender']['classification_report'],
                'confusion_matrix': results['gender']['confusion_matrix']
            },
            'timestamp': results['timestamp']
        }
        
        with open(output_path, 'w') as f:
            json.dump(json_results, f, indent=2)
        
        print(f"✓ Results saved: {output_path}")
    
    def save_detailed_csv(self, results: Dict, filename: str = 'detailed_results.csv'):
        output_path = os.path.join(self.output_dir, filename)
        
        df = pd.DataFrame({
            'age_predicted': results['age']['predictions'],
            'age_ground_truth': results['age']['ground_truth'],
            'age_error': np.abs(np.array(results['age']['predictions']) - np.array(results['age']['ground_truth'])),
            'gender_predicted': results['gender']['predictions'],
            'gender_ground_truth': results['gender']['ground_truth'],
            'gender_correct': np.array(results['gender']['predictions']) == np.array(results['gender']['ground_truth']),
            'confidence_female': [c['female'] for c in results['gender']['confidences']],
            'confidence_male': [c['male'] for c in results['gender']['confidences']],
            'confidence_child': [c['child'] for c in results['gender']['confidences']]
        })
        
        df.to_csv(output_path, index=False)
        print(f"✓ CSV saved: {output_path}")
    
    def plot_confusion_matrix(self, results: Dict, filename: str = 'confusion_matrix_gender.png'):
        cm = np.array(results['gender']['confusion_matrix'])
        labels = ['Female', 'Male', 'Child']
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=labels, yticklabels=labels,
            cbar_kws={'label': 'Count'}
        )
        plt.title('Gender Classification - Confusion Matrix', fontsize=14, fontweight='bold')
        plt.ylabel('True Label', fontsize=12)
        plt.xlabel('Predicted Label', fontsize=12)
        plt.tight_layout()
        
        output_path = os.path.join(self.output_dir, filename)
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✓ Confusion matrix: {output_path}")
    
    def plot_age_distribution(self, results: Dict, filename: str = 'age_distribution.png'):
        predictions = np.array(results['age']['predictions'])
        ground_truth = np.array(results['age']['ground_truth'])
        errors = np.abs(predictions - ground_truth)
        
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        
        axes[0, 0].scatter(ground_truth, predictions, alpha=0.5, s=10)
        axes[0, 0].plot([0, 100], [0, 100], 'r--', label='Perfect prediction')
        axes[0, 0].set_xlabel('Ground Truth Age (years)', fontsize=11)
        axes[0, 0].set_ylabel('Predicted Age (years)', fontsize=11)
        axes[0, 0].set_title('Age Prediction: Ground Truth vs Predicted', fontsize=12, fontweight='bold')
        axes[0, 0].legend()
        axes[0, 0].grid(True, alpha=0.3)
        
        axes[0, 1].hist(errors, bins=50, edgecolor='black', alpha=0.7)
        axes[0, 1].axvline(np.mean(errors), color='r', linestyle='--', label=f'Mean: {np.mean(errors):.2f}')
        axes[0, 1].axvline(np.median(errors), color='g', linestyle='--', label=f'Median: {np.median(errors):.2f}')
        axes[0, 1].set_xlabel('Absolute Error (years)', fontsize=11)
        axes[0, 1].set_ylabel('Frequency', fontsize=11)
        axes[0, 1].set_title('Age Prediction Error Distribution', fontsize=12, fontweight='bold')
        axes[0, 1].legend()
        axes[0, 1].grid(True, alpha=0.3)
        
        axes[1, 0].hist(ground_truth, bins=30, edgecolor='black', alpha=0.7, color='blue')
        axes[1, 0].set_xlabel('Age (years)', fontsize=11)
        axes[1, 0].set_ylabel('Frequency', fontsize=11)
        axes[1, 0].set_title('Ground Truth Age Distribution', fontsize=12, fontweight='bold')
        axes[1, 0].grid(True, alpha=0.3)
        
        axes[1, 1].hist(predictions, bins=30, edgecolor='black', alpha=0.7, color='green')
        axes[1, 1].set_xlabel('Age (years)', fontsize=11)
        axes[1, 1].set_ylabel('Frequency', fontsize=11)
        axes[1, 1].set_title('Predicted Age Distribution', fontsize=12, fontweight='bold')
        axes[1, 1].grid(True, alpha=0.3)
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, filename)
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✓ Age distribution: {output_path}")
    
    def generate_comparison_table(self, results: Dict):
        print(f"\n{'='*60}")
        print("COMPARISON WITH PAPER (Burkhardt et al., 2023)")
        print(f"{'='*60}")
        print(f"\n{'Metric':<30} {'Paper (FP32)':<20} {'This (INT8)':<20} {'Delta':<15}")
        print("-" * 60)
        
        paper_mae_years = 8.8
        our_mae = results['age']['mae']
        delta_mae = our_mae - paper_mae_years
        print(f"{'Age MAE (years)':<30} {paper_mae_years:<20.2f} {our_mae:<20.2f} {delta_mae:+.2f}")
        
        paper_gender_acc = 0.992
        our_gender_acc = results['gender']['accuracy']
        delta_gender = our_gender_acc - paper_gender_acc
        print(f"{'Gender Accuracy':<30} {paper_gender_acc:<20.3f} {our_gender_acc:<20.3f} {delta_gender:+.3f}")
        
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(description='Age & Gender Model Evaluation')
    parser.add_argument('--audio-dir', required=True, 
                       help='Path to audio files directory')
    parser.add_argument('--model', default='age_and_gender_model_quantized.onnx',
                       help='Path to ONNX model')
    parser.add_argument('--csv', default='mozillacommonvoice.test.csv',
                       help='Path to test CSV file')
    parser.add_argument('--output', default='./evaluation_results',
                       help='Output directory')
    parser.add_argument('--dev', action='store_true',
                       help='Run in development mode')
    parser.add_argument('--dev-samples', type=int, default=50,
                       help='Number of samples for dev mode')
    
    args = parser.parse_args()
    
    print(f"\n{'='*60}")
    print("AGE & GENDER EVALUATION")
    print(f"{'='*60}")
    print(f"Model: {args.model}")
    print(f"CSV: {args.csv}")
    print(f"Audio dir: {args.audio_dir}")
    print(f"Dev mode: {args.dev}")
    if args.dev:
        print(f"Samples: {args.dev_samples}")
    print(f"{'='*60}\n")
    
    evaluator = AgeGenderEvaluator(
        model_path=args.model,
        csv_path=args.csv,
        audio_base_dir=args.audio_dir,
        output_dir=args.output,
        dev_mode=args.dev,
        dev_samples=args.dev_samples
    )
    
    results = evaluator.evaluate()
    
    evaluator.save_results(results, 'results.json')
    evaluator.save_detailed_csv(results, 'detailed_results.csv')
    evaluator.plot_confusion_matrix(results, 'confusion_matrix_gender.png')
    evaluator.plot_age_distribution(results, 'age_distribution.png')
    evaluator.generate_comparison_table(results)
    
    print(f"\n{'='*60}")
    print("EVALUATION COMPLETE")
    print(f"Results: {args.output}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()