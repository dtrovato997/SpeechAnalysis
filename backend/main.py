from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import os
import numpy as np
import librosa
from typing import Dict, Any
import logging
import time
from contextlib import asynccontextmanager
from models.nationality_model import NationalityModel
from models.age_and_gender_model import AgeGenderModel
from models.emotions_model import EmotionModel

# Configure logging with more detailed format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'flac', 'm4a'}
SAMPLING_RATE = 16000
MAX_DURATION_SECONDS = 120  # 2 minutes maximum

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Global model variables
age_gender_model = None
nationality_model = None
emotion_model = None

def allowed_file(filename: str) -> bool:
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def clip_audio_to_max_duration(audio_data: np.ndarray, sr: int, max_duration: int = MAX_DURATION_SECONDS) -> tuple[np.ndarray, bool]:
    current_duration = len(audio_data) / sr
    
    if current_duration <= max_duration:
        logger.info(f"Audio duration ({current_duration:.2f}s) is within limit ({max_duration}s) - no clipping needed")
        return audio_data, False
    
    # Calculate how many samples we need for the max duration
    max_samples = int(max_duration * sr)
    
    # Clip to first max_duration seconds
    clipped_audio = audio_data[:max_samples]
    
    logger.info(f"Audio clipped from {current_duration:.2f}s to {max_duration}s ({len(audio_data)} samples → {len(clipped_audio)} samples)")
    
    return clipped_audio, True

async def load_models() -> bool:
    global age_gender_model, nationality_model, emotion_model
    
    try:
        total_start_time = time.time()
        
        # Load age & gender model
        logger.info("Starting age & gender model loading...")
        age_start = time.time()
        age_gender_model = AgeGenderModel()
        age_gender_success = age_gender_model.load()
        age_end = time.time()
        
        if not age_gender_success:
            logger.error("Failed to load age & gender model")
            return False
        
        logger.info(f"Age & gender model loaded successfully in {age_end - age_start:.2f} seconds")
        
        # Load nationality model
        logger.info("Starting nationality model loading...")
        nationality_start = time.time()
        nationality_model = NationalityModel()
        nationality_success = nationality_model.load()
        nationality_end = time.time()
        
        if not nationality_success:
            logger.error("Failed to load nationality model")
            return False
            
        logger.info(f"Nationality model loaded successfully in {nationality_end - nationality_start:.2f} seconds")
        
        # Load emotion model
        logger.info("Starting emotion model loading...")
        emotion_start = time.time()
        emotion_model = EmotionModel()
        emotion_success = emotion_model.load()
        emotion_end = time.time()
        
        if not emotion_success:
            logger.error("Failed to load emotion model")
            return False
            
        logger.info(f"Emotion model loaded successfully in {emotion_end - emotion_start:.2f} seconds")
        
        total_end = time.time()
        logger.info(f"All models loaded successfully! Total time: {total_end - total_start_time:.2f} seconds")
        return True
    except Exception as e:
        logger.error(f"Error loading models: {e}")
        return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting FastAPI application...")
    startup_start = time.time()
    success = await load_models()
    startup_end = time.time()
    
    if not success:
        logger.error("Failed to load models. Application will not work properly.")
    else:
        logger.info(f"FastAPI application started successfully in {startup_end - startup_start:.2f} seconds")
    
    yield
    
    # Shutdown
    logger.info("Shutting down FastAPI application...")

# Create FastAPI app with lifespan events
app = FastAPI(
    title="Audio Analysis API",
    description="Audio analysis for age, gender, nationality, and emotion prediction",
    version="1.0.0",
    lifespan=lifespan
)

def preprocess_audio(audio_data: np.ndarray, sr: int) -> tuple[np.ndarray, int, bool]:
    preprocess_start = time.time()
    original_shape = audio_data.shape
    original_duration = len(audio_data) / sr
    logger.info(f"Starting audio preprocessing - Original shape: {original_shape}, Sample rate: {sr}Hz, Duration: {original_duration:.2f}s")
    
    # Convert to mono if stereo
    if len(audio_data.shape) > 1:
        mono_start = time.time()
        audio_data = librosa.to_mono(audio_data)
        mono_end = time.time()
        logger.info(f"Converted stereo to mono in {mono_end - mono_start:.3f} seconds - New shape: {audio_data.shape}")
    
    # Resample if needed
    if sr != SAMPLING_RATE:
        resample_start = time.time()
        logger.info(f"Resampling from {sr}Hz to {SAMPLING_RATE}Hz...")
        audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=SAMPLING_RATE)
        resample_end = time.time()
        logger.info(f"Resampling completed in {resample_end - resample_start:.3f} seconds")
        sr = SAMPLING_RATE
    else:
        logger.info(f"No resampling needed - already at {SAMPLING_RATE}Hz")
    
    # Clip audio to maximum duration if needed
    audio_data, was_clipped = clip_audio_to_max_duration(audio_data, sr)
    
    # Convert to float32
    audio_data = audio_data.astype(np.float32)
    
    preprocess_end = time.time()
    final_duration_seconds = len(audio_data) / sr
    logger.info(f"Audio preprocessing completed in {preprocess_end - preprocess_start:.3f} seconds")
    logger.info(f"Final audio: {audio_data.shape} samples, {final_duration_seconds:.2f} seconds duration")
    
    return audio_data, sr, was_clipped

async def process_audio_file(file: UploadFile) -> tuple[np.ndarray, int, bool]:
    process_start = time.time()
    logger.info(f"Processing uploaded file: {file.filename}")
    
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file selected")
    
    if not allowed_file(file.filename):
        logger.warning(f"Invalid file type uploaded: {file.filename}")
        raise HTTPException(status_code=400, detail="Invalid file type. Allowed: wav, mp3, flac, m4a")
    
    # Get file extension and log it
    file_ext = file.filename.rsplit('.', 1)[1].lower()
    logger.info(f"Processing {file_ext.upper()} file: {file.filename}")
    
    # Create a secure filename
    filename = f"temp_{int(time.time())}_{file.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    
    try:
        # Save uploaded file temporarily
        save_start = time.time()
        with open(filepath, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        save_end = time.time()
        
        file_size_mb = len(content) / (1024 * 1024)
        logger.info(f"File saved ({file_size_mb:.2f} MB) in {save_end - save_start:.3f} seconds")
        
        # Load and preprocess audio
        load_start = time.time()
        logger.info(f"Loading audio from {filepath}...")
        audio_data, sr = librosa.load(filepath, sr=None)
        load_end = time.time()
        logger.info(f"Audio loaded in {load_end - load_start:.3f} seconds")
        
        processed_audio, processed_sr, was_clipped = preprocess_audio(audio_data, sr)
        
        process_end = time.time()
        logger.info(f"Total file processing completed in {process_end - process_start:.3f} seconds")
        
        return processed_audio, processed_sr, was_clipped
        
    except Exception as e:
        logger.error(f"Error processing audio file {file.filename}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {str(e)}")
    finally:
        # Clean up temporary file
        if os.path.exists(filepath):
            os.remove(filepath)
            logger.info(f"Temporary file {filename} cleaned up")

@app.get("/")
async def root() -> Dict[str, Any]:
    logger.info("Root endpoint accessed")
    return {
        "message": "Audio Analysis API - Age, Gender, Nationality & Emotion Prediction",
        "max_audio_duration": f"{MAX_DURATION_SECONDS} seconds (files longer than this will be automatically clipped)",
        "models_loaded": {
            "age_gender": age_gender_model is not None and hasattr(age_gender_model, 'model') and age_gender_model.model is not None,
            "nationality": nationality_model is not None and hasattr(nationality_model, 'model') and nationality_model.model is not None,
            "emotion": emotion_model is not None and hasattr(emotion_model, 'model') and emotion_model.model is not None
        },
        "endpoints": {
            "/predict_age_and_gender": "POST - Upload audio file for age and gender prediction",
            "/predict_nationality": "POST - Upload audio file for nationality prediction",
            "/predict_emotion": "POST - Upload audio file for emotion prediction",
            "/predict_all": "POST - Upload audio file for complete analysis (age, gender, nationality, emotion)",
        },
        "emotions": ["angry", "disgust", "fear", "happy", "neutral", "sad", "surprise"],
        "docs": "/docs - Interactive API documentation",
        "openapi": "/openapi.json - OpenAPI schema"
    }

@app.post("/predict_age_and_gender")
async def predict_age_and_gender(file: UploadFile = File(...)) -> Dict[str, Any]:
    endpoint_start = time.time()
    logger.info(f"Age & Gender prediction requested for file: {file.filename}")
    
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        logger.error("Age & gender model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Age & gender model not loaded")
    
    try:
        processed_audio, processed_sr, was_clipped = await process_audio_file(file)
        
        # Make prediction
        prediction_start = time.time()
        logger.info("Starting age & gender prediction...")
        predictions = age_gender_model.predict(processed_audio, processed_sr)
        prediction_end = time.time()
        
        logger.info(f"Age & gender prediction completed in {prediction_end - prediction_start:.3f} seconds")
        logger.info(f"Predicted age: {predictions['age']['predicted_age']:.1f} years")
        logger.info(f"Predicted gender: {predictions['gender']['predicted_gender']} (confidence: {predictions['gender']['confidence']:.3f})")
        
        endpoint_end = time.time()
        logger.info(f"Total age & gender endpoint processing time: {endpoint_end - endpoint_start:.3f} seconds")
        
        response = {
            "success": True,
            "predictions": predictions,
            "processing_time": round(endpoint_end - endpoint_start, 3),
            "audio_info": {
                "was_clipped": was_clipped,
                "max_duration_seconds": MAX_DURATION_SECONDS
            }
        }
        
        if was_clipped:
            response["warning"] = f"Audio was longer than {MAX_DURATION_SECONDS} seconds and was automatically clipped to the first {MAX_DURATION_SECONDS} seconds for analysis."
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in age & gender prediction: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_nationality")
async def predict_nationality(file: UploadFile = File(...)) -> Dict[str, Any]:
    endpoint_start = time.time()
    logger.info(f"Nationality prediction requested for file: {file.filename}")
    
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        logger.error("Nationality model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Nationality model not loaded")
    
    try:
        processed_audio, processed_sr, was_clipped = await process_audio_file(file)
        
        # Make prediction
        prediction_start = time.time()
        logger.info("Starting nationality prediction...")
        predictions = nationality_model.predict(processed_audio, processed_sr)
        prediction_end = time.time()
        
        logger.info(f"Nationality prediction completed in {prediction_end - prediction_start:.3f} seconds")
        logger.info(f"Predicted language: {predictions['predicted_language']} (confidence: {predictions['confidence']:.3f})")
        logger.info(f"Top 3 languages: {[lang['language_code'] for lang in predictions['top_languages'][:3]]}")
        
        endpoint_end = time.time()
        logger.info(f"Total nationality endpoint processing time: {endpoint_end - endpoint_start:.3f} seconds")
        
        response = {
            "success": True,
            "predictions": predictions,
            "processing_time": round(endpoint_end - endpoint_start, 3),
            "audio_info": {
                "was_clipped": was_clipped,
                "max_duration_seconds": MAX_DURATION_SECONDS
            }
        }
        
        if was_clipped:
            response["warning"] = f"Audio was longer than {MAX_DURATION_SECONDS} seconds and was automatically clipped to the first {MAX_DURATION_SECONDS} seconds for analysis."
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in nationality prediction: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_emotion")
async def predict_emotion(file: UploadFile = File(...)) -> Dict[str, Any]:
    endpoint_start = time.time()
    logger.info(f"Emotion prediction requested for file: {file.filename}")
    
    if emotion_model is None or not hasattr(emotion_model, 'model') or emotion_model.model is None:
        logger.error("Emotion model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Emotion model not loaded")
    
    try:
        processed_audio, processed_sr, was_clipped = await process_audio_file(file)
        
        # Make prediction
        prediction_start = time.time()
        logger.info("Starting emotion prediction...")
        predictions = emotion_model.predict(processed_audio, processed_sr)
        prediction_end = time.time()
        
        logger.info(f"Emotion prediction completed in {prediction_end - prediction_start:.3f} seconds")
        logger.info(f"Predicted emotion: {predictions['predicted_emotion']} (confidence: {predictions['confidence']:.3f})")
        logger.info(f"Top 3 emotions: {[emo['emotion'] for emo in predictions['top_emotions'][:3]]}")
        
        endpoint_end = time.time()
        logger.info(f"Total emotion endpoint processing time: {endpoint_end - endpoint_start:.3f} seconds")
        
        response = {
            "success": True,
            "predictions": predictions,
            "processing_time": round(endpoint_end - endpoint_start, 3),
            "audio_info": {
                "was_clipped": was_clipped,
                "max_duration_seconds": MAX_DURATION_SECONDS
            }
        }
        
        if was_clipped:
            response["warning"] = f"Audio was longer than {MAX_DURATION_SECONDS} seconds and was automatically clipped to the first {MAX_DURATION_SECONDS} seconds for analysis."
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in emotion prediction: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_all")
async def predict_all(file: UploadFile = File(...)) -> Dict[str, Any]:
    endpoint_start = time.time()
    logger.info(f"Complete analysis requested for file: {file.filename}")
    
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        logger.error("Age & gender model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Age & gender model not loaded")
    
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        logger.error("Nationality model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Nationality model not loaded")
    
    if emotion_model is None or not hasattr(emotion_model, 'model') or emotion_model.model is None:
        logger.error("Emotion model not loaded - returning 500 error")
        raise HTTPException(status_code=500, detail="Emotion model not loaded")
    
    try:
        processed_audio, processed_sr, was_clipped = await process_audio_file(file)
        
        age_prediction_start = time.time()
        logger.info("Starting age & gender prediction for complete analysis...")
        age_gender_predictions = age_gender_model.predict(processed_audio, processed_sr)
        age_prediction_end = time.time()
        logger.info(f"Age & gender prediction completed in {age_prediction_end - age_prediction_start:.3f} seconds")
        
        nationality_prediction_start = time.time()
        logger.info("Starting nationality prediction for complete analysis...")
        nationality_predictions = nationality_model.predict(processed_audio, processed_sr)
        nationality_prediction_end = time.time()
        logger.info(f"Nationality prediction completed in {nationality_prediction_end - nationality_prediction_start:.3f} seconds")

        emotion_prediction_start = time.time()
        logger.info("Starting emotion prediction for complete analysis...")
        emotion_predictions = emotion_model.predict(processed_audio, processed_sr)
        emotion_prediction_end = time.time()
        logger.info(f"Emotion prediction completed in {emotion_prediction_end - emotion_prediction_start:.3f} seconds")
        
        logger.info(f"Complete analysis results:")
        logger.info(f"  - Age: {age_gender_predictions['age']['predicted_age']:.1f} years")
        logger.info(f"  - Gender: {age_gender_predictions['gender']['predicted_gender']} (confidence: {age_gender_predictions['gender']['confidence']:.3f})")
        logger.info(f"  - Language: {nationality_predictions['predicted_language']} (confidence: {nationality_predictions['confidence']:.3f})")
        logger.info(f"  - Emotion: {emotion_predictions['predicted_emotion']}")
        
        total_prediction_time = (age_prediction_end - age_prediction_start) + (nationality_prediction_end - nationality_prediction_start) + (emotion_prediction_end - emotion_prediction_start)
        endpoint_end = time.time()
        
        logger.info(f"Total prediction time: {total_prediction_time:.3f} seconds")
        logger.info(f"Total complete analysis endpoint processing time: {endpoint_end - endpoint_start:.3f} seconds")
        
        response = {
            "success": True,
            "predictions": {
                "demographics": age_gender_predictions,
                "nationality": nationality_predictions,
                "emotion": emotion_predictions
            },
            "processing_time": {
                "total": round(endpoint_end - endpoint_start, 3),
                "age_gender": round(age_prediction_end - age_prediction_start, 3),
                "nationality": round(nationality_prediction_end - nationality_prediction_start, 3),
                "emotion": round(emotion_prediction_end - emotion_prediction_start, 3)
            },
            "audio_info": {
                "was_clipped": was_clipped,
                "max_duration_seconds": MAX_DURATION_SECONDS
            }
        }
        
        if was_clipped:
            response["warning"] = f"Audio was longer than {MAX_DURATION_SECONDS} seconds and was automatically clipped to the first {MAX_DURATION_SECONDS} seconds for analysis."
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in complete analysis: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 7860))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        reload=False,  # Set to True for development
        log_level="info"
    )