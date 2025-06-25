import 'dart:io';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

/// Data class for passing model loading parameters to compute function
class ModelLoadingParams {
  final String modelName;
  final Uint8List modelBytes;
  
  ModelLoadingParams(this.modelName, this.modelBytes);
}

/// Service for running local ONNX model inference
/// Model loading happens in background threads, everything else on main thread
class LocalInferenceService {
  static final LocalInferenceService _instance =
      LocalInferenceService._internal();
  factory LocalInferenceService() => _instance;
  LocalInferenceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  bool _modelsLoaded = false;

  // Model bytes (loaded at startup)
  Uint8List? _emotionModelBytes;
  Uint8List? _ageGenderModelBytes;
  Uint8List? _languageModelBytes;

  // ONNX Runtime sessions (loaded on first use)
  OrtSession? _emotionSession;
  OrtSession? _ageGenderSession;
  OrtSession? _languageSession;

  // Audio processing constants
  static const int _targetSampleRate = 16000;
  static const int _maxDurationSeconds = 120; // 2 minutes

  // Language vocabulary - matches your Python model
  static const List<String> _languageVocabulary = [
    'chinese',
    'english',
    'french',
    'german',
    'indonesian',
    'italian',
    'japanese',
    'korean',
    'portuguese',
    'russian',
    'spanish',
    'turkish',
    'vietnamese',
    'other',
  ];

  /// Initialize the service (fast - only loads asset bytes)
  Future<bool> initialize() async {
    if (_isInitialized) {
      _logger.info('LocalInferenceService already initialized');
      return true;
    }

    try {
      _logger.info('Initializing LocalInferenceService (loading asset bytes)...');

      // Initialize ONNX Runtime environment on main thread
      OrtEnv.instance.init();

      // Load model assets on main thread (fast - just loads bytes into memory)
      _logger.info('Loading model asset bytes...');
      _emotionModelBytes = await _loadAssetBytes('assets/models/emotion_model.onnx');
      _ageGenderModelBytes = await _loadAssetBytes('assets/models/age_and_gender_model.onnx');
      _languageModelBytes = await _loadAssetBytes('assets/models/language_model.onnx');

      if (_emotionModelBytes == null || _ageGenderModelBytes == null || _languageModelBytes == null) {
        _logger.error('One or more model files not found');
        return false;
      }

      _isInitialized = true;
      _logger.info('LocalInferenceService initialized successfully (asset bytes loaded)');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize LocalInferenceService', e, stackTrace);
      await _cleanup();
      return false;
    }
  }

  /// Load models into memory (slow - deferred until first use)
  Future<bool> _loadModels() async {
    if (_modelsLoaded) {
      _logger.info('Models already loaded in memory');
      return true;
    }

    if (!_isInitialized) {
      _logger.error('Service not initialized. Call initialize() first.');
      return false;
    }

    try {
      _logger.info('Loading models into memory (this may take a few seconds)...');

      // Create ONNX sessions using compute (this is the slow, CPU-intensive part)
      final sessionResults = await Future.wait([
        compute(_loadModelInBackground, ModelLoadingParams('emotion', _emotionModelBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('age_gender', _ageGenderModelBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('language', _languageModelBytes!)),
      ]);

      _emotionSession = sessionResults[0];
      _ageGenderSession = sessionResults[1];
      _languageSession = sessionResults[2];

      if (_emotionSession == null || _ageGenderSession == null || _languageSession == null) {
        _logger.error('Failed to load one or more models into memory');
        return false;
      }

      _modelsLoaded = true;
      _logger.info('Models loaded into memory successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to load models into memory', e, stackTrace);
      return false;
    }
  }

  /// Load asset bytes (on main thread where rootBundle works)
  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final rawAssetFile = await rootBundle.load(assetPath);
      return rawAssetFile.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Load model in background compute function (ONNX session creation only)
  static OrtSession? _loadModelInBackground(ModelLoadingParams params) {
    try {
      final sessionOptions = OrtSessionOptions();
      sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
      sessionOptions.appendXnnpackProvider();
      sessionOptions.appendCPUProvider(CPUFlags.useNone);
      final session = OrtSession.fromBuffer(params.modelBytes, sessionOptions);
      sessionOptions.release();
      return session;
    } catch (e) {
      return null;
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

  /// Process audio file with FFmpeg and extract raw audio data (on main thread)
  Future<Float32List?> _processAudioWithFFmpeg(String inputPath) async {
    String? outputPath;

    try {
      if (!_isSupportedFormat(inputPath)) {
        _logger.error('Unsupported audio format: ${path.extension(inputPath)}');
        return null;
      }

      outputPath = _getTempAudioPath(inputPath);

      // FFmpeg command
      final command =
          '-i "$inputPath" -t ${_maxDurationSeconds.toString()} -ar ${_targetSampleRate.toString()} -ac 1 -f f32le -acodec pcm_f32le -y "$outputPath"';

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

  /// Read raw PCM float32 file and convert to Float32List (no normalization)
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

      _logger.info(
        'Raw audio samples extracted: ${audioSamples.length} samples',
      );
      return Float32List.fromList(audioSamples);
    } catch (e, stackTrace) {
      _logger.error('Error reading PCM file', e, stackTrace);
      return null;
    }
  }

  /// Normalize audio signal to [-1, 1] range using the same algorithm as tf_normalize_signal
  Float32List _normalizeSignal(Float32List audioData) {
    // Find the maximum absolute value for normalization
    double maxAbsValue = 0.0;
    for (final sample in audioData) {
      final absValue = sample.abs();
      if (absValue > maxAbsValue) {
        maxAbsValue = absValue;
      }
    }

    // Calculate gain: 1.0 / (max_abs + 1e-9)
    final gain = 1.0 / (maxAbsValue + 1e-9);
    
    // Apply gain to normalize signal
    final normalizedSamples = <double>[];
    for (final sample in audioData) {
      normalizedSamples.add(sample * gain);
    }

    _logger.debug('Audio normalized with gain: $gain (max abs: $maxAbsValue)');
    return Float32List.fromList(normalizedSamples);
  }

  /// Enhanced audio preprocessing using FFmpeg (on main thread)
  Future<Float32List?> _preprocessAudio(String audioFilePath) async {
    try {
      final inputFile = File(audioFilePath);
      if (!await inputFile.exists()) {
        _logger.error('Audio file not found: $audioFilePath');
        return null;
      }

      _logger.info('Starting audio preprocessing for: $audioFilePath');

      // Process audio with FFmpeg and get the audio data directly
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

  /// Run emotion prediction on preprocessed audio data (requires normalization)
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

      // Create input tensor with normalized audio
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final inputs = {'input_values': inputTensor};

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference (this already runs in background via runAsync)
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
        'angry',
        'calms',
        'disgust',
        'fearful',
        'happy',
        'neutral',
        'sad',
        'surprised',
      ];

      // Apply softmax to get probabilities
      final emotionProbs = _applySoftmax(logits, emotionLabels);

      final topEmotion = emotionProbs.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      _logger.info(
        'Emotion prediction completed: ${topEmotion.key} (${topEmotion.value.toStringAsFixed(3)})',
      );

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

  /// Run age and gender prediction on preprocessed audio data (requires normalization)
  Future<AgeGenderPrediction?> _predictAgeGender(Float32List audioData) async {
    if (_ageGenderSession == null) {
      _logger.error('Age and gender model not loaded');
      return null;
    }


    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      final inputShape = [1, audioData.length];

      // Create input tensor with normalized audio
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final inputs = {'signal': inputTensor};

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference (this already runs in background via runAsync)
      outputs = await _ageGenderSession!.runAsync(runOptions, inputs);

      if (outputs == null || outputs.length < 2) {
        _logger.error('Insufficient outputs from age and gender model');
        return null;
      }

      // Get age logits (first output)
      final ageOutput = outputs[1];
      if (ageOutput == null) {
        _logger.error('Age output is null');
        return null;
      }

      // Get gender logits (second output)
      final genderOutput = outputs[2];
      if (genderOutput == null) {
        _logger.error('Gender output is null');
        return null;
      }

      // Process age prediction (regression output - single value)
      final ageData = ageOutput.value;
      double predictedAge;

      if (ageData is List<List<double>>) {
        predictedAge = ageData[0][0] * 100; // Batch size 1, single output
      } else if (ageData is List<double>) {
        predictedAge = ageData[0] * 100;
      } else {
        _logger.error('Unexpected age output format: ${ageData.runtimeType}');
        return null;
      }

      // Process gender prediction (classification output)
      final genderData = genderOutput.value as List<List<double>>;
      final genderLogits = genderData[0]; // Assuming batch size of 1

      final genderLabels = ['female', 'male', 'child'];

      // Apply softmax to get gender probabilities
      final genderProbs = _applySoftmax(genderLogits, genderLabels);

      // Find the top gender prediction
      final topGender = genderProbs.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      // Map gender labels to expected format (M/F/C)
      String mappedGender;
      switch (topGender.key.toLowerCase()) {
        case 'female':
          mappedGender = 'F';
          break;
        case 'male':
          mappedGender = 'M';
          break;
        case 'child':
          mappedGender = 'C';
          break;
        default:
          mappedGender = 'M'; // Default fallback
      }

      // Create mapped probabilities with M/F/C keys
      final mappedGenderProbs = <String, double>{
        'F': genderProbs['female'] ?? 0.0,
        'M': genderProbs['male'] ?? 0.0,
        'C': genderProbs['child'] ?? 0.0,
      };

      _logger.info(
        'Age and gender prediction completed: Age=${predictedAge.toStringAsFixed(1)}, Gender=$mappedGender (${topGender.value.toStringAsFixed(3)})',
      );

      return AgeGenderPrediction(
        age: AgePrediction(predictedAge: predictedAge),
        gender: GenderPrediction(
          predictedGender: mappedGender,
          probabilities: mappedGenderProbs,
          confidence: topGender.value,
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('Error during age and gender prediction', e, stackTrace);
      return null;
    } finally {
      // Clean up resources
      inputTensor?.release();
      runOptions?.release();
      outputs?.forEach((output) => output?.release());
    }
  }

  Future<NationalityPrediction?> _predictLanguage(Float32List audioData) async {
    if (_languageSession == null) {
      _logger.error('Language model not loaded');
      return null;
    }

    // Use raw audio data (no normalization) for language model
    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      final inputShape = [audioData.length]; // Variable length audio input

      // Create input tensor with raw (unnormalized) audio
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final inputs = {'signal': inputTensor}; // Adjust input name if needed

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference (this already runs in background via runAsync)
      outputs = await _languageSession!.runAsync(runOptions, inputs);

      if (outputs == null || outputs.length < 3) {
        _logger.error('Insufficient outputs from language model');
        return null;
      }

      // Get outputs - based on your Python model outputs
      final predictedClassOutput = outputs[0];
      final confidenceOutput = outputs[1];
      final probabilitiesOutput = outputs[2];

      if (predictedClassOutput == null ||
          confidenceOutput == null ||
          probabilitiesOutput == null) {
        _logger.error('One or more language model outputs are null');
        return null;
      }

      // Extract prediction results
      final predictedClassData = predictedClassOutput.value;
      final confidenceData = confidenceOutput.value;
      final probabilitiesData = probabilitiesOutput.value;

      // Handle different output formats with robust type conversion
      int predictedIndex;
      double confidence;
      List<double> probabilities;

      // Parse predicted class index
      if (predictedClassData is List) {
        final firstElement = predictedClassData[0];
        if (firstElement is int) {
          predictedIndex = firstElement;
        } else if (firstElement is double) {
          predictedIndex = firstElement.round();
        } else {
          predictedIndex = (firstElement as num).round();
        }
      } else {
        predictedIndex = (predictedClassData as num).round();
      }

      // Parse confidence value
      if (confidenceData is List) {
        final firstElement = confidenceData[0];
        confidence = (firstElement as num).toDouble();
      } else {
        confidence = (confidenceData as num).toDouble();
      }

      // Parse probabilities with robust type handling
      if (probabilitiesData is List<List<dynamic>>) {
        // Handle nested list with dynamic types
        final innerList = probabilitiesData[0];
        probabilities = innerList.map((e) => (e as num).toDouble()).toList();
      } else if (probabilitiesData is List<List<double>>) {
        probabilities = probabilitiesData[0]; // Batch size 1
      } else if (probabilitiesData is List<double>) {
        probabilities = probabilitiesData;
      } else if (probabilitiesData is List<dynamic>) {
        // Handle flat list with dynamic types
        probabilities =
            probabilitiesData.map((e) => (e as num).toDouble()).toList();
      } else {
        _logger.error(
          'Unexpected probabilities format: ${probabilitiesData.runtimeType}',
        );
        _logger.debug('Probabilities data: $probabilitiesData');
        return null;
      }

      // Get predicted language
      final predictedLanguage =
          predictedIndex < _languageVocabulary.length
              ? _languageVocabulary[predictedIndex]
              : 'other';

      // Create top languages list from probabilities
      final languageProbPairs = <MapEntry<String, double>>[];
      for (
        int i = 0;
        i < probabilities.length && i < _languageVocabulary.length;
        i++
      ) {
        languageProbPairs.add(
          MapEntry(_languageVocabulary[i], probabilities[i]),
        );
      }

      // Sort by probability (descending) and take top 5
      languageProbPairs.sort((a, b) => b.value.compareTo(a.value));

      final topLanguages =
          languageProbPairs
              .take(5)
              .map(
                (entry) => LanguagePrediction(
                  languageCode: _mapLanguageToCode(entry.key),
                  probability: entry.value,
                ),
              )
              .toList();

      _logger.info(
        'Language prediction completed: ${predictedLanguage} (${confidence.toStringAsFixed(3)})',
      );

      return NationalityPrediction(
        predictedLanguage: _mapLanguageToCode(predictedLanguage),
        confidence: confidence,
        topLanguages: topLanguages,
      );
    } catch (e, stackTrace) {
      _logger.error('Error during language prediction', e, stackTrace);
      return null;
    } finally {
      // Clean up resources
      inputTensor?.release();
      runOptions?.release();
      outputs?.forEach((output) => output?.release());
    }
  }

  /// Map internal language names to language codes used in your LanguageMap
  String _mapLanguageToCode(String languageName) {
    const languageCodeMap = {
      'chinese': 'cmn', // Mandarin Chinese
      'english': 'eng', // English
      'french': 'fra', // French
      'german': 'deu', // German
      'indonesian': 'ind', // Indonesian
      'italian': 'ita', // Italian
      'japanese': 'jpn', // Japanese
      'korean': 'kor', // Korean
      'portuguese': 'por', // Portuguese
      'russian': 'rus', // Russian
      'spanish': 'spa', // Spanish
      'turkish': 'tur', // Turkish
      'vietnamese': 'vie', // Vietnamese
      'other': 'unk', // Unknown language fallback
    };

    return languageCodeMap[languageName.toLowerCase()] ?? 'unk';
  }

  /// Apply softmax function to convert logits to probabilities
  Map<String, double> _applySoftmax(List<double> logits, List<String> labels) {
    final probs = <String, double>{};
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
      probs[labels[i]] = expValues[i] / sumExp;
    }

    return probs;
  }

  /// Run complete prediction on audio file
  Future<CompletePrediction?> predictAll(String audioFilePath) async {
    if (!_isInitialized) {
      _logger.error('LocalInferenceService not initialized');
      return null;
    }

    // Load models into memory on first use (lazy loading)
    if (!_modelsLoaded) {
      _logger.info('First inference call - loading models into memory...');
      final modelsLoaded = await _loadModels();
      if (!modelsLoaded) {
        _logger.error('Failed to load models into memory');
        return null;
      }
    }

    try {
      _logger.info('Starting local inference for: $audioFilePath');

      // Preprocess audio (raw, unnormalized)
      final audioData = await _preprocessAudio(audioFilePath);
      if (audioData == null) {
        _logger.error('Failed to preprocess audio');
        return null;
      }

      // Run predictions (inference already happens in background via runAsync)
      final emotion = await _predictEmotion(audioData);
      if (emotion == null) {
        _logger.error('Failed to predict emotion');
        return null;
      }

      final demographics = await _predictAgeGender(audioData);
      if (demographics == null) {
        _logger.error('Failed to predict age and gender');
        return null;
      }

      final nationality = await _predictLanguage(audioData);
      if (nationality == null) {
        _logger.error('Failed to predict language');
        return null;
      }

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
  bool get isAvailable => _isInitialized && _modelsLoaded &&
      _emotionSession != null &&
      _ageGenderSession != null &&
      _languageSession != null;

  /// Check if service is initialized (asset bytes loaded)
  bool get isInitialized => _isInitialized;

  /// Check if models are loaded into memory
  bool get areModelsLoaded => _modelsLoaded;

  /// Get available models
  Map<String, bool> get availableModels => {
    'age_gender': _ageGenderSession != null,
    'nationality': _languageSession != null,
    'emotion': _emotionSession != null,
  };

  /// Get supported languages
  List<String> get supportedLanguages => List.from(_languageVocabulary);

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      _emotionSession?.release();
      _emotionSession = null;

      _ageGenderSession?.release();
      _ageGenderSession = null;

      _languageSession?.release();
      _languageSession = null;

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