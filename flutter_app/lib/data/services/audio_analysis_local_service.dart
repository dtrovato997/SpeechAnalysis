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

    final initStartTime = DateTime.now();
    _logger.info('=== PROFILING: Service Initialization Started ===');

    try {
      // Initialize ONNX Runtime environment on main thread
      final ortEnvStartTime = DateTime.now();
      OrtEnv.instance.init();
      final ortEnvDuration = DateTime.now().difference(ortEnvStartTime);
      _logger.info('PROFILING: OrtEnv initialization took ${ortEnvDuration.inMilliseconds}ms');

      // Load model assets on main thread (fast - just loads bytes into memory)
      _logger.info('PROFILING: Loading model asset bytes...');
      
      final emotionLoadStart = DateTime.now();
      _emotionModelBytes = await _loadAssetBytes('assets/models/emotion_model.onnx');
      final emotionLoadDuration = DateTime.now().difference(emotionLoadStart);
      _logger.info('PROFILING: Emotion model bytes loaded in ${emotionLoadDuration.inMilliseconds}ms (${_emotionModelBytes?.length ?? 0} bytes)');
      
      final ageGenderLoadStart = DateTime.now();
      _ageGenderModelBytes = await _loadAssetBytes('assets/models/age_and_gender_model.onnx');
      final ageGenderLoadDuration = DateTime.now().difference(ageGenderLoadStart);
      _logger.info('PROFILING: Age & Gender model bytes loaded in ${ageGenderLoadDuration.inMilliseconds}ms (${_ageGenderModelBytes?.length ?? 0} bytes)');
      
      final whisperPreprocLoadStart = DateTime.now();
      _whisperPreprocessorBytes = await _loadAssetBytes('assets/models/whisper_preprocessor.onnx');
      final whisperPreprocLoadDuration = DateTime.now().difference(whisperPreprocLoadStart);
      _logger.info('PROFILING: Whisper preprocessor bytes loaded in ${whisperPreprocLoadDuration.inMilliseconds}ms (${_whisperPreprocessorBytes?.length ?? 0} bytes)');
      
      final whisperDetectorLoadStart = DateTime.now();
      _whisperLanguageDetectorBytes = await _loadAssetBytes('assets/models/whisper_lang_detector.onnx');
      final whisperDetectorLoadDuration = DateTime.now().difference(whisperDetectorLoadStart);
      _logger.info('PROFILING: Whisper language detector bytes loaded in ${whisperDetectorLoadDuration.inMilliseconds}ms (${_whisperLanguageDetectorBytes?.length ?? 0} bytes)');

      if (_emotionModelBytes == null || _ageGenderModelBytes == null || 
          _whisperPreprocessorBytes == null || _whisperLanguageDetectorBytes == null) {
        _logger.error('One or more model files not found');
        return false;
      }

      final totalBytesLoaded = (_emotionModelBytes?.length ?? 0) + 
                                (_ageGenderModelBytes?.length ?? 0) + 
                                (_whisperPreprocessorBytes?.length ?? 0) + 
                                (_whisperLanguageDetectorBytes?.length ?? 0);
      _logger.info('PROFILING: Total model bytes loaded: ${(totalBytesLoaded / 1024 / 1024).toStringAsFixed(2)} MB');

      _isInitialized = true;
      final totalInitDuration = DateTime.now().difference(initStartTime);
      _logger.info('=== PROFILING: Service Initialization Completed in ${totalInitDuration.inMilliseconds}ms ===');
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

    final loadStartTime = DateTime.now();
    _logger.info('=== PROFILING: Model Loading Started ===');

    try {
      // Create ONNX sessions using compute (this is the slow, CPU-intensive part)
      _logger.info('PROFILING: Creating ONNX sessions in parallel...');
      final parallelLoadStart = DateTime.now();
      
      final sessionResults = await Future.wait([
        compute(_loadModelInBackground, ModelLoadingParams('emotion', _emotionModelBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('age_gender', _ageGenderModelBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('whisper_preprocessor', _whisperPreprocessorBytes!)),
        compute(_loadModelInBackground, ModelLoadingParams('whisper_language_detector', _whisperLanguageDetectorBytes!)),
      ]);
      
      final parallelLoadDuration = DateTime.now().difference(parallelLoadStart);
      _logger.info('PROFILING: Parallel model loading completed in ${parallelLoadDuration.inMilliseconds}ms');

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
      final totalLoadDuration = DateTime.now().difference(loadStartTime);
      _logger.info('=== PROFILING: Model Loading Completed in ${totalLoadDuration.inMilliseconds}ms ===');
      _logger.info('PROFILING: Models now occupy memory - ready for inference');
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
    final modelLoadStart = DateTime.now();
    
    try {
      print('PROFILING [${params.modelName}]: Starting model load, size: ${params.modelBytes.length} bytes (${(params.modelBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      final sessionOptions = OrtSessionOptions();
      final optionsCreateTime = DateTime.now();
      
      // Use different provider strategies based on model type
      if (params.modelName == 'whisper_language_detector') {
        try {
          sessionOptions.appendCPUProvider(CPUFlags.useNone);
          print('PROFILING [${params.modelName}]: Using CPU-only provider');
        } catch (e) {
          print('PROFILING [${params.modelName}]: CPU provider configuration failed: $e');
        }
      } else {
        try {
          sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
          print('PROFILING [${params.modelName}]: NNAPI provider appended');
        } catch (e) {
          print('PROFILING [${params.modelName}]: NNAPI provider not available: $e');
        }
        
        try {
          sessionOptions.appendXnnpackProvider();
          print('PROFILING [${params.modelName}]: XNNPACK provider appended');
        } catch (e) {
          print('PROFILING [${params.modelName}]: XNNPACK provider not available: $e');
        }
        
        try {
          sessionOptions.appendCPUProvider(CPUFlags.useNone);
          print('PROFILING [${params.modelName}]: CPU provider appended');
        } catch (e) {
          print('PROFILING [${params.modelName}]: CPU provider configuration failed: $e');
        }
      }
      
      final optionsConfigTime = DateTime.now().difference(optionsCreateTime);
      print('PROFILING [${params.modelName}]: Session options configured in ${optionsConfigTime.inMilliseconds}ms');
      
      final sessionCreateStart = DateTime.now();
      final session = OrtSession.fromBuffer(params.modelBytes, sessionOptions);
      final sessionCreateTime = DateTime.now().difference(sessionCreateStart);
      print('PROFILING [${params.modelName}]: Session creation took ${sessionCreateTime.inMilliseconds}ms');
      
      sessionOptions.release();
      
      final totalLoadTime = DateTime.now().difference(modelLoadStart);
      print('PROFILING [${params.modelName}]: Successfully loaded in ${totalLoadTime.inMilliseconds}ms total');
      return session;
    } catch (e, stackTrace) {
      print('PROFILING [${params.modelName}]: Failed to load model: $e');
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
    final ffmpegStartTime = DateTime.now();
    _logger.info('PROFILING: FFmpeg audio processing started');

    try {
      if (!_isSupportedFormat(inputPath)) {
        _logger.error('Unsupported audio format: ${path.extension(inputPath)}');
        return null;
      }

      // Check input file size
      final inputFile = File(inputPath);
      final inputFileSize = await inputFile.length();
      _logger.info('PROFILING: Input audio file size: ${(inputFileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      outputPath = _getTempAudioPath(inputPath);

      // FFmpeg command
      final command =
          '-i "$inputPath" -t ${_maxDurationSeconds.toString()} -ar ${_targetSampleRate.toString()} -ac 1 -f f32le -acodec pcm_f32le -y "$outputPath"';

      _logger.debug('PROFILING: Executing FFmpeg command: $command');
      final ffmpegExecStart = DateTime.now();

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      final ffmpegExecDuration = DateTime.now().difference(ffmpegExecStart);
      _logger.info('PROFILING: FFmpeg execution took ${ffmpegExecDuration.inMilliseconds}ms');

      if (ReturnCode.isSuccess(returnCode)) {
        // Check output file size
        final outputFile = File(outputPath);
        final outputFileSize = await outputFile.length();
        _logger.info('PROFILING: Output PCM file size: ${(outputFileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        // Read the raw PCM data
        final readStartTime = DateTime.now();
        final audioData = await _readRawPCMFile(outputPath);
        final readDuration = DateTime.now().difference(readStartTime);
        _logger.info('PROFILING: PCM file reading took ${readDuration.inMilliseconds}ms');
        
        if (audioData != null) {
          _logger.info('PROFILING: Audio samples: ${audioData.length} (${(audioData.length / _targetSampleRate).toStringAsFixed(2)}s duration)');
        }

        final totalFFmpegDuration = DateTime.now().difference(ffmpegStartTime);
        _logger.info('PROFILING: Total FFmpeg processing took ${totalFFmpegDuration.inMilliseconds}ms');
        
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
    final preprocessStartTime = DateTime.now();
    _logger.info('=== PROFILING: Audio Preprocessing Started ===');
    
    try {
      final inputFile = File(audioFilePath);
      if (!await inputFile.exists()) {
        _logger.error('Audio file not found: $audioFilePath');
        return null;
      }

      // Process audio with FFmpeg and get the audio data directly
      final audioData = await _processAudioWithFFmpeg(audioFilePath);
      if (audioData == null) {
        _logger.error('Failed to process audio with FFmpeg');
        return null;
      }

      final totalPreprocessDuration = DateTime.now().difference(preprocessStartTime);
      _logger.info('=== PROFILING: Audio Preprocessing Completed in ${totalPreprocessDuration.inMilliseconds}ms ===');
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

    final emotionStartTime = DateTime.now();
    _logger.info('=== PROFILING: Emotion Inference Started ===');
    _logger.info('PROFILING [Emotion]: Input audio samples: ${audioData.length}');

    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      final inputShape = [1, audioData.length];

      // Create input tensor with normalized audio
      final tensorCreateStart = DateTime.now();
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final tensorCreateDuration = DateTime.now().difference(tensorCreateStart);
      _logger.info('PROFILING [Emotion]: Input tensor created in ${tensorCreateDuration.inMilliseconds}ms');
      
      final inputs = {'input_values': inputTensor};

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference
      final inferenceStart = DateTime.now();
      outputs = await _emotionSession!.runAsync(runOptions, inputs);
      final inferenceDuration = DateTime.now().difference(inferenceStart);
      _logger.info('PROFILING [Emotion]: Model inference took ${inferenceDuration.inMilliseconds}ms');

      if (outputs == null || outputs.isEmpty) {
        _logger.error('No outputs from emotion model');
        return null;
      }

      // Process outputs
      final postprocessStart = DateTime.now();
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
      
      final postprocessDuration = DateTime.now().difference(postprocessStart);
      _logger.info('PROFILING [Emotion]: Output postprocessing took ${postprocessDuration.inMilliseconds}ms');

      final totalEmotionDuration = DateTime.now().difference(emotionStartTime);
      _logger.info('=== PROFILING: Emotion Inference Completed in ${totalEmotionDuration.inMilliseconds}ms ===');
      _logger.info('PROFILING [Emotion]: Result: ${topEmotion.key} (confidence: ${topEmotion.value.toStringAsFixed(3)})');

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

    final ageGenderStartTime = DateTime.now();
    _logger.info('=== PROFILING: Age & Gender Inference Started ===');
    _logger.info('PROFILING [AgeGender]: Input audio samples: ${audioData.length}');

    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      final inputShape = [1, audioData.length];

      // Create input tensor with normalized audio
      final tensorCreateStart = DateTime.now();
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final tensorCreateDuration = DateTime.now().difference(tensorCreateStart);
      _logger.info('PROFILING [AgeGender]: Input tensor created in ${tensorCreateDuration.inMilliseconds}ms');
      
      final inputs = {'signal': inputTensor};

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference
      final inferenceStart = DateTime.now();
      outputs = await _ageGenderSession!.runAsync(runOptions, inputs);
      final inferenceDuration = DateTime.now().difference(inferenceStart);
      _logger.info('PROFILING [AgeGender]: Model inference took ${inferenceDuration.inMilliseconds}ms');

      if (outputs == null || outputs.length < 2) {
        _logger.error('Insufficient outputs from age and gender model');
        return null;
      }

      // Process outputs
      final postprocessStart = DateTime.now();
      
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
      
      final postprocessDuration = DateTime.now().difference(postprocessStart);
      _logger.info('PROFILING [AgeGender]: Output postprocessing took ${postprocessDuration.inMilliseconds}ms');

      final totalAgeGenderDuration = DateTime.now().difference(ageGenderStartTime);
      _logger.info('=== PROFILING: Age & Gender Inference Completed in ${totalAgeGenderDuration.inMilliseconds}ms ===');
      _logger.info('PROFILING [AgeGender]: Result: Age=${predictedAge.toStringAsFixed(1)}, Gender=$mappedGender (confidence: ${topGender.value.toStringAsFixed(3)})');

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

    final languageStartTime = DateTime.now();
    _logger.info('=== PROFILING: Language Detection Started ===');
    _logger.info('PROFILING [Language]: Input audio samples: ${audioData.length}');

    OrtValueTensor? audioTensor;
    OrtValueTensor? featuresTensor;
    OrtRunOptions? runOptions1;
    OrtRunOptions? runOptions2;
    List<OrtValue?>? preprocessorOutputs;
    List<OrtValue?>? detectorOutputs;

    try {
      // Step 1: Whisper Preprocessor
      _logger.info('PROFILING [Language]: Running Whisper preprocessor...');
      final preprocessorStart = DateTime.now();
      
      final audioShape = [1, audioData.length];
      final tensorCreateStart = DateTime.now();
      audioTensor = OrtValueTensor.createTensorWithDataList(audioData, audioShape);
      final tensorCreateDuration = DateTime.now().difference(tensorCreateStart);
      _logger.info('PROFILING [Language-Preproc]: Audio tensor created in ${tensorCreateDuration.inMilliseconds}ms');
      
      final preprocessorInputs = {'audio_pcm': audioTensor};

      runOptions1 = OrtRunOptions();
      
      final preprocInferenceStart = DateTime.now();
      preprocessorOutputs = await _whisperPreprocessorSession!.runAsync(runOptions1, preprocessorInputs);
      final preprocInferenceDuration = DateTime.now().difference(preprocInferenceStart);
      _logger.info('PROFILING [Language-Preproc]: Preprocessor inference took ${preprocInferenceDuration.inMilliseconds}ms');

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
      _logger.info('PROFILING [Language-Preproc]: Output shape: [${featuresData.length}, ${featuresData[0].length}, ${featuresData[0][0].length}]');

      final features2D = featuresData[0]; // Remove batch dimension
      
      final preprocessorTotalDuration = DateTime.now().difference(preprocessorStart);
      _logger.info('PROFILING [Language-Preproc]: Total preprocessor time: ${preprocessorTotalDuration.inMilliseconds}ms');
      
      // Step 2: Whisper Language Detector
      _logger.info('PROFILING [Language]: Running Whisper language detector...');
      final detectorStart = DateTime.now();
      
      // Create input tensor for language detector with shape [80, 3000]
      final featuresShape = [features2D.length, features2D[0].length];
      final flatFeatures = <double>[];
      for (final row in features2D) {
        flatFeatures.addAll(row);
      }
      
      final detectorTensorStart = DateTime.now();
      featuresTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(flatFeatures), 
        featuresShape
      );
      final detectorTensorDuration = DateTime.now().difference(detectorTensorStart);
      _logger.info('PROFILING [Language-Detector]: Features tensor created in ${detectorTensorDuration.inMilliseconds}ms');
      
      final detectorInputs = {'input_features': featuresTensor};

      runOptions2 = OrtRunOptions();
      
      final detectorInferenceStart = DateTime.now();
      detectorOutputs = await _whisperLanguageDetectorSession!.runAsync(runOptions2, detectorInputs);
      final detectorInferenceDuration = DateTime.now().difference(detectorInferenceStart);
      _logger.info('PROFILING [Language-Detector]: Detector inference took ${detectorInferenceDuration.inMilliseconds}ms');

      if (detectorOutputs == null || detectorOutputs.isEmpty) {
        _logger.error('No outputs from Whisper language detector');
        return null;
      }

      // Step 3: Process outputs
      final postprocessStart = DateTime.now();
      
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

      _logger.info('PROFILING [Language-Detector]: Output probabilities count: ${languageProbs.length}');

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
      
      final postprocessDuration = DateTime.now().difference(postprocessStart);
      _logger.info('PROFILING [Language]: Output postprocessing took ${postprocessDuration.inMilliseconds}ms');

      final detectorTotalDuration = DateTime.now().difference(detectorStart);
      _logger.info('PROFILING [Language-Detector]: Total detector time: ${detectorTotalDuration.inMilliseconds}ms');

      final totalLanguageDuration = DateTime.now().difference(languageStartTime);
      _logger.info('=== PROFILING: Language Detection Completed in ${totalLanguageDuration.inMilliseconds}ms ===');
      _logger.info('PROFILING [Language]: Result: $predictedLanguageCode (confidence: ${maxProb.toStringAsFixed(3)})');

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

    final totalPredictionStartTime = DateTime.now();
    _logger.info('======================================');
    _logger.info('=== PROFILING: COMPLETE ANALYSIS STARTED ===');
    _logger.info('PROFILING: Audio file: $audioFilePath');
    _logger.info('======================================');

    // Load models into memory on first use (lazy loading)
    if (!_modelsLoaded) {
      _logger.info('PROFILING: First inference call - loading models into memory...');
      final modelsLoaded = await _loadModels();
      if (!modelsLoaded) {
        _logger.error('Failed to load models into memory');
        return null;
      }
    }

    try {
      // Preprocess audio (raw, unnormalized)
      final audioData = await _preprocessAudio(audioFilePath);
      if (audioData == null) {
        _logger.error('Failed to preprocess audio');
        return null;
      }

      _logger.info('======================================');
      _logger.info('PROFILING: Starting PARALLEL model inference...');
      _logger.info('======================================');

      // Run all predictions in parallel using Future.wait
      final parallelInferenceStart = DateTime.now();
      final results = await Future.wait([
        _predictEmotion(audioData),
        _predictAgeGender(audioData),
        _predictLanguage(audioData),
      ]);
      final parallelInferenceDuration = DateTime.now().difference(parallelInferenceStart);
      
      _logger.info('======================================');
      _logger.info('PROFILING: PARALLEL inference completed in ${parallelInferenceDuration.inMilliseconds}ms');
      _logger.info('======================================');

      final emotion = results[0] as EmotionPrediction?;
      final demographics = results[1] as AgeGenderPrediction?;
      final nationality = results[2] as NationalityPrediction?;

      if (emotion == null) {
        _logger.error('Failed to predict emotion');
        return null;
      }

      if (demographics == null) {
        _logger.error('Failed to predict age and gender');
        return null;
      }

      if (nationality == null) {
        _logger.error('Failed to predict language with Whisper');
        return null;
      }

      final prediction = CompletePrediction(
        demographics: demographics,
        nationality: nationality,
        emotion: emotion,
      );

      final totalPredictionDuration = DateTime.now().difference(totalPredictionStartTime);
      _logger.info('======================================');
      _logger.info('=== PROFILING: COMPLETE ANALYSIS FINISHED ===');
      _logger.info('PROFILING: Total analysis time: ${totalPredictionDuration.inMilliseconds}ms (${(totalPredictionDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');
      _logger.info('PROFILING: Parallel inference time: ${parallelInferenceDuration.inMilliseconds}ms');
      _logger.info('PROFILING: Audio duration: ${(audioData.length / _targetSampleRate).toStringAsFixed(2)}s');
      _logger.info('PROFILING: Real-time factor: ${((totalPredictionDuration.inMilliseconds / 1000) / (audioData.length / _targetSampleRate)).toStringAsFixed(2)}x');
      _logger.info('======================================');

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