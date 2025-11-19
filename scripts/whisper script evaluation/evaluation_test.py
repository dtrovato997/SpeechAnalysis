import os
import json
import numpy as np
import torch
from pathlib import Path
from typing import Dict, List, Tuple
from tqdm import tqdm
from datasets import load_dataset, Dataset
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import threading
import time

WHISPER_99_LANGUAGES = [
    'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt', 'tr',
    'pl', 'ca', 'nl', 'ar', 'sv', 'it', 'id', 'hi', 'fi', 'vi',
    'he', 'uk', 'el', 'ms', 'cs', 'ro', 'da', 'hu', 'ta', 'no',
    'th', 'ur', 'hr', 'bg', 'lt', 'la', 'mi', 'ml', 'cy', 'sk',
    'te', 'fa', 'lv', 'bn', 'sr', 'az', 'sl', 'kn', 'et', 'mk',
    'br', 'eu', 'is', 'hy', 'ne', 'mn', 'bs', 'kk', 'sq', 'sw',
    'gl', 'mr', 'pa', 'si', 'km', 'sn', 'yo', 'so', 'af', 'oc',
    'ka', 'be', 'tg', 'sd', 'gu', 'am', 'yi', 'lo', 'uz', 'fo',
    'ht', 'ps', 'tk', 'nn', 'mt', 'sa', 'lb', 'my', 'bo', 'tl',
    'mg', 'as', 'tt', 'haw', 'ln', 'ha', 'ba', 'jw', 'su'
]

WHISPER_82_HIGH_RESOURCE = [
    'af', 'am', 'ar', 'as', 'az', 'be', 'bg', 'bn', 'bs', 'ca', 'zh', 'cs', 'cy', 'da',
    'de', 'el', 'en', 'es', 'et', 'fa', 'fi', 'tl', 'fr', 'gl', 'gu', 'ha', 'he', 'hi',
    'hr', 'hu', 'hy', 'id', 'is', 'it', 'ja', 'jw', 'ka', 'kk', 'km', 'kn', 'ko', 'lb',
    'ln', 'lo', 'lt', 'lv', 'mi', 'mk', 'ml', 'mn', 'mr', 'ms', 'mt', 'my', 'no', 'ne',
    'nl', 'oc', 'pa', 'pl', 'ps', 'pt', 'ro', 'ru', 'sd', 'sk', 'sl', 'sn', 'so', 'sr',
    'sv', 'sw', 'ta', 'te', 'tg', 'th', 'tr', 'uk', 'ur', 'uz', 'vi', 'yo'
]

WHISPER_17_LOW_RESOURCE = [
    'tk', 'nn', 'mt', 'sa', 'lb', 'my', 'bo', 'tl',
    'mg', 'as', 'tt', 'haw', 'ln', 'ha', 'ba', 'jw', 'su'
]

WHISPER_TO_FLEURS_LANGUAGE_NAMES = {
    'en': 'English', 'zh': 'Mandarin Chinese', 'de': 'German', 'es': 'Spanish',
    'ru': 'Russian', 'ko': 'Korean', 'fr': 'French', 'ja': 'Japanese',
    'pt': 'Portuguese', 'tr': 'Turkish', 'pl': 'Polish', 'ca': 'Catalan',
    'nl': 'Dutch', 'ar': 'Arabic', 'sv': 'Swedish', 'it': 'Italian',
    'id': 'Indonesian', 'hi': 'Hindi', 'fi': 'Finnish', 'vi': 'Vietnamese',
    'he': 'Hebrew', 'uk': 'Ukrainian', 'el': 'Greek', 'ms': 'Malay',
    'cs': 'Czech', 'ro': 'Romanian', 'da': 'Danish', 'hu': 'Hungarian',
    'ta': 'Tamil', 'no': 'Norwegian', 'th': 'Thai', 'ur': 'Urdu',
    'hr': 'Croatian', 'bg': 'Bulgarian', 'lt': 'Lithuanian', 'mi': 'Maori',
    'ml': 'Malayalam', 'cy': 'Welsh', 'sk': 'Slovak', 'te': 'Telugu',
    'fa': 'Persian', 'lv': 'Latvian', 'bn': 'Bengali', 'sr': 'Serbian',
    'az': 'Azerbaijani', 'sl': 'Slovenian', 'kn': 'Kannada', 'et': 'Estonian',
    'mk': 'Macedonian', 'is': 'Icelandic', 'hy': 'Armenian', 'ne': 'Nepali',
    'mn': 'Mongolian', 'bs': 'Bosnian', 'kk': 'Kazakh', 'sw': 'Swahili',
    'gl': 'Galician', 'mr': 'Marathi', 'pa': 'Punjabi', 'km': 'Khmer',
    'sn': 'Shona', 'yo': 'Yoruba', 'so': 'Somali', 'af': 'Afrikaans',
    'oc': 'Occitan', 'ka': 'Georgian', 'be': 'Belarusian', 'tg': 'Tajik',
    'sd': 'Sindhi', 'gu': 'Gujarati', 'am': 'Amharic', 'lo': 'Lao',
    'uz': 'Uzbek', 'ps': 'Pashto', 'as': 'Assamese', 'tl': 'Filipino',
    'ha': 'Hausa', 'jw': 'Javanese', 'lb': 'Luxembourgish', 'ln': 'Lingala',
    'mt': 'Maltese', 'my': 'Burmese', 'la': None, 'br': None, 'eu': None,
    'sq': None, 'si': None, 'yi': None, 'fo': None, 'ht': None, 'tk': None,
    'nn': None, 'sa': None, 'bo': None, 'mg': None, 'tt': None, 'haw': None,
    'ba': None, 'su': None
}


class WhisperFLEURSEvaluator:
    
    def __init__(
        self, 
        model_path: str,
        cache_dir: str = "",
        output_dir: str = "./evaluation_results",
        dev_mode: bool = False,
        dev_samples: int = 100,
        use_82_languages: bool = True,
        eval_whisper_subset: bool = True,
        eval_full_102: bool = True
    ):
        self.model_path = model_path
        self.cache_dir = cache_dir
        self.output_dir = output_dir
        self.dev_mode = dev_mode
        self.dev_samples = dev_samples
        self.use_82_languages = use_82_languages
        self.eval_whisper_subset = eval_whisper_subset
        self.eval_full_102 = eval_full_102
        
        self.paused = False
        self.pause_lock = threading.Lock()
        self.stop_requested = False
        self.keyboard_thread = None
        
        self.num_whisper_langs = 82 if use_82_languages else 99
        self.whisper_eval_langs = WHISPER_82_HIGH_RESOURCE if use_82_languages else WHISPER_99_LANGUAGES
        
        if not eval_whisper_subset and not eval_full_102:
            raise ValueError("At least one evaluation must be enabled")
        
        os.makedirs(output_dir, exist_ok=True)
        
        self.preprocessor_session = None
        self.detector_session = None
        self.load_model()
        
        print(f"\n{'='*60}")
        print(f"EVALUATION CONFIGURATION")
        print(f"{'='*60}")
        print(f"Mode: {'DEV' if dev_mode else 'FULL'}")
        print(f"Language set: {self.num_whisper_langs} languages")
        if eval_whisper_subset:
            print(f"  ✓ Whisper {self.num_whisper_langs}-language subset")
        if eval_full_102:
            print(f"  ✓ Full 102-language FLEURS set")
        print(f"{'='*60}\n")
    
    def load_model(self):
        import onnxruntime as ort
        
        preprocessor_path = "whisper_preprocessor.onnx"
        detector_path = "whisper_lang_detector.onnx"
        
        if not os.path.exists(preprocessor_path):
            raise FileNotFoundError(f"Preprocessor model not found: {preprocessor_path}")
        if not os.path.exists(detector_path):
            raise FileNotFoundError(f"Detector model not found: {detector_path}")
        
        providers = ['CPUExecutionProvider']
        
        sess_options = ort.SessionOptions()
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        
        self.preprocessor_session = ort.InferenceSession(
            preprocessor_path, sess_options=sess_options, providers=providers
        )
        self.detector_session = ort.InferenceSession(
            detector_path, sess_options=sess_options, providers=providers
        )
        
        print(f"✓ Models loaded (CPU)")
    
    def _keyboard_listener(self):
        print("\nKEYBOARD CONTROLS: 'p' PAUSE | 'r' RESUME | 'q' QUIT\n")
        
        while not self.stop_requested:
            try:
                user_input = input().strip().lower()
                
                if user_input == 'p':
                    with self.pause_lock:
                        if not self.paused:
                            self.paused = True
                            print("\n⏸️  PAUSED - Press 'r' to resume\n")
                
                elif user_input == 'r':
                    with self.pause_lock:
                        if self.paused:
                            self.paused = False
                            print("\n▶️  RESUMED\n")
                
                elif user_input == 'q':
                    with self.pause_lock:
                        self.stop_requested = True
                        print("\n🛑 STOPPING - Saving progress...\n")
                    break
                
            except (EOFError, Exception):
                break
    
    def _start_keyboard_listener(self):
        self.keyboard_thread = threading.Thread(target=self._keyboard_listener, daemon=True)
        self.keyboard_thread.start()
    
    def _check_pause(self):
        while True:
            with self.pause_lock:
                if self.stop_requested:
                    return True
                if not self.paused:
                    return False
            time.sleep(0.1)
    
    def download_fleurs(self, subset: str = "all") -> Dict[str, Dataset]:
        print(f"\nDownloading FLEURS dataset (subset: {subset})")
        dataset = load_dataset("google/fleurs", subset)
        print(f"Dataset downloaded - Test split: {len(dataset['test'])} samples")
        return dataset
    
    def _predict_language(self, audio_array: np.ndarray, sample_rate: int) -> Tuple[str, float]:
        if sample_rate != 16000:
            from scipy import signal
            num_samples = int(len(audio_array) * 16000 / sample_rate)
            audio_array = signal.resample(audio_array, num_samples)
        
        max_samples = 30 * 16000
        if len(audio_array) > max_samples:
            audio_array = audio_array[:max_samples]
        
        max_amplitude = np.max(np.abs(audio_array))
        if max_amplitude > 0:
            audio_array = audio_array / max_amplitude
        
        audio_input = audio_array.astype(np.float32).reshape(1, -1)
        
        preprocessor_outputs = self.preprocessor_session.run(None, {"audio_pcm": audio_input})
        preprocessed_features = preprocessor_outputs[0]
        features_2d = preprocessed_features[0]
        
        detector_outputs = self.detector_session.run(None, {"input_features": features_2d})
        language_probs = detector_outputs[0]
        
        if len(language_probs.shape) == 2:
            language_probs = language_probs[0]
        
        top_idx = np.argmax(language_probs)
        top_confidence = float(language_probs[top_idx])
        
        predicted_lang_code = WHISPER_99_LANGUAGES[top_idx] if top_idx < len(WHISPER_99_LANGUAGES) else 'unknown'
        predicted_lang_name = WHISPER_TO_FLEURS_LANGUAGE_NAMES.get(predicted_lang_code, predicted_lang_code)
        
        if predicted_lang_name is None:
            predicted_lang_name = f"[Whisper-{predicted_lang_code}]"
        
        return predicted_lang_name, top_confidence
    
    def evaluate_subset(
        self, 
        dataset: Dataset, 
        language_subset: List[str] = None,
        max_samples_per_lang: int = None
    ) -> Dict:
        predictions = []
        ground_truth = []
        confidences = []
        
        if self.dev_mode:
            eval_indices = list(range(min(self.dev_samples, len(dataset))))
            if language_subset:
                filtered_indices = [
                    idx for idx in eval_indices 
                    if dataset[idx]['language'] in language_subset
                ]
                eval_indices = filtered_indices
            print(f"DEV MODE: {len(eval_indices)} samples")
        else:
            if language_subset:
                samples_by_lang = {}
                for idx, sample in enumerate(tqdm(dataset, desc="Scanning")):
                    lang_name = sample['language']
                    if lang_name in language_subset:
                        if lang_name not in samples_by_lang:
                            samples_by_lang[lang_name] = []
                        samples_by_lang[lang_name].append(idx)
                
                eval_indices = []
                for lang, indices in sorted(samples_by_lang.items()):
                    if max_samples_per_lang:
                        indices = indices[:max_samples_per_lang]
                    eval_indices.extend(indices)
                
                print(f"Evaluating {len(eval_indices):,} samples")
            else:
                eval_indices = range(len(dataset))
        
        successful = 0
        failed = 0
        
        self._start_keyboard_listener()
        
        progress_bar = tqdm(eval_indices, desc="Evaluating", unit="samples", ncols=100)
        
        for idx in progress_bar:
            should_stop = self._check_pause()
            if should_stop:
                print("\n🛑 STOPPED - Saving partial results")
                break
            
            sample = dataset[int(idx)]
            audio_array = np.array(sample['audio']['array'])
            sample_rate = sample['audio']['sampling_rate']
            true_lang_name = sample['language']
            
            try:
                pred_lang_name, confidence = self._predict_language(audio_array, sample_rate)
                successful += 1
            except Exception as e:
                failed += 1
                if failed == 1:
                    print(f"\n⚠️  Error on sample {idx}: {e}")
                pred_lang_name = 'unknown'
                confidence = 0.0
            
            predictions.append(pred_lang_name)
            ground_truth.append(true_lang_name)
            confidences.append(confidence)
            
            progress_bar.set_postfix({'success': successful, 'failed': failed})
            
            if len(predictions) % 1000 == 0 and len(predictions) > 0:
                self._save_intermediate_results(
                    predictions, ground_truth, confidences, 
                    f"checkpoint_{len(predictions)}.pkl"
                )
        
        self.stop_requested = True
        
        print(f"\n{'='*60}")
        print(f"✓ Success: {successful:,} ({successful/len(predictions)*100:.1f}%)")
        if failed > 0:
            print(f"✗ Failed: {failed:,}")
        print(f"{'='*60}\n")
        
        accuracy = accuracy_score(ground_truth, predictions)
        unique_langs = sorted(list(set(ground_truth)))
        
        report = classification_report(
            ground_truth, predictions, labels=unique_langs,
            output_dict=True, zero_division=0
        )
        
        return {
            'accuracy': accuracy,
            'num_samples': len(predictions),
            'num_languages': len(unique_langs),
            'languages': unique_langs,
            'predictions': predictions,
            'ground_truth': ground_truth,
            'confidences': confidences,
            'classification_report': report,
            'dev_mode': self.dev_mode,
            'successful_predictions': successful,
            'failed_predictions': failed
        }
    
    def save_results(self, results: Dict, filename: str):
        if self.dev_mode:
            filename = f"dev_{filename}"
        
        output_path = os.path.join(self.output_dir, filename)
        
        save_data = {
            'dev_mode': results.get('dev_mode', False),
            'accuracy': results['accuracy'],
            'num_samples': results['num_samples'],
            'num_languages': results['num_languages'],
            'languages': results['languages'],
            'classification_report': results['classification_report']
        }
        
        with open(output_path, 'w') as f:
            json.dump(save_data, f, indent=2)
        print(f"✓ Results saved: {output_path}")
        
        csv_path = output_path.replace('.json', '_detailed.csv')
        df = pd.DataFrame({
            'ground_truth': results['ground_truth'],
            'prediction': results['predictions'],
            'confidence': results['confidences'],
            'correct': [gt == pred for gt, pred in zip(results['ground_truth'], results['predictions'])]
        })
        df.to_csv(csv_path, index=False)
        print(f"✓ CSV saved: {csv_path}")
    
    def plot_confusion_matrix(self, results: Dict, filename: str, top_n: int = 20):
        from collections import Counter
        lang_counts = Counter(results['ground_truth'])
        top_langs = [lang for lang, _ in lang_counts.most_common(top_n)]
        
        filtered_gt = []
        filtered_pred = []
        for gt, pred in zip(results['ground_truth'], results['predictions']):
            if gt in top_langs:
                filtered_gt.append(gt)
                filtered_pred.append(pred if pred in top_langs else 'other')
        
        cm = confusion_matrix(filtered_gt, filtered_pred, labels=top_langs)
        
        plt.figure(figsize=(12, 10))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                    xticklabels=top_langs, yticklabels=top_langs)
        plt.title(f'Confusion Matrix - Top {top_n} Languages')
        plt.ylabel('True Language')
        plt.xlabel('Predicted Language')
        plt.tight_layout()
        
        if self.dev_mode:
            filename = f"dev_{filename}"
        
        output_path = os.path.join(self.output_dir, filename)
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"✓ Confusion matrix: {output_path}")
        plt.close()
    
    def plot_all_confusion_matrices(self, results: Dict, base_filename: str, langs_per_plot: int = 25):
        from collections import Counter
        
        lang_counts = Counter(results['ground_truth'])
        all_langs = [lang for lang, _ in lang_counts.most_common()]
        num_plots = (len(all_langs) + langs_per_plot - 1) // langs_per_plot
        
        print(f"\nGenerating {num_plots} confusion matrices...")
        
        for plot_idx in range(num_plots):
            start_idx = plot_idx * langs_per_plot
            end_idx = min((plot_idx + 1) * langs_per_plot, len(all_langs))
            group_langs = all_langs[start_idx:end_idx]
            
            filtered_gt = []
            filtered_pred = []
            for gt, pred in zip(results['ground_truth'], results['predictions']):
                if gt in group_langs:
                    filtered_gt.append(gt)
                    filtered_pred.append(pred if pred in group_langs else 'other')
            
            if len(filtered_gt) == 0:
                continue
            
            cm = confusion_matrix(filtered_gt, filtered_pred, labels=group_langs)
            
            fig_size = max(12, len(group_langs) * 0.5)
            plt.figure(figsize=(fig_size, fig_size))
            sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                        xticklabels=group_langs, yticklabels=group_langs,
                        cbar_kws={'label': 'Count'})
            plt.title(f'Confusion Matrix - Languages {start_idx+1}-{end_idx}')
            plt.ylabel('True Language')
            plt.xlabel('Predicted Language')
            plt.xticks(rotation=45, ha='right')
            plt.yticks(rotation=0)
            plt.tight_layout()
            
            if self.dev_mode:
                output_filename = f"dev_{base_filename}_group{plot_idx+1}.png"
            else:
                output_filename = f"{base_filename}_group{plot_idx+1}.png"
            
            output_path = os.path.join(self.output_dir, output_filename)
            plt.savefig(output_path, dpi=300, bbox_inches='tight')
            plt.close()
        
        print(f"✓ All confusion matrices saved")
    
    def run_full_evaluation(self):
        print("\n" + "="*60)
        print(f"WHISPER LANGUAGE IDENTIFICATION")
        print("="*60)
        
        dataset_subset = "en_us" if self.dev_mode else "all"
        dataset = self.download_fleurs(subset=dataset_subset)
        test_data = dataset['test']
        
        all_fleurs_langs = sorted(list(set(test_data['language'])))
        
        whisper_lang_names = set([
            WHISPER_TO_FLEURS_LANGUAGE_NAMES.get(code) 
            for code in self.whisper_eval_langs
            if WHISPER_TO_FLEURS_LANGUAGE_NAMES.get(code) is not None
        ])
        fleurs_whisper_langs = [lang for lang in all_fleurs_langs if lang in whisper_lang_names]
        
        results_whisper = None
        if self.eval_whisper_subset:
            print(f"\n{'='*60}")
            print(f"EVALUATION 1: {self.num_whisper_langs}-Language Subset")
            print(f"{'='*60}")
            
            results_whisper = self.evaluate_subset(
                test_data, language_subset=fleurs_whisper_langs, max_samples_per_lang=None
            )
            
            print(f"\nAccuracy: {results_whisper['accuracy']*100:.2f}%")
            print(f"Samples: {results_whisper['num_samples']:,}")
            
            self.save_results(results_whisper, f'results_{self.num_whisper_langs}_languages.json')
            self.plot_confusion_matrix(results_whisper, f'confusion_matrix_{self.num_whisper_langs}_langs.png', top_n=20)
            
            if results_whisper['num_languages'] > 20:
                self.plot_all_confusion_matrices(results_whisper, f'confusion_matrix_{self.num_whisper_langs}_complete', langs_per_plot=25)
        
        results_102 = None
        if self.eval_full_102 and not self.dev_mode:
            print(f"\n{'='*60}")
            print("EVALUATION 2: Full 102-Language Set")
            print(f"{'='*60}")
            
            results_102 = self.evaluate_subset(test_data, language_subset=None, max_samples_per_lang=None)
            
            print(f"\nAccuracy: {results_102['accuracy']*100:.2f}%")
            print(f"Samples: {results_102['num_samples']:,}")
            
            self.save_results(results_102, 'results_102_languages.json')
            self.plot_confusion_matrix(results_102, 'confusion_matrix_102_langs.png', top_n=20)
            self.plot_all_confusion_matrices(results_102, 'confusion_matrix_102_complete', langs_per_plot=25)
            
            if results_whisper is not None:
                self._generate_comparison_report(results_whisper, results_102)
        
        print(f"\n{'='*60}")
        print(f"EVALUATION COMPLETE")
        print(f"{'='*60}\n")
    
    def _generate_comparison_report(self, results_whisper: Dict, results_102: Dict):
        report_path = os.path.join(self.output_dir, 'comparison_report.txt')
        
        with open(report_path, 'w') as f:
            f.write("="*60 + "\n")
            f.write("WHISPER LANGUAGE IDENTIFICATION - COMPARISON REPORT\n")
            f.write("="*60 + "\n\n")
            
            f.write(f"{self.num_whisper_langs}-Language Subset:\n")
            f.write(f"  Accuracy: {results_whisper['accuracy']*100:.2f}%\n")
            f.write(f"  Samples: {results_whisper['num_samples']}\n\n")
            
            f.write(f"102-Language Full Set:\n")
            f.write(f"  Accuracy: {results_102['accuracy']*100:.2f}%\n")
            f.write(f"  Samples: {results_102['num_samples']}\n\n")
            
            accuracy_drop = results_whisper['accuracy'] - results_102['accuracy']
            f.write(f"Accuracy drop on zero-shot: {accuracy_drop*100:.2f}%\n")
        
        print(f"✓ Comparison report: {report_path}")
    
    def _save_intermediate_results(self, predictions, ground_truth, confidences, filename):
        import pickle
        checkpoint_path = os.path.join(self.output_dir, filename)
        checkpoint_data = {
            'predictions': predictions,
            'ground_truth': ground_truth,
            'confidences': confidences,
            'timestamp': time.time()
        }
        try:
            with open(checkpoint_path, 'wb') as f:
                pickle.dump(checkpoint_data, f)
        except Exception as e:
            print(f"Warning: Could not save checkpoint: {e}")


def main():
    DEV_MODE = False
    DEV_SAMPLES = 10
    USE_82_LANGUAGES = True
    
    EVAL_WHISPER_SUBSET = True
    EVAL_FULL_102 = False
    
    MODEL_PATH = "whisper_tiny_quantized.onnx"
    CACHE_DIR = ""
    OUTPUT_DIR = "./evaluation_results"
    
    evaluator = WhisperFLEURSEvaluator(
        model_path=MODEL_PATH,
        cache_dir=CACHE_DIR,
        output_dir=OUTPUT_DIR,
        dev_mode=DEV_MODE,
        dev_samples=DEV_SAMPLES,
        use_82_languages=USE_82_LANGUAGES,
        eval_whisper_subset=EVAL_WHISPER_SUBSET,
        eval_full_102=EVAL_FULL_102
    )
    
    evaluator.run_full_evaluation()


if __name__ == "__main__":
    main()