import audeer
from flask import Flask, request, jsonify
import os
import numpy as np
import audonnx
import audinterface
import librosa
import io
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'flac', 'm4a'}
MODEL_PATH = './models'  # Relative to backend directory
SAMPLING_RATE = 16000

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs('./models', exist_ok=True)


model = None
interface = None

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Download the model if it doesn't exist
def download_model_if_needed():
    model_onnx = os.path.join(MODEL_PATH, 'model.onnx')
    model_yaml = os.path.join(MODEL_PATH, 'model.yaml')
    
    if os.path.exists(model_onnx) and os.path.exists(model_yaml):
        print("Model files already exist, skipping download.")
        return True
    
    print("Model files not found. Downloading...")
    
    try:
        cache_root = 'cache'
        audeer.mkdir(cache_root)
        audeer.mkdir(MODEL_PATH)
        
        def cache_path(file):
            return os.path.join(cache_root, file)
        
        url = 'https://zenodo.org/record/7761387/files/w2v2-L-robust-24-age-gender.728d5a4c-1.1.1.zip'
        dst_path = cache_path('model.zip')
        
        if not os.path.exists(dst_path):
            print(f"Downloading model from {url}...")
            audeer.download_url(url, dst_path, verbose=True)
        
        print(f"Extracting model to {MODEL_PATH}...")
        audeer.extract_archive(dst_path, MODEL_PATH, verbose=True)

        if os.path.exists(model_onnx) and os.path.exists(model_yaml):
            print("Model downloaded and extracted successfully!")

            if os.path.exists(dst_path):
                os.remove(dst_path)
            return True
        else:
            print("Model extraction failed, files not found after extraction")
            return False
            
    except Exception as e:
        print(f"Error downloading model: {e}")
        return False
    
def load_model():
    global model, interface
    
    try:
        # Download model if needed
        if not download_model_if_needed():
            print("Failed to download model")
            return False
        
        # Load the audonnx model
        print("Loading model...")
        model = audonnx.load(MODEL_PATH)
        
        # Create the audinterface Feature interface
        outputs = ['logits_age', 'logits_gender']
        interface = audinterface.Feature(
            model.labels(outputs),
            process_func=model,
            process_func_args={
                'outputs': outputs,
                'concat': True,
            },
            sampling_rate=SAMPLING_RATE,
            resample=False,  # We handle resampling manually
            verbose=False,
        )
        print("Model loaded successfully!")
        return True
    except Exception as e:
        print(f"Error loading model: {e}")
        return False

#convert audio to mono, resample to 16kHz, convert to float32
def preprocess_audio(audio_data, sr):
    if len(audio_data.shape) > 1:
        audio_data = librosa.to_mono(audio_data)
    
    if sr != SAMPLING_RATE:
        print(f"Resampling from {sr}Hz to {SAMPLING_RATE}Hz")
        audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=SAMPLING_RATE)
    
    audio_data = audio_data.astype(np.float32)
    
    return audio_data, SAMPLING_RATE

def predict_age_gender(audio_data, sr):
    try:
        # Preprocess audio to model requirements
        processed_audio, processed_sr = preprocess_audio(audio_data, sr)

        # Process with the interface, then extract logits scores, then process them
        # Use softmax to convert logits to probabilities for Gender
        # and normalize age score to 0-100
        result = interface.process_signal(processed_audio, processed_sr)
        

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
        
        # Find most likely gender, this is the effective prediction
        predicted_gender = gender_labels[np.argmax(gender_probs)]
        max_probability = float(np.max(gender_probs))
        
        return {
            'age': {
                'predicted_age': float(predicted_age),
                'raw_score': float(age_score),
                'note': 'Age score represents normalized value (0-1 = 0-100 years)'
            },
            'gender': {
                'predicted_gender': predicted_gender,
                'probabilities': gender_probabilities,
                'confidence': max_probability,
                'raw_logits': {k: float(v) for k, v in gender_logits.items()},
                'note': 'Probabilities computed from logits using softmax'
            },
            'audio_processing': {
                'original_sr': int(sr),
                'processed_sr': int(processed_sr),
                'was_resampled': sr != processed_sr,
                'duration_seconds': len(processed_audio) / processed_sr
            }
        }
    except Exception as e:
        raise Exception(f"Prediction error: {str(e)}")
    

@app.route("/")
def home():
    return jsonify({
        "message": "wav2vec 2.0 Age & Gender Prediction API",
        "model_loaded": model is not None,
        "endpoints": {
            "/predict": "POST - Upload audio file for prediction",
            "/predict_array": "POST - Send audio array for prediction",
            "/health": "GET - Check API health"
        }
    })

#This is the real endpoint for prediction which expects an audio file with a certain format
#It saves the file into a temporary directory and then loads it for processing
#then removes it after the processing is done
@app.route("/predict", methods=['POST'])
def predict_from_file():
    """
    Predict age and gender from uploaded audio file
    """
    if model is None:
        return jsonify({"error": "Model not loaded"}), 500
    
    # Check if file is present
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400
    
    file = request.files['file']
    
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400
    
    if file and allowed_file(file.filename):
        try:
            filename = secure_filename(file.filename)
            filepath = os.path.join(UPLOAD_FOLDER, filename)
            file.save(filepath)
            audio_data, sr = librosa.load(filepath, sr=None)
            predictions = predict_age_gender(audio_data, sr)
            os.remove(filepath)
            
            return jsonify({
                "success": True,
                "predictions": predictions,
                "file_info": {
                    "filename": filename,
                    "duration_seconds": len(audio_data) / sr,
                    "sampling_rate": sr
                }
            })
            
        except Exception as e:
            # Clean up file if it exists
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Invalid file type"}), 400

#test with random signal copied from the original notebook
@app.route("/test_random", methods=['GET'])
def test_with_random():
    if model is None:
        return jsonify({"error": "Model not loaded"}), 500
    
    try:
        # Generate random noise for testing
        np.random.seed(42)  # For reproducible results
        signal = np.random.normal(size=SAMPLING_RATE).astype(np.float32)
        
        predictions = predict_age_gender(signal, SAMPLING_RATE)
        
        return jsonify({
            "success": True,
            "predictions": predictions,
            "note": "This is a test with random noise - predictions may not be meaningful"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Load model at startup
print("Loading wav2vec 2.0 model...")
if load_model():
    print("Starting Flask app...")
else:
    print("Failed to load model. Exiting.")
    exit(1)