from flask import Flask, request, jsonify
import os
import numpy as np
import librosa
from werkzeug.utils import secure_filename
from models.nationality_model import NationalityModel
from models.age_and_gender_model import AgeGenderModel

app = Flask(__name__)

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'flac', 'm4a'}
SAMPLING_RATE = 16000

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Global model variables
age_gender_model = None
nationality_model = None

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def load_models():
    global age_gender_model, nationality_model
    
    try:
        # Load age & gender model
        print("Loading age & gender model...")
        age_gender_model = AgeGenderModel()
        age_gender_success = age_gender_model.load()
        
        if not age_gender_success:
            print("Failed to load age & gender model")
            return False
        
        # Load nationality model
        print("Loading nationality model...")
        nationality_model = NationalityModel()
        nationality_success = nationality_model.load()
        
        if not nationality_success:
            print("Failed to load nationality model")
            return False
            
        return True
    except Exception as e:
        print(f"Error loading models: {e}")
        return False

@app.route("/")
def home():
    return jsonify({
        "message": "Audio Analysis API - Age, Gender & Nationality Prediction",
        "models_loaded": {
            "age_gender": age_gender_model is not None and hasattr(age_gender_model, 'model') and age_gender_model.model is not None,
            "nationality": nationality_model is not None and hasattr(nationality_model, 'model') and nationality_model.model is not None
        },
        "endpoints": {
            "/predict_nationality": "POST - Upload audio file for nationality prediction",
            "/predict_all": "POST - Upload audio file for complete analysis (age, gender, nationality)",
        }
    })


@app.route("/predict_age_and_gender", methods=['POST'])
def predict_from_file():
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        return jsonify({"error": "Age & gender model not loaded"}), 500
    
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
            # Preprocess audio to model requirements
            processed_audio, processed_sr = preprocess_audio(audio_data, sr)
            predictions = age_gender_model.predict(processed_audio, processed_sr)
            os.remove(filepath)
            
            return jsonify({
                "success": True,
                "predictions": predictions
            })
            
        except Exception as e:
            # Clean up file if it exists
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Invalid file type"}), 400


@app.route("/predict_nationality", methods=['POST'])
def predict_nationality_from_file():
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        return jsonify({"error": "Nationality model not loaded"}), 500
    
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
            # Preprocess audio to model requirements
            processed_audio, processed_sr = preprocess_audio(audio_data, sr)
            predictions = nationality_model.predict(processed_audio, processed_sr)
            os.remove(filepath)
            
            return jsonify({
                "success": True,
                "predictions": predictions
            })
            
        except Exception as e:
            # Clean up file if it exists
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Invalid file type"}), 400


@app.route("/predict_all", methods=['POST'])
def predict_all_from_file():
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        return jsonify({"error": "Age & gender model not loaded"}), 500
    
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        return jsonify({"error": "Nationality model not loaded"}), 500
    
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
            
            # Preprocess audio to model requirements
            processed_audio, processed_sr = preprocess_audio(audio_data, sr)

            # Get both predictions
            age_gender_predictions = age_gender_model.predict(processed_audio, processed_sr)
            nationality_predictions = nationality_model.predict(processed_audio, processed_sr)
            
            os.remove(filepath)
            
            return jsonify({
                "success": True,
                "predictions": {
                    "demographics": age_gender_predictions,
                    "nationality": nationality_predictions
                }
            })
            
        except Exception as e:
            # Clean up file if it exists
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Invalid file type"}), 400


def preprocess_audio(audio_data, sr):
    if len(audio_data.shape) > 1:
        audio_data = librosa.to_mono(audio_data)
        
    if sr != SAMPLING_RATE:
        print(f"Resampling from {sr}Hz to {SAMPLING_RATE}Hz")
        audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=SAMPLING_RATE)
        
    audio_data = audio_data.astype(np.float32)
        
    return audio_data, SAMPLING_RATE
    

# Load models at startup
print("Loading models...")
if load_models():
    print("Starting Flask app...")
else:
    print("Failed to load models. Exiting.")
    exit(1)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)