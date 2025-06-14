import 'dart:io';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;
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

  // Audio processing constants
  static const int _targetSampleRate = 16000;
  static const int _maxDurationSeconds = 120; // 2 minutes

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
      var providers = OrtEnv.instance.availableProviders();
      
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
      sessionOptions.appendNnapiProvider(NnapiFlags.cpuDisabled);
      sessionOptions.appendXnnpackProvider();
      sessionOptions.appendCPUProvider(CPUFlags.useNone);
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

  /// Get a temporary file path for audio processing
  String _getTempAudioPath(String originalPath) {
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'audio_${timestamp}_processed.pcm';
    return path.join(tempDir.path, filename);
  }

  /// Check if the audio file format is supported
  bool _isSupportedFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.mp3', '.wav', '.m4a'].contains(extension);
  }

  /// Process audio file with FFmpeg and extract raw audio data
  Future<Float32List?> _processAudioWithFFmpeg(String inputPath) async {
    String? outputPath;
    
    try {
      if (!_isSupportedFormat(inputPath)) {
        _logger.error('Unsupported audio format: ${path.extension(inputPath)}');
        return null;
      }

      outputPath = _getTempAudioPath(inputPath);
      
      // FFmpeg command to:
      // - Convert to raw PCM format (no headers)
      // - Resample to 16kHz
      // - Convert to mono
      // - Normalize audio levels
      // - Limit duration to 2 minutes
      // - Output as 32-bit float PCM (little-endian)
      final command = '-i "$inputPath" -t ${_maxDurationSeconds.toString()} -ar ${_targetSampleRate.toString()} -ac 1 -f f32le -acodec pcm_f32le -y "$outputPath"';

      _logger.debug('Executing FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        _logger.info('Audio processing completed successfully');
        
        // Read the raw PCM data
        final audioData = await _readRawPCMFile(outputPath);
        return audioData;
      } else {
        final logs = await session.getAllLogs();
        final errorMessage = logs.map((log) => log.getMessage()).join('\n');
        _logger.error('FFmpeg processing failed: $errorMessage');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.error('Error processing audio with FFmpeg', e, stackTrace);
      return null;
    } finally {
      // Always clean up the temporary file
      if (outputPath != null) {
        try {
          final tempFile = File(outputPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
            _logger.debug('Temporary PCM file cleaned up: $outputPath');
          }
        } catch (e) {
          _logger.warning('Failed to clean up temporary PCM file: $e');
        }
      }
    }
  }

  /// Read raw PCM float32 file and convert to Float32List
  Future<Float32List?> _readRawPCMFile(String pcmPath) async {
    try {
      final file = File(pcmPath);
      if (!await file.exists()) {
        _logger.error('Processed PCM file not found: $pcmPath');
        return null;
      }

      final audioBytes = await file.readAsBytes();
      
      // Convert bytes to float32 array
      // Each float32 is 4 bytes (little-endian)
      final byteData = ByteData.sublistView(Uint8List.fromList(audioBytes));
      final audioSamples = <double>[];
      
      for (int i = 0; i < audioBytes.length; i += 4) {
        if (i + 3 < audioBytes.length) {
          final floatValue = byteData.getFloat32(i, Endian.little);
          audioSamples.add(floatValue);
        }
      }

      // Normalize audio like in the Python code
      // Find the maximum absolute value for normalization
      double maxAbsValue = 0.0;
      for (final sample in audioSamples) {
        final absValue = sample.abs();
        if (absValue > maxAbsValue) {
          maxAbsValue = absValue;
        }
      }
      
      // Normalize by dividing by max absolute value (avoid division by zero)
      if (maxAbsValue > 0.0) {
        for (int i = 0; i < audioSamples.length; i++) {
          audioSamples[i] = audioSamples[i] / maxAbsValue;
        }
        _logger.debug('Audio normalized with max absolute value: $maxAbsValue');
      } else {
        _logger.warning('Audio contains only silence, skipping normalization');
      }


      _logger.info('Audio samples extracted and normalized: ${audioSamples.length} samples');
      return Float32List.fromList(audioSamples);
      
    } catch (e, stackTrace) {
      _logger.error('Error reading PCM file', e, stackTrace);
      return null;
    }
  }

  /// Enhanced audio preprocessing using FFmpeg
  Future<Float32List?> _preprocessAudio(String audioFilePath) async {
    try {
      final inputFile = File(audioFilePath);
      if (!await inputFile.exists()) {
        _logger.error('Audio file not found: $audioFilePath');
        return null;
      }

      _logger.info('Starting audio preprocessing for: $audioFilePath');

      // Process audio with FFmpeg and get the audio data directly
      // Temporary files are created and cleaned up inside _processAudioWithFFmpeg
      final audioData = await _processAudioWithFFmpeg(audioFilePath);
      if (audioData == null) {
        _logger.error('Failed to process audio with FFmpeg');
        return null;
      }

      _logger.info('Audio preprocessing completed successfully');
      return audioData;
      
    } catch (e, stackTrace) {
      _logger.error('Error in audio preprocessing', e, stackTrace);
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
      
      // Run inference
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