import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

class MicrophonePermissionService {
  static final MicrophonePermissionService _instance = MicrophonePermissionService._internal();
  factory MicrophonePermissionService() => _instance;
  MicrophonePermissionService._internal();

  final LoggerService _logger = LoggerService();

  /// Check if microphone permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.microphone.status;
      _logger.debug('Microphone permission status: $status');
      return status == PermissionStatus.granted;
    } catch (e) {
      _logger.error('Error checking microphone permission', e);
      return false;
    }
  }

  /// Request microphone permission
  Future<PermissionResult> requestPermission() async {
    try {
      _logger.info('Requesting microphone permission');
      
      // Check current status first
      final currentStatus = await Permission.microphone.status;
      _logger.debug('Current microphone permission status: $currentStatus');

      // If already granted, return success
      if (currentStatus == PermissionStatus.granted) {
        _logger.info('Microphone permission already granted');
        return PermissionResult.granted;
      }

      // If permanently denied, cannot request again
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        _logger.warning('Microphone permission permanently denied');
        return PermissionResult.permanentlyDenied;
      }

      // Request permission
      final status = await Permission.microphone.request();
      _logger.info('Microphone permission request result: $status');

      switch (status) {
        case PermissionStatus.granted:
          return PermissionResult.granted;
        case PermissionStatus.denied:
          return PermissionResult.denied;
        case PermissionStatus.permanentlyDenied:
          return PermissionResult.permanentlyDenied;
        default:
          return PermissionResult.denied;
      }
    } catch (e) {
      _logger.error('Error requesting microphone permission', e);
      return PermissionResult.error;
    }
  }

  /// Open app settings for the user to manually grant permission
  Future<bool> openSettings() async {
    try {
      _logger.info('Opening app settings for microphone permission');
      return await openAppSettings();
    } catch (e) {
      _logger.error('Error opening app settings', e);
      return false;
    }
  }

  /// Check if permission should show rationale (Android only)
  Future<bool> shouldShowRequestRationale() async {
    try {
      return await Permission.microphone.shouldShowRequestRationale;
    } catch (e) {
      _logger.error('Error checking if should show rationale', e);
      return false;
    }
  }
}

/// Enum representing different permission request results
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  error,
}