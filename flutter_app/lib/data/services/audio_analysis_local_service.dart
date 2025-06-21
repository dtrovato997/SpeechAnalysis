import 'dart:io';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:mobile_speech_recognition/utils/audio_processing_util.dart';
import 'package:path/path.dart' as path;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

/// Service for running local ONNX model inference on audio files
class LocalInferenceService {
  static final LocalInferenceService _instance =
      LocalInferenceService._internal();
  factory LocalInferenceService() => _instance;
  LocalInferenceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  OrtSession? _emotionSession;
  OrtSession? _ageGenderSession;
  OrtSession? _nationalitySession; // Added nationality session

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

      // Load the models
      await _loadEmotionModel();
      await _loadAgeGenderModel();
      await _loadNationalityModel();

      _isInitialized = true;
      _logger.info('LocalInferenceService initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize LocalInferenceService',
        e,
        stackTrace,
      );
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
      sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
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

  /// Load the age and gender model
  Future<void> _loadAgeGenderModel() async {
    try {
      const assetFileName = 'assets/models/age_and_gender_model.onnx';
      final rawAssetFile = await rootBundle.load(assetFileName);
      final bytes = rawAssetFile.buffer.asUint8List();

      final sessionOptions = OrtSessionOptions();
      sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
      sessionOptions.appendXnnpackProvider();
      sessionOptions.appendCPUProvider(CPUFlags.useNone);
      _ageGenderSession = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();

      _logger.info('Age and gender model loaded successfully');
    } catch (e) {
      _logger.error('Failed to load age and gender model: $e');
      rethrow;
    }
  }

  /// Load the nationality model
  Future<void> _loadNationalityModel() async {
    try {
      const assetFileName = 'assets/models/tiny_encoder.onnx';
      final rawAssetFile = await rootBundle.load(assetFileName);
      final bytes = rawAssetFile.buffer.asUint8List();

      final sessionOptions = OrtSessionOptions();
      sessionOptions.appendNnapiProvider(NnapiFlags.useNCHW);
      sessionOptions.appendXnnpackProvider();
      sessionOptions.appendCPUProvider(CPUFlags.useNone);
      _nationalitySession = OrtSession.fromBuffer(
        bytes,
        sessionOptions,
      ); // Fixed: was _ageGenderSession
      sessionOptions.release();

      _logger.info('Nationality model loaded successfully');
    } catch (e) {
      _logger.error('Failed to load nationality model: $e');
      rethrow;
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
  Future<Float32List?> _processAudioWithFFmpeg(
    String inputPath, [
    bool normalize = true,
  ]) async {
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
      final command =
          '-i "$inputPath" -t ${_maxDurationSeconds.toString()} -ar ${_targetSampleRate.toString()} -ac 1 -f f32le -acodec pcm_f32le -y "$outputPath"';

      _logger.debug('Executing FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        _logger.info('Audio processing completed successfully');

        // Read the raw PCM data
        final audioData = await _readRawPCMFile(outputPath, normalize);
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

  /// Process audio file with FFmpeg and extract raw audio data
  Future<List<double>?> _readAndResampleAudioWithFFmpeg(
    String inputPath, [
    bool normalize = true,
  ]) async {
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
      final command =
          '-i "$inputPath" -t ${_maxDurationSeconds.toString()} -ar ${_targetSampleRate.toString()} -ac 1 -f f32le -acodec pcm_f32le -y "$outputPath"';

      _logger.debug('Executing FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        _logger.info('Audio processing completed successfully');

        // Read the raw PCM data
        final audioData = await _readRawPCMFileToDoubleList(outputPath, normalize);
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
  Future<Float32List?> _readRawPCMFile(
    String pcmPath, [
    bool normalize = true,
  ]) async {
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

      if (normalize) {
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
          _logger.debug(
            'Audio normalized with max absolute value: $maxAbsValue',
          );
        } else {
          _logger.warning(
            'Audio contains only silence, skipping normalization',
          );
        }

        _logger.info(
          'Audio samples extracted and normalized: ${audioSamples.length} samples',
        );
        return Float32List.fromList(audioSamples);
      }
      else {
        return Float32List.fromList(audioSamples);
      }
    } catch (e, stackTrace) {
      _logger.error('Error reading PCM file', e, stackTrace);
      return null;
    }
  }

  /// Read raw PCM float32 file and convert to Float32List
  Future<List<double>?> _readRawPCMFileToDoubleList(
    String pcmPath, [
    bool normalize = true,
  ]) async {
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

      if (normalize) {
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
          _logger.debug(
            'Audio normalized with max absolute value: $maxAbsValue',
          );
        } else {
          _logger.warning(
            'Audio contains only silence, skipping normalization',
          );
        }

        _logger.info(
          'Audio samples extracted and normalized: ${audioSamples.length} samples',
        );
        return audioSamples;
      }
      else {
        return audioSamples;
      }
    } catch (e, stackTrace) {
      _logger.error('Error reading PCM file', e, stackTrace);
      return null;
    }
  }

  /// Enhanced audio preprocessing using FFmpeg
  Future<Float32List?> _preprocessAudio(
    String audioFilePath, [
    bool normalize = true,
  ]) async {
    try {
      final inputFile = File(audioFilePath);
      if (!await inputFile.exists()) {
        _logger.error('Audio file not found: $audioFilePath');
        return null;
      }

      _logger.info('Starting audio preprocessing for: $audioFilePath');

      // Process audio with FFmpeg and get the audio data directly
      // Temporary files are created and cleaned up inside _processAudioWithFFmpeg
      final audioData = await _processAudioWithFFmpeg(audioFilePath, normalize);
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
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
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

  /// Run age and gender prediction on preprocessed audio data
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

      // Create input tensor
      inputTensor = OrtValueTensor.createTensorWithDataList(
        audioData,
        inputShape,
      );
      final inputs = {'signal': inputTensor};

      // Create run options
      runOptions = OrtRunOptions();

      // Run inference
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

  /// Run nationality/language prediction on preprocessed audio data
Future<NationalityPrediction?> _predictNationality(
  List<double> audioData,
) async {
  if (_nationalitySession == null) {
    _logger.error('Nationality model not loaded');
    return null;
  }

  OrtValueTensor? inputTensor;
  OrtRunOptions? runOptions;
  List<OrtValue?>? outputs;

  try {
    _logger.info('Computing mel spectrogram for language detection...');
    
    // Step 1: Compute mel spectrogram using your pure Dart implementation
    final melSpectrogramResult = WhisperMelSpectrogram.forLanguageDetection(audioData);
    
    _logger.info(
      'Mel spectrogram computed: ${melSpectrogramResult.nMel} x ${melSpectrogramResult.nFrames}',
    );

    // Step 2: Convert to the format expected by Whisper encoder
    // Whisper encoder expects input shape: [batch_size, n_mel, n_frames]
    // where n_mel = 80 and n_frames depends on audio length
    
    final batchSize = 1;
    final nMel = melSpectrogramResult.nMel; // Should be 80
    final nFrames = melSpectrogramResult.nFrames;
    
    // Convert mel spectrogram data to Float32List (float, not double)
    final inputDataFloat32 = <double>[];
    
    for (int mel = 0; mel < nMel; mel++) {
      for (int frame = 0; frame < nFrames; frame++) {
        // Convert to float32 precision
        inputDataFloat32.add(melSpectrogramResult.data[mel][frame]);
      }
    }
    
    // Create input shape: [batch_size, n_mel, n_frames]
    final inputShape = [batchSize, nMel, nFrames];
    
    _logger.info('Creating input tensor with shape: $inputShape');
    _logger.info('Input data length: ${inputDataFloat32.length}');
    
    // Step 3: Create ONNX input tensor with FLOAT32 data type
    // This is the key fix - use Float32List instead of List<double>
    final float32Data = Float32List.fromList(inputDataFloat32);
    
    inputTensor = OrtValueTensor.createTensorWithDataList(
      float32Data, // Use Float32List here, not List<double>
      inputShape,
    );
    
    // The Whisper encoder typically expects input named 'mel' or 'mel_spectrogram'
    // Check your ONNX model's input names if this doesn't work
    final inputs = {'mel': inputTensor};
    
    // Step 4: Create run options
    runOptions = OrtRunOptions();
    
    _logger.info('Running Whisper encoder inference...');
    
    // Step 5: Run inference
    outputs = await _nationalitySession!.runAsync(runOptions, inputs);
    
    if (outputs == null || outputs.isEmpty) {
      _logger.error('No outputs from nationality/encoder model');
      return null;
    }
    
    _logger.info('Encoder inference completed, got ${outputs.length} outputs');
    
    // Step 6: Get encoder output
    final encoderOutput = outputs[0];
    if (encoderOutput == null) {
      _logger.error('Encoder output is null');
      return null;
    }
    
    // The encoder output will be the encoded audio features
    // Shape should be something like [batch_size, sequence_length, hidden_size]
    final encoderData = encoderOutput.value;
    
    _logger.info('Encoder output type: ${encoderData.runtimeType}');
    
    // For now, since you don't have the decoder yet, let's just return a placeholder
    // TODO: Replace this with actual decoder logic when you have the decoder model
    
    // Extract some basic info about the encoded features for logging
    if (encoderData is List) {
      _logger.info('Encoder output shape info: length=${encoderData.length}');
      if (encoderData.isNotEmpty && encoderData[0] is List) {
        final batch0 = encoderData[0] as List;
        _logger.info('First batch shape: length=${batch0.length}');
        if (batch0.isNotEmpty && batch0[0] is List) {
          final seq0 = batch0[0] as List;
          _logger.info('Hidden dimension: ${seq0.length}');
        }
      }
    }
    
    // Placeholder return - replace this when you add the decoder
    _logger.info('Encoder processing completed successfully');
    
    return NationalityPrediction(
      predictedLanguage: "ENCODED", // Placeholder
      confidence: 1.0,
      topLanguages: [
        LanguagePrediction(
          languageCode: "ENCODED", 
          probability: 1.0,
        ),
      ],
    );
    
  } catch (e, stackTrace) {
    _logger.error('Error during nationality prediction', e, stackTrace);
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

      // Run age and gender prediction
      final demographics = await _predictAgeGender(audioData);
      if (demographics == null) {
        _logger.error('Failed to predict age and gender');
        return null;
      }

      // Preprocess audio
      final audioDataForNationality = await _readAndResampleAudioWithFFmpeg(audioFilePath, false);
      if (audioDataForNationality == null) {
        _logger.error('Failed to preprocess audio');
        return null;
      }
      // Run nationality prediction
      var nationality = await _predictNationality(audioDataForNationality);
      if (nationality == null) {
        _logger.error('Failed to predict nationality');
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
  bool get isAvailable =>
      _isInitialized &&
      _emotionSession != null &&
      _ageGenderSession != null &&
      _nationalitySession != null;

  /// Get available models
  Map<String, bool> get availableModels => {
    'age_gender': _ageGenderSession != null,
    'nationality': _nationalitySession != null,
    'emotion': _emotionSession != null,
  };

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      _emotionSession?.release();
      _emotionSession = null;

      _ageGenderSession?.release();
      _ageGenderSession = null;

      _nationalitySession?.release();
      _nationalitySession = null;

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
