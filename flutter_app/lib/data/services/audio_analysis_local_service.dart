import 'dart:io';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:mobile_speech_recognition/utils/language_map.dart';
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

/// Service for running local ONNX model inference with Whisper language detection
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
  Uint8List? _whisperPreprocessorBytes;
  Uint8List? _whisperLanguageDetectorBytes;

  // ONNX Runtime sessions (loaded on first use)
  OrtSession? _emotionSession;
  OrtSession? _ageGenderSession;
  OrtSession? _whisperPreprocessorSession;
  OrtSession? _whisperLanguageDetectorSession;

  // Audio processing constants
  static const int _targetSampleRate = 16000;
  static const int _maxDurationSeconds = 120; // 2 minutes

  // Whisper language tokens - extracted from Hugging Face tokenizer config
  static const List<String> _whisperLanguageTokens = [
    "<|en|>", "<|zh|>", "<|de|>", "<|es|>", "<|ru|>", "<|ko|>", "<|fr|>", "<|ja|>", "<|pt|>", "<|tr|>",
    "<|pl|>", "<|ca|>", "<|nl|>", "<|ar|>", "<|sv|>", "<|it|>", "<|id|>", "<|hi|>", "<|fi|>", "<|vi|>",
    "<|he|>", "<|uk|>", "<|el|>", "<|ms|>", "<|cs|>", "<|ro|>", "<|da|>", "<|hu|>", "<|ta|>", "<|no|>",
    "<|th|>", "<|ur|>", "<|hr|>", "<|bg|>", "<|lt|>", "<|la|>", "<|mi|>", "<|ml|>", "<|cy|>", "<|sk|>",
    "<|te|>", "<|fa|>", "<|lv|>", "<|bn|>", "<|sr|>", "<|az|>", "<|sl|>", "<|kn|>", "<|et|>", "<|mk|>",
    "<|br|>", "<|eu|>", "<|is|>", "<|hy|>", "<|ne|>", "<|mn|>", "<|bs|>", "<|kk|>", "<|sq|>", "<|sw|>",
    "<|gl|>", "<|mr|>", "<|pa|>", "<|si|>", "<|km|>", "<|sn|>", "<|yo|>", "<|so|>", "<|af|>", "<|oc|>",
    "<|ka|>", "<|be|>", "<|tg|>", "<|sd|>", "<|gu|>", "<|am|>", "<|yi|>", "<|lo|>", "<|uz|>", "<|fo|>",
    "<|ht|>", "<|ps|>", "<|tk|>", "<|nn|>", "<|mt|>", "<|sa|>", "<|lb|>", "<|my|>", "<|bo|>", "<|tl|>",
    "<|mg|>", "<|as|>", "<|tt|>", "<|haw|>", "<|ln|>", "<|ha|>", "<|ba|>", "<|jw|>", "<|su|>"
  ];

  // Extract language codes from tokens
  static final List<String> _whisperLanguageCodes = 
      _whisperLanguageTokens.map((token) => token.substring(2, token.length - 2)).toList();

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
      _whisperPreprocessorBytes = await _loadAssetBytes('assets/models/whisper_preprocessor.onnx');
      _whisperLanguageDetectorBytes = await _loadAssetBytes('assets/models/whisper_lang_detector.onnx');

      if (_emotionModelBytes == null || _ageGenderModelBytes == null || 
          _whisperPreprocessorBytes == null || _whisperLanguageDetectorBytes == null) {
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
        compute(_loadModelInBackground, ModelLoadingParams('whisper_preprocessor', _whisperPreprocessorBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('whisper_language_detector', _whisperLanguageDetectorBytes!)),
      ]);

      _emotionSession = sessionResults[0];
      _ageGenderSession = sessionResults[1];
      _whisperPreprocessorSession = sessionResults[2];
      _whisperLanguageDetectorSession = sessionResults[3];

      if (_emotionSession == null || _ageGenderSession == null || 
          _whisperPreprocessorSession == null || _whisperLanguageDetectorSession == null) {
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
      print('Loading model: ${params.modelName}, size: ${params.modelBytes.length} bytes');
      
      final sessionOptions = OrtSessionOptions();
      
      // Use different provider strategies based on model type
      if (params.modelName == 'whisper_language_detector') {
        try {
          sessionOptions.appendCPUProvider(CPUFlags.useNone);
          print('Using CPU-only provider for ${params.modelName}');
        } catch (e) {
          print('CPU provider configuration failed for ${params.modelName}: $e');
        }
      } else {
        try {
          sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
        } catch (e) {
          print('NNAPI provider not available for ${params.modelName}: $e');
        }
        
        try {
          sessionOptions.appendXnnpackProvider();
        } catch (e) {
          print('XNNPACK provider not available for ${params.modelName}: $e');
        }
        
        try {
          sessionOptions.appendCPUProvider(CPUFlags.useNone);
        } catch (e) {
          print('CPU provider configuration failed for ${params.modelName}: $e');
        }
      }
      
      final session = OrtSession.fromBuffer(params.modelBytes, sessionOptions);
      sessionOptions.release();
      
      print('Successfully loaded model: ${params.modelName}');
      return session;
    } catch (e, stackTrace) {
      print('Failed to load model ${params.modelName}: $e');
      print('Stack trace: $stackTrace');
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

  bool _isSupportedFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.mp3', '.wav', '.m4a'].contains(extension);
  }

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
      final logits = logitsData[0];

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

      final ageOutput = outputs[1];
      if (ageOutput == null) {
        _logger.error('Age output is null');
        return null;
      }

      final genderOutput = outputs[2];
      if (genderOutput == null) {
        _logger.error('Gender output is null');
        return null;
      }

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
    if (_whisperPreprocessorSession == null || _whisperLanguageDetectorSession == null) {
      _logger.error('Whisper models not loaded');
      return null;
    }

    OrtValueTensor? audioTensor;
    OrtValueTensor? featuresTensor;
    OrtRunOptions? runOptions1;
    OrtRunOptions? runOptions2;
    List<OrtValue?>? preprocessorOutputs;
    List<OrtValue?>? detectorOutputs;

    try {
      _logger.debug('Running Whisper preprocessor...');
      
      final audioShape = [1, audioData.length];
      audioTensor = OrtValueTensor.createTensorWithDataList(audioData, audioShape);
      final preprocessorInputs = {'audio_pcm': audioTensor};

      runOptions1 = OrtRunOptions();
      preprocessorOutputs = await _whisperPreprocessorSession!.runAsync(runOptions1, preprocessorInputs);

      if (preprocessorOutputs == null || preprocessorOutputs.isEmpty) {
        _logger.error('No outputs from Whisper preprocessor');
        return null;
      }

      final featuresOutput = preprocessorOutputs[0];
      if (featuresOutput == null) {
        _logger.error('Features output from preprocessor is null');
        return null;
      }

      final featuresData = featuresOutput.value as List<List<List<double>>>;
      _logger.debug('Preprocessor output shape: [${featuresData.length}, ${featuresData[0].length}, ${featuresData[0][0].length}]');

      final features2D = featuresData[0]; // Remove batch dimension
      
      // Step 3: Run Whisper language detector
      _logger.debug('Running Whisper language detector...');
      
      // Create input tensor for language detector with shape [80, 3000]
      final featuresShape = [features2D.length, features2D[0].length];
      final flatFeatures = <double>[];
      for (final row in features2D) {
        flatFeatures.addAll(row);
      }
      
      featuresTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(flatFeatures), 
        featuresShape
      );
      final detectorInputs = {'input_features': featuresTensor};

      runOptions2 = OrtRunOptions();
      detectorOutputs = await _whisperLanguageDetectorSession!.runAsync(runOptions2, detectorInputs);

      if (detectorOutputs == null || detectorOutputs.isEmpty) {
        _logger.error('No outputs from Whisper language detector');
        return null;
      }

      final languageProbsOutput = detectorOutputs[0];
      if (languageProbsOutput == null) {
        _logger.error('Language probabilities output is null');
        return null;
      }

      // Get language probabilities
      final languageProbsData = languageProbsOutput.value;
      List<double> languageProbs;

      if (languageProbsData is List<List<double>>) {
        languageProbs = languageProbsData[0]; // Remove batch dimension
      } else if (languageProbsData is List<double>) {
        languageProbs = languageProbsData;
      } else {
        _logger.error('Unexpected language probabilities format: ${languageProbsData.runtimeType}');
        return null;
      }

      // Find top prediction
      int topIndex = 0;
      double maxProb = languageProbs[0];
      for (int i = 1; i < languageProbs.length; i++) {
        if (languageProbs[i] > maxProb) {
          maxProb = languageProbs[i];
          topIndex = i;
        }
      }

      // Get predicted language
      final predictedLanguageCode = topIndex < _whisperLanguageCodes.length 
          ? _whisperLanguageCodes[topIndex] 
          : 'unk';

      // Create top languages list from probabilities
      final languageProbPairs = <MapEntry<String, double>>[];
      for (int i = 0; i < languageProbs.length && i < _whisperLanguageCodes.length; i++) {
        languageProbPairs.add(MapEntry(_whisperLanguageCodes[i], languageProbs[i]));
      }

      // Sort by probability (descending) and take top 5
      languageProbPairs.sort((a, b) => b.value.compareTo(a.value));

      final topLanguages = languageProbPairs
          .take(5)
          .map((entry) => LanguagePrediction(
                languageCode: LanguageMap.mapWhisperLanguageToCode(entry.key),
                probability: entry.value,
              ))
          .toList();

      _logger.info(
        'Whisper language prediction completed: $predictedLanguageCode (${maxProb.toStringAsFixed(3)})',
      );

      return NationalityPrediction(
        predictedLanguage: LanguageMap.mapWhisperLanguageToCode(predictedLanguageCode),
        confidence: maxProb,
        topLanguages: topLanguages,
      );
    } catch (e, stackTrace) {
      _logger.error('Error during Whisper language prediction', e, stackTrace);
      return null;
    } finally {
      // Clean up resources
      audioTensor?.release();
      featuresTensor?.release();
      runOptions1?.release();
      runOptions2?.release();
      preprocessorOutputs?.forEach((output) => output?.release());
      detectorOutputs?.forEach((output) => output?.release());
    }
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

      // Use Whisper-based language prediction instead of the old model
      final nationality = await _predictLanguage(audioData);
      if (nationality == null) {
        _logger.error('Failed to predict language with Whisper');
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
      _whisperPreprocessorSession != null &&
      _whisperLanguageDetectorSession != null;

  /// Check if service is initialized (asset bytes loaded)
  bool get isInitialized => _isInitialized;

  /// Check if models are loaded into memory
  bool get areModelsLoaded => _modelsLoaded;

  /// Get available models
  Map<String, bool> get availableModels => {
    'age_gender': _ageGenderSession != null,
    'nationality': _whisperLanguageDetectorSession != null && _whisperPreprocessorSession != null,
    'emotion': _emotionSession != null,
  };

  /// Get supported languages (Whisper languages)
  List<String> get supportedLanguages => List.from(_whisperLanguageCodes);

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      _emotionSession?.release();
      _emotionSession = null;

      _ageGenderSession?.release();
      _ageGenderSession = null;

      _whisperPreprocessorSession?.release();
      _whisperPreprocessorSession = null;

      _whisperLanguageDetectorSession?.release();
      _whisperLanguageDetectorSession = null;

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
      _modelsLoaded = false;
      _logger.info('LocalInferenceService disposed');
    } catch (e, stackTrace) {
      _logger.error('Error disposing LocalInferenceService', e, stackTrace);
    }
  }
}