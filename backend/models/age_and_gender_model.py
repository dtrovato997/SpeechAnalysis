import os
import numpy as np
import audeer
import audonnx
import audinterface
import librosa

class AgeGenderModel:
    def __init__(self, model_path="./cache/age_and_gender"):
        self.model_path = model_path
        self.model = None
        self.interface = None
        self.sampling_rate = 16000
        os.makedirs(model_path, exist_ok=True)
    
    def download_model(self):
        model_onnx = os.path.join(self.model_path, 'model.onnx')
        model_yaml = os.path.join(self.model_path, 'model.yaml')
        
        if os.path.exists(model_onnx) and os.path.exists(model_yaml):
            print("Age & gender model files already exist, skipping download.")
            return True
        
        print("Age & gender model files not found. Downloading...")
        
        try:
            cache_root = 'cache'
            audeer.mkdir(cache_root)
            audeer.mkdir(self.model_path)
            
            def cache_path(file):
                return os.path.join(cache_root, file)
            
            url = 'https://zenodo.org/record/7761387/files/w2v2-L-robust-24-age-gender.728d5a4c-1.1.1.zip'
            dst_path = cache_path('model.zip')
            
            if not os.path.exists(dst_path):
                print(f"Downloading model from {url}...")
                audeer.download_url(url, dst_path, verbose=True)
            
            print(f"Extracting model to {self.model_path}...")
            audeer.extract_archive(dst_path, self.model_path, verbose=True)

            if os.path.exists(model_onnx) and os.path.exists(model_yaml):
                print("Age & gender model downloaded and extracted successfully!")

                if os.path.exists(dst_path):
                    os.remove(dst_path)
                return True
            else:
                print("Age & gender model extraction failed, files not found after extraction")
                return False
                
        except Exception as e:
            print(f"Error downloading age & gender model: {e}")
            return False
    
    def load(self):
        try:
            # Download model if needed
            if not self.download_model():
                print("Failed to download age & gender model")
                return False
            
            # Load the audonnx model
            print("Loading age & gender model...")
            self.model = audonnx.load(self.model_path)
            
            # Create the audinterface Feature interface
            outputs = ['logits_age', 'logits_gender']
            self.interface = audinterface.Feature(
                self.model.labels(outputs),
                process_func=self.model,
                process_func_args={
                    'outputs': outputs,
                    'concat': True,
                },
                sampling_rate=self.sampling_rate,
                resample=False,  # We handle resampling manually
                verbose=False,
            )
            print("Age & gender model loaded successfully!")
            return True
        except Exception as e:
            print(f"Error loading age & gender model: {e}")
            return False
    
    
    def predict(self, audio_data, sr):
        if self.model is None or self.interface is None:
            raise ValueError("Model not loaded. Call load() first.")
        
        try:            # Process with the interface
            result = self.interface.process_signal(audio_data, sr)
            
            # Extract and process results
            age_score = result['age'].values[0]
            gender_logits = {
                'female': result['female'].values[0],
                'male': result['male'].values[0],
                'child': result['child'].values[0]
            }
            
            predicted_age = age_score * 100      
            gender_values = np.array(list(gender_logits.values()))
            gender_probs = np.exp(gender_values) / np.sum(np.exp(gender_values))
            
            gender_labels = ['female', 'male', 'child']
            gender_probabilities = {
                label: float(prob) for label, prob in zip(gender_labels, gender_probs)
            }
            
            # Find most likely gender
            predicted_gender = gender_labels[np.argmax(gender_probs)]
            max_probability = float(np.max(gender_probs))
            
            return {
                'age': {
                    'predicted_age': float(predicted_age)
                },
                'gender': {
                    'predicted_gender': predicted_gender,
                    'probabilities': gender_probabilities,
                    'confidence': max_probability
                }
            }
        except Exception as e:
            raise Exception(f"Age & gender prediction error: {str(e)}")