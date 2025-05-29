// lib/services/exception_handler.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';

class GlobalExceptionHandler {
  static final GlobalExceptionHandler _instance = GlobalExceptionHandler._internal();
  factory GlobalExceptionHandler() => _instance;
  GlobalExceptionHandler._internal();
  final LoggerService _loggerService = LoggerService();

  bool _isInitialized = false;

  /// Initialize global exception handling
  void initialize() {
    if (_isInitialized) return;

    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Handle errors from other isolates
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStacktrace = pair;
      final error = errorAndStacktrace.first;
      final stackTrace = errorAndStacktrace.last;
      await _handleIsolateError(error, stackTrace);
    }).sendPort);

    // Handle uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true; // Handled
    };

    _isInitialized = true;
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    // Log the error using the logger service
    _loggerService.error(
      'Flutter framework error: ${details.summary}',
      details.exception,
      details.stack,
    );

    // In debug mode, also print to console with Flutter's default handler
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Handle isolate errors
  Future<void> _handleIsolateError(dynamic error, StackTrace stackTrace) async {
    _loggerService.error(
      'Isolate error occurred',
      error,
      stackTrace,
    );

  }

  /// Handle platform/uncaught async errors
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _loggerService.error(
      'Uncaught platform error',
      error,
      stackTrace,
    );
    return true; // Error handled
  }
}