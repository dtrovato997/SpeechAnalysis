import 'dart:io';
import 'dart:isolate';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter/services.dart';
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

// Data class for passing data to isolate
class InferenceRequest {
  final String audioFilePath;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  InferenceRequest({
    required this.audioFilePath,
    required this.sendPort,
    required this.rootIsolateToken,
  });
}

// Isolate entry point - this runs in a separate thread
void _inferenceIsolate(InferenceRequest request) async {
  // Register the root isolate token to access platform channels
  BackgroundIsolateBinaryMessenger.ensureInitialized(request.rootIsolateToken);

  try {
    // Initialize ONNX Runtime in the isolate
    final onnxRuntime = OnnxRuntime();
    
    // Load the emotion model
    final emotionSession = await onnxRuntime.createSessionFromAsset(
      'assets/models/emotion_model.onnx',
    );

    // Read and preprocess audio
    final audioData = await _preprocessAudioInIsolate(request.audioFilePath);
    if (audioData == null) {
      request.sendPort.send({'error': 'Failed to preprocess audio'});
      return;
    }

    // Run predictions
    final emotion = await _predictEmotionInIsolate(audioData, emotionSession);
    
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

    // Send results back to main isolate
    request.sendPort.send({
      'success': true,
      'demographics': demographics,
      'nationality': nationality,
      'emotion': emotion,
    });

    // Clean up
    emotionSession.close();
  } catch (e) {
    request.sendPort.send({'error': e.toString()});
  }
}

// Helper functions for isolate (duplicated because isolates don't share memory)
Future<Float32List?> _preprocessAudioInIsolate(String audioFilePath) async {
  try {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      return null;
    }

    final audioBytes = await file.readAsBytes();
    
    // Skip WAV header and convert to float samples
    const headerSize = 44;
    const maxSamples = 16000 * 30; // 30 seconds at 16kHz
    
    if (audioBytes.length <= headerSize) {
      return null;
    }

    final audioSamples = <double>[];
    for (int i = headerSize; i < audioBytes.length - 1; i += 2) {
      final sample = (audioBytes[i] | (audioBytes[i + 1] << 8));
      final normalizedSample = sample / 32768.0;
      audioSamples.add(normalizedSample);
    }

    // Pad or trim
    if (audioSamples.length > maxSamples) {
      audioSamples.removeRange(maxSamples, audioSamples.length);
    } else {
      while (audioSamples.length < maxSamples) {
        audioSamples.add(0.0);
      }
    }

    return Float32List.fromList(audioSamples);
  } catch (e) {
    return null;
  }
}

Future<EmotionPrediction?> _predictEmotionInIsolate(
  Float32List audioData,
  OrtSession emotionSession,
) async {
  try {
    final inputShape = [1, audioData.length];
    final inputValue = await OrtValue.fromList(audioData, inputShape);
    
    final inputs = {'input_values': inputValue};
    final outputs = await emotionSession.run(inputs);
    
    final emotionOutput = await outputs['logits']?.asList();
    if (emotionOutput == null) return null;
    
    List<dynamic> logits;
    if (emotionOutput.isNotEmpty && emotionOutput[0] is List) {
      logits = emotionOutput[0] as List<dynamic>;
    } else {
      logits = emotionOutput;
    }
    
    final emotionLabels = [
      'angry', 'calms', 'disgust', 'fearful',
      'happy', 'neutral', 'sad', 'surprised'
    ];
    
    final emotionProbs = <String, double>{};
    final expValues = <double>[];
    double maxLogit = double.negativeInfinity;
    
    for (int i = 0; i < logits.length && i < emotionLabels.length; i++) {
      final value = (logits[i] as num).toDouble();
      if (value > maxLogit) maxLogit = value;
    }
    
    double sumExp = 0.0;
    for (int i = 0; i < logits.length && i < emotionLabels.length; i++) {
      final value = (logits[i] as num).toDouble();
      final exp = dart_math.exp(value - maxLogit);
      expValues.add(exp);
      sumExp += exp;
    }
    
    for (int i = 0; i < expValues.length; i++) {
      emotionProbs[emotionLabels[i]] = expValues[i] / sumExp;
    }
    
    final topEmotion = emotionProbs.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    
    return EmotionPrediction(
      predictedEmotion: topEmotion.key,
      confidence: topEmotion.value,
      allEmotions: emotionProbs,
    );
  } catch (e) {
    return null;
  }
}

/// Service for running local ONNX model inference on audio files
class LocalInferenceService {
  static final LocalInferenceService _instance = LocalInferenceService._internal();
  factory LocalInferenceService() => _instance;
  LocalInferenceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      _logger.info('LocalInferenceService already initialized');
      return true;
    }

    try {
      _logger.info('Initializing LocalInferenceService...');
      // Just check if models exist
      final emotionModelExists = await _assetExists('assets/models/emotion_model.onnx');
      
      if (!emotionModelExists) {
        _logger.error('Emotion model not found');
        return false;
      }

      _isInitialized = true;
      _logger.info('LocalInferenceService initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize LocalInferenceService', e, stackTrace);
      return false;
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

  /// Run complete prediction on audio file using isolate
  Future<CompletePrediction?> predictAll(String audioFilePath) async {
    if (!_isInitialized) {
      _logger.error('LocalInferenceService not initialized');
      return null;
    }

    try {
      _logger.info('Starting local inference for: $audioFilePath');

      // Create a receive port for getting results from isolate
      final receivePort = ReceivePort();
      
      // Get root isolate token for platform channel access
      final rootIsolateToken = RootIsolateToken.instance!;

      // Create request data
      final request = InferenceRequest(
        audioFilePath: audioFilePath,
        sendPort: receivePort.sendPort,
        rootIsolateToken: rootIsolateToken,
      );

      // Spawn isolate to run inference
      await Isolate.spawn(_inferenceIsolate, request);

      // Wait for result from isolate
      final result = await receivePort.first as Map<String, dynamic>;
      
      // Close the receive port
      receivePort.close();

      // Check for errors
      if (result.containsKey('error')) {
        _logger.error('Inference isolate error: ${result['error']}');
        return null;
      }

      // Parse results
      if (result['success'] == true) {
        final demographics = result['demographics'];
        final nationality = result['nationality'];
        final emotion = result['emotion'];

        if (demographics == null || nationality == null || emotion == null) {
          _logger.error('Failed to parse prediction results');
          return null;
        }

        final prediction = CompletePrediction(
          demographics: demographics,
          nationality: nationality,
          emotion: emotion,
        );

        _logger.info('Local inference completed successfully');
        return prediction;
      }

      return null;
    } catch (e, stackTrace) {
      _logger.error('Error during local inference', e, stackTrace);
      return null;
    }
  }

  /// Check if local inference is available
  bool get isAvailable => _isInitialized;

  /// Get available models
  Map<String, bool> get availableModels => {
    'age_gender': false, // Not implemented
    'nationality': false, // Not implemented
    'emotion': _isInitialized,
  };

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _logger.info('Disposing LocalInferenceService...');
      _isInitialized = false;
      _logger.info('LocalInferenceService disposed');
    } catch (e, stackTrace) {
      _logger.error('Error disposing LocalInferenceService', e, stackTrace);
    }
  }
}