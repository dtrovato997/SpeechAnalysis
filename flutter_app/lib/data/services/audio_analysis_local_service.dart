import 'dart:io';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

/// Service for running local ONNX model inference on audio files
class LocalInferenceService {
  static final LocalInferenceService _instance = LocalInferenceService._internal();
  factory LocalInferenceService() => _instance;
  LocalInferenceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  OrtSession? _emotionSession;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      _logger.info('LocalInferenceService already initialized');
      return true;
    }

    try {
      _logger.info('Initializing LocalInferenceService...');
      
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();
      
      // Check if models exist
      final emotionModelExists = await _assetExists('assets/models/emotion_model.onnx');
      
      if (!emotionModelExists) {
        _logger.error('Emotion model not found');
        OrtEnv.instance.release();
        return false;
      }

      // Load the emotion model
      await _loadEmotionModel();

      _isInitialized = true;
      _logger.info('LocalInferenceService initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize LocalInferenceService', e, stackTrace);
      // Clean up on failure
      await _cleanup();
      return false;
    }
  }

  /// Load the emotion model
  Future<void> _loadEmotionModel() async {
    try {
      const assetFileName = 'assets/models/emotion_model.onnx';
      final rawAssetFile = await rootBundle.load(assetFileName);
      final bytes = rawAssetFile.buffer.asUint8List();
      
      final sessionOptions = OrtSessionOptions();
      _emotionSession = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();
      
      _logger.info('Emotion model loaded successfully');
    } catch (e) {
      _logger.error('Failed to load emotion model: $e');
      rethrow;
    }
  }

  /// Check if an asset exists
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Preprocess audio file to the required format
  Future<Float32List?> _preprocessAudio(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        _logger.error('Audio file not found: $audioFilePath');
        return null;
      }

      final audioBytes = await file.readAsBytes();
      
      // Skip WAV header and convert to float samples
      const headerSize = 44;
      const maxSamples = 16000 * 30; // 30 seconds at 16kHz
      
      if (audioBytes.length <= headerSize) {
        _logger.error('Audio file too small');
        return null;
      }

      final audioSamples = <double>[];
      for (int i = headerSize; i < audioBytes.length - 1; i += 2) {
        final sample = (audioBytes[i] | (audioBytes[i + 1] << 8));
        final normalizedSample = sample / 32768.0;
        audioSamples.add(normalizedSample);
      }

      // Pad or trim to exact size
      if (audioSamples.length > maxSamples) {
        audioSamples.removeRange(maxSamples, audioSamples.length);
      } else {
        while (audioSamples.length < maxSamples) {
          audioSamples.add(0.0);
        }
      }

      _logger.debug('Audio preprocessed: ${audioSamples.length} samples');
      return Float32List.fromList(audioSamples);
    } catch (e, stackTrace) {
      _logger.error('Error preprocessing audio', e, stackTrace);
      return null;
    }
  }

  /// Run emotion prediction on preprocessed audio data
  Future<EmotionPrediction?> _predictEmotion(Float32List audioData) async {
    if (_emotionSession == null) {
      _logger.error('Emotion model not loaded');
      return null;
    }

    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;
    
    try {
      final inputShape = [1, audioData.length];
      
      // Create input tensor
      inputTensor = OrtValueTensor.createTensorWithDataList(audioData, inputShape);
      final inputs = {'input_values': inputTensor};
      
      // Create run options
      runOptions = OrtRunOptions();
      
      // Run inference (this automatically uses isolates if needed)
      outputs = await _emotionSession!.runAsync(runOptions, inputs);
      
      if (outputs == null || outputs.isEmpty) {
        _logger.error('No outputs from emotion model');
        return null;
      }
      
      // Get logits output
      final logitsOutput = outputs[0];
      if (logitsOutput == null) {
        _logger.error('Logits output is null');
        return null;
      }
      
      final logitsData = logitsOutput.value as List<List<double>>;
      final logits = logitsData[0]; // Assuming batch size of 1
      
      final emotionLabels = [
        'angry', 'calms', 'disgust', 'fearful',
        'happy', 'neutral', 'sad', 'surprised'
      ];
      
      // Apply softmax to get probabilities
      final emotionProbs = _applySoftmax(logits, emotionLabels);
      
      final topEmotion = emotionProbs.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      
      _logger.info('Emotion prediction completed: ${topEmotion.key} (${topEmotion.value.toStringAsFixed(3)})');
      
      return EmotionPrediction(
        predictedEmotion: topEmotion.key,
        confidence: topEmotion.value,
        allEmotions: emotionProbs,
      );
    } catch (e, stackTrace) {
      _logger.error('Error during emotion prediction', e, stackTrace);
      return null;
    } finally {
      // Clean up resources
      inputTensor?.release();
      runOptions?.release();
      outputs?.forEach((output) => output?.release());
    }
  }

  /// Apply softmax function to convert logits to probabilities
  Map<String, double> _applySoftmax(List<double> logits, List<String> labels) {
    final emotionProbs = <String, double>{};
    final expValues = <double>[];
    
    // Find max for numerical stability
    double maxLogit = logits.reduce(dart_math.max);
    
    // Calculate exp values
    double sumExp = 0.0;
    for (int i = 0; i < logits.length && i < labels.length; i++) {
      final exp = dart_math.exp(logits[i] - maxLogit);
      expValues.add(exp);
      sumExp += exp;
    }
    
    // Normalize to get probabilities
    for (int i = 0; i < expValues.length; i++) {
      emotionProbs[labels[i]] = expValues[i] / sumExp;
    }
    
    return emotionProbs;
  }

  /// Run complete prediction on audio file
  Future<CompletePrediction?> predictAll(String audioFilePath) async {
    if (!_isInitialized) {
      _logger.error('LocalInferenceService not initialized');
      return null;
    }

    try {
      _logger.info('Starting local inference for: $audioFilePath');

      // Preprocess audio
      final audioData = await _preprocessAudio(audioFilePath);
      if (audioData == null) {
        _logger.error('Failed to preprocess audio');
        return null;
      }

      // Run emotion prediction
      final emotion = await _predictEmotion(audioData);
      if (emotion == null) {
        _logger.error('Failed to predict emotion');
        return null;
      }
      
      // For demo purposes, create dummy age/gender/nationality predictions
      final demographics = AgeGenderPrediction(
        age: AgePrediction(predictedAge: 25.0),
        gender: GenderPrediction(
          predictedGender: "M",
          probabilities: {'M': 0.75, 'F': 0.25},
          confidence: 0.75,
        ),
      );
      
      final nationality = NationalityPrediction(
        predictedLanguage: "ita",
        confidence: 0.99,
        topLanguages: [],
      );

      final prediction = CompletePrediction(
        demographics: demographics,
        nationality: nationality,
        emotion: emotion,
      );

      _logger.info('Local inference completed successfully');
      return prediction;
    } catch (e, stackTrace) {
      _logger.error('Error during local inference', e, stackTrace);
      return null;
    }
  }

  /// Check if local inference is available
  bool get isAvailable => _isInitialized && _emotionSession != null;

  /// Get available models
  Map<String, bool> get availableModels => {
    'age_gender': false, // Not implemented
    'nationality': false, // Not implemented
    'emotion': _emotionSession != null,
  };

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      _emotionSession?.release();
      _emotionSession = null;
      
      if (_isInitialized) {
        OrtEnv.instance.release();
      }
    } catch (e) {
      _logger.warning('Error during cleanup: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _logger.info('Disposing LocalInferenceService...');
      await _cleanup();
      _isInitialized = false;
      _logger.info('LocalInferenceService disposed');
    } catch (e, stackTrace) {
      _logger.error('Error disposing LocalInferenceService', e, stackTrace);
    }
  }
}