from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import os
import numpy as np
import librosa
from typing import Dict, Any
import logging
from contextlib import asynccontextmanager
from models.nationality_model import NationalityModel
from models.age_and_gender_model import AgeGenderModel

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'flac', 'm4a'}
SAMPLING_RATE = 16000

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Global model variables
age_gender_model = None
nationality_model = None

def allowed_file(filename: str) -> bool:
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

async def load_models() -> bool:
    global age_gender_model, nationality_model
    
    try:
        # Load age & gender model
        logger.info("Loading age & gender model...")
        age_gender_model = AgeGenderModel()
        age_gender_success = age_gender_model.load()
        
        if not age_gender_success:
            logger.error("Failed to load age & gender model")
            return False
        
        # Load nationality model
        logger.info("Loading nationality model...")
        nationality_model = NationalityModel()
        nationality_success = nationality_model.load()
        
        if not nationality_success:
            logger.error("Failed to load nationality model")
            return False
            
        logger.info("All models loaded successfully!")
        return True
    except Exception as e:
        logger.error(f"Error loading models: {e}")
        return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting FastAPI application...")
    success = await load_models()
    if not success:
        logger.error("Failed to load models. Application will not work properly.")
    
    yield
    
    # Shutdown
    logger.info("Shutting down FastAPI application...")

# Create FastAPI app with lifespan events
app = FastAPI(
    title="Audio Analysis API",
    description="audio analysis for age, gender, and nationality prediction",
    version="1.0.0",
    lifespan=lifespan
)

def preprocess_audio(audio_data: np.ndarray, sr: int) -> tuple[np.ndarray, int]:
    if len(audio_data.shape) > 1:
        audio_data = librosa.to_mono(audio_data)
        
    if sr != SAMPLING_RATE:
        logger.info(f"Resampling from {sr}Hz to {SAMPLING_RATE}Hz")
        audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=SAMPLING_RATE)
        
    audio_data = audio_data.astype(np.float32)
        
    return audio_data, SAMPLING_RATE

async def process_audio_file(file: UploadFile) -> tuple[np.ndarray, int]:
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file selected")
    
    if not allowed_file(file.filename):
        raise HTTPException(status_code=400, detail="Invalid file type. Allowed: wav, mp3, flac, m4a")
    
    # Create a secure filename
    filename = f"temp_{file.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    
    try:
        # Save uploaded file temporarily
        with open(filepath, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Load and preprocess audio
        audio_data, sr = librosa.load(filepath, sr=None)
        processed_audio, processed_sr = preprocess_audio(audio_data, sr)
        
        return processed_audio, processed_sr
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {str(e)}")
    finally:
        # Clean up temporary file
        if os.path.exists(filepath):
            os.remove(filepath)

@app.get("/")
async def root() -> Dict[str, Any]:
    return {
        "message": "Audio Analysis API - Age, Gender & Nationality Prediction",
        "models_loaded": {
            "age_gender": age_gender_model is not None and hasattr(age_gender_model, 'model') and age_gender_model.model is not None,
            "nationality": nationality_model is not None and hasattr(nationality_model, 'model') and nationality_model.model is not None
        },
        "endpoints": {
            "/predict_age_and_gender": "POST - Upload audio file for age and gender prediction",
            "/predict_nationality": "POST - Upload audio file for nationality prediction",
            "/predict_all": "POST - Upload audio file for complete analysis (age, gender, nationality)",
        },
        "docs": "/docs - Interactive API documentation",
        "openapi": "/openapi.json - OpenAPI schema"
    }

@app.get("/health")
async def health_check() -> Dict[str, str]:
    return {"status": "healthy"}

@app.post("/predict_age_and_gender")
async def predict_age_and_gender(file: UploadFile = File(...)) -> Dict[str, Any]:
    """Predict age and gender from uploaded audio file."""
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        raise HTTPException(status_code=500, detail="Age & gender model not loaded")
    
    try:
        processed_audio, processed_sr = await process_audio_file(file)
        predictions = age_gender_model.predict(processed_audio, processed_sr)
        
        return {
            "success": True,
            "predictions": predictions
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_nationality")
async def predict_nationality(file: UploadFile = File(...)) -> Dict[str, Any]:
    """Predict nationality/language from uploaded audio file."""
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        raise HTTPException(status_code=500, detail="Nationality model not loaded")
    
    try:
        processed_audio, processed_sr = await process_audio_file(file)
        predictions = nationality_model.predict(processed_audio, processed_sr)
        
        return {
            "success": True,
            "predictions": predictions
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict_all")
async def predict_all(file: UploadFile = File(...)) -> Dict[str, Any]:
    if age_gender_model is None or not hasattr(age_gender_model, 'model') or age_gender_model.model is None:
        raise HTTPException(status_code=500, detail="Age & gender model not loaded")
    
    if nationality_model is None or not hasattr(nationality_model, 'model') or nationality_model.model is None:
        raise HTTPException(status_code=500, detail="Nationality model not loaded")
    
    try:
        processed_audio, processed_sr = await process_audio_file(file)
        
        # Get both predictions
        age_gender_predictions = age_gender_model.predict(processed_audio, processed_sr)
        nationality_predictions = nationality_model.predict(processed_audio, processed_sr)
        
        return {
            "success": True,
            "predictions": {
                "demographics": age_gender_predictions,
                "nationality": nationality_predictions
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        reload=False,  # Set to True for development
        log_level="info"
    )