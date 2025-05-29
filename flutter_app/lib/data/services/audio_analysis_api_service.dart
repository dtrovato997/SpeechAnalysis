// lib/data/services/audio_analysis_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';

/// Custom exception for HTTP errors
class HttpException implements Exception {
  final int statusCode;
  final String message;
  final String? responseBody;

  HttpException({
    required this.statusCode,
    required this.message,
    this.responseBody,
  });

  @override
  String toString() {
    return 'HTTP Error $statusCode: $message';
  }
}

class AudioAnalysisApiService {
  static final AudioAnalysisApiService _instance = AudioAnalysisApiService._internal();
  factory AudioAnalysisApiService() => _instance;
  AudioAnalysisApiService._internal();

  //static const String baseUrl = 'http://10.0.2.2:7860'; // Android emulator
  //static const String baseUrl = 'http://localhost:7860'; // iOS simulator
  //static const String baseUrl = 'http://192.168.1.52:7860'; // Physical device
  static const String baseUrl = 'https://dtrovato997-speechanalysisdemo.hf.space'; // Hugging Face Space
  // Timeout is large because inferences can take time on backedn
  static const Duration timeoutDuration = Duration(minutes: 8);

  /// Send audio file for complete analysis (age, gender, nationality)
  Future<CompletePrediction?> predictAll(String audioFilePath) async {
    try {
      final response = await _sendAudioRequest('/predict_all', audioFilePath);
      
      if (response.success && response.predictions != null) {
        return CompletePrediction.fromJson(response.predictions!);
      } else {
        throw Exception(response.error ?? 'Server returned success: false');
      }
    } catch (e) {
      print('Error in predictAll: $e');
      rethrow;
    }
  }
  
  Future<ApiResponse<Map<String, dynamic>>> _sendAudioRequest(
    String endpoint, 
    String audioFilePath
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    
    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) {
      throw Exception('Audio file does not exist: $audioFilePath');
    }

    final multipartFile = await http.MultipartFile.fromPath('file', audioFilePath);
    request.files.add(multipartFile);

    print('Sending audio file to $endpoint: $audioFilePath');
    
    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(timeoutDuration);
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
    
    final response = await http.Response.fromStream(streamedResponse);

    print('Server response status: ${response.statusCode}');
    print('Server response body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.fromJson(
          jsonResponse,
          (json) => json as Map<String, dynamic>,
        );
      } catch (e) {
        throw HttpException(
          statusCode: response.statusCode,
          message: 'Invalid JSON response from server',
          responseBody: response.body,
        );
      }
    } else {
      // HTTP error - non-200 status code
      String errorMessage;
      try {
        final errorJson = json.decode(response.body);
        errorMessage = errorJson['error'] ?? errorJson['message'] ?? 'Unknown server error';
      } catch (e) {
        // If response body is not JSON, use the raw body or a default message
        errorMessage = response.body.isNotEmpty 
            ? response.body 
            : 'Server error without details';
      }
      
      throw HttpException(
        statusCode: response.statusCode,
        message: errorMessage,
        responseBody: response.body,
      );
    }
  }

  /// Check if server is available
  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/');
      
      http.Response response;
      try {
        response = await http.get(uri).timeout(const Duration(seconds: 5));
      } catch (e) {
        // Network error
        print('Server health check network error: $e');
        return false;
      }
      
      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          final modelsLoaded = jsonResponse['models_loaded'];
          return modelsLoaded['age_gender'] == true && 
                 modelsLoaded['nationality'] == true;
        } catch (e) {
          print('Server health check JSON parsing error: $e');
          return false;
        }
      } else {
        print('Server health check HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }
}