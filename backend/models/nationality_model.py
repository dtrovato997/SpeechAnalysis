import os
import torch
import numpy as np
from transformers import Wav2Vec2ForSequenceClassification, AutoFeatureExtractor

# Constants
MODEL_ID = "facebook/mms-lid-256"
SAMPLING_RATE = 16000

class NationalityModel:
    def __init__(self, cache_dir=None):
        if cache_dir is None:
            if os.path.exists("/data"):
                # HF Spaces persistent storage
                self.cache_dir = "/data/nationality"
            else:
                # Local development or other platforms
                self.cache_dir = "./cache/nationality"
        else:
            self.cache_dir = cache_dir
            
        self.processor = None
        self.model = None
        os.makedirs(self.cache_dir, exist_ok=True)
        
    def load(self):
        try:
            print(f"Loading nationality prediction model from {MODEL_ID}...")
            print(f"Using cache directory: {self.cache_dir}")
            
            self.processor = AutoFeatureExtractor.from_pretrained(
                MODEL_ID, 
                cache_dir=self.cache_dir
            )
            self.model = Wav2Vec2ForSequenceClassification.from_pretrained(
                MODEL_ID, 
                cache_dir=self.cache_dir
            )
            print("Nationality prediction model loaded successfully!")
            return True
        except Exception as e:
            print(f"Error loading nationality prediction model: {e}")
            return False
    
    def predict(self, audio_data, sampling_rate):
        if self.model is None or self.processor is None:
            raise ValueError("Model not loaded. Call load() first.")
        
        try:
            if len(audio_data.shape) > 1:
                audio_data = audio_data.mean(axis=0)
            
            audio_data = audio_data.astype(np.float32)
            
            inputs = self.processor(audio_data, sampling_rate=sampling_rate, return_tensors="pt")
            
            with torch.no_grad():
                outputs = self.model(**inputs).logits
            
            # Get top 5 predictions
            probabilities = torch.nn.functional.softmax(outputs, dim=-1)[0]
            top_k_values, top_k_indices = torch.topk(probabilities, k=5)
            
            top_languages = []
            for i, idx in enumerate(top_k_indices):
                lang_id = idx.item()
                lang_code = self.model.config.id2label[lang_id]
                probability = top_k_values[i].item()
                top_languages.append({
                    "language_code": lang_code,
                    "probability": probability
                })
            
            # Get the most likely language
            predicted_lang_id = torch.argmax(outputs, dim=-1)[0].item()
            predicted_lang = self.model.config.id2label[predicted_lang_id]
            max_probability = probabilities[predicted_lang_id].item()
            
            return {
                "predicted_language": predicted_lang,
                "confidence": max_probability,
                "top_languages": top_languages
            }
            
        except Exception as e:
            raise Exception(f"Nationality prediction error: {str(e)}")