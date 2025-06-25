import os
import torch
import numpy as np
import librosa
from transformers import Wav2Vec2FeatureExtractor, Wav2Vec2ForCTC, Wav2Vec2ForSequenceClassification

# Constants
MODEL_ID = "Dpngtm/wav2vec2-emotion-recognition"
SAMPLING_RATE = 16000

# Define the emotion mapping based on the model's expected output
EMOTION_MAPPING = {
    "LABEL_0": "angry",
    "LABEL_1": "calm", 
    "LABEL_2": "disgust",
    "LABEL_3": "fearful",
    "LABEL_4": "happy",
    "LABEL_5": "neutral",
    "LABEL_6": "sad",
    "LABEL_7": "surprised"
}

class EmotionModel:
    def __init__(self, cache_dir=None):
        if cache_dir is None:
            if os.path.exists("/data"):
                # HF Spaces persistent storage
                self.cache_dir = "/data/emotion"
            else:
                # Local development or other platforms
                self.cache_dir = "./cache/emotion"
        else:
            self.cache_dir = cache_dir
            
        self.processor = None
        self.model = None
        self.emotion_labels = None
        os.makedirs(self.cache_dir, exist_ok=True)
        
    def load(self):
        try:
            print(f"Loading emotion recognition model from {MODEL_ID}...")
            print(f"Using cache directory: {self.cache_dir}")
            
            self.processor = Wav2Vec2FeatureExtractor.from_pretrained(
                MODEL_ID, 
                cache_dir=self.cache_dir
            )

            self.model = Wav2Vec2ForSequenceClassification.from_pretrained(
                MODEL_ID, 

                cache_dir=self.cache_dir
            )
            
            # Get the raw labels from the model
            raw_labels = self.model.config.id2label
            
            # Map the generic labels to meaningful emotion names
            self.emotion_labels = {}
            for label_id, raw_label in raw_labels.items():
                if raw_label in EMOTION_MAPPING:
                    self.emotion_labels[label_id] = EMOTION_MAPPING[raw_label]
                else:
                    # Fallback in case the mapping doesn't match
                    self.emotion_labels[label_id] = raw_label.lower()

            print("Emotion recognition model loaded successfully!")
            print(f"Available emotions: {list(self.emotion_labels.values())}")
            return True
        except Exception as e:
            print(f"Error loading emotion recognition model: {e}")
            return False
    
    def predict(self, audio_data, sampling_rate):
        if self.model is None or self.processor is None:
            raise ValueError("Model not loaded. Call load() first.")
        
        try:
            # Ensure audio is mono
            if len(audio_data.shape) > 1:
                audio_data = audio_data.mean(axis=0)
            
            # Convert to float32
            audio_data = audio_data.astype(np.float32)
            
            # Process audio with feature extractor
            inputs = self.processor(
                audio_data, 
                sampling_rate=sampling_rate, 
                return_tensors="pt", 
                padding=True
            )
            
            # Make prediction
            with torch.no_grad():
                outputs = self.model(**inputs)
                predictions = torch.nn.functional.softmax(outputs.logits, dim=-1)
            
            # Get predicted emotion
            predicted_id = torch.argmax(predictions, dim=-1).item()
            predicted_emotion = self.emotion_labels[predicted_id]
            confidence = predictions[0][predicted_id].item()
            
            # Get all emotion probabilities
            emotion_scores = {}
            for i, emotion in self.emotion_labels.items():
                emotion_scores[emotion] = predictions[0][i].item()
            

            return {
                'predicted_emotion': predicted_emotion,
                'confidence': confidence,
                'all_emotions': emotion_scores
            }
            
        except Exception as e:
            raise Exception(f"Emotion prediction error: {str(e)}")