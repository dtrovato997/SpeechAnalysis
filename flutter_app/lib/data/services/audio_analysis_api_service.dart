// lib/data/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mobile_speech_recognition/data/model/prediction_models.dart';


class AudioAnalysisApiService {
  static final AudioAnalysisApiService _instance = AudioAnalysisApiService._internal();
  factory AudioAnalysisApiService() => _instance;
  AudioAnalysisApiService._internal();

  // Base URL - adjust for your environment
  //static const String baseUrl = 'http://10.0.2.2:5000'; // Android emulator
  // static const String baseUrl = 'http://localhost:5000'; // iOS simulator
 static const String baseUrl = 'http://192.168.1.52:5000'; // Physical device

  static const Duration timeoutDuration = Duration(seconds: 30);

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
    final streamedResponse = await request.send().timeout(timeoutDuration);
    final response = await http.Response.fromStream(streamedResponse);

    print('Server response status: ${response.statusCode}');
    print('Server response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return ApiResponse.fromJson(
        jsonResponse,
        (json) => json as Map<String, dynamic>,
      );
    } else {
      final errorBody = response.body.isNotEmpty ? response.body : 'No error message';
      throw Exception('Server error ${response.statusCode}: $errorBody');
    }
  }

  /// Check if server is available
  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final modelsLoaded = jsonResponse['models_loaded'];
        return modelsLoaded['age_gender'] == true && 
               modelsLoaded['nationality'] == true;
      }
      return false;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }
}