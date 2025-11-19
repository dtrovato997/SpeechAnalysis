// lib/services/logger_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  late Logger _logger;
  bool _isInitialized = false;
  File? _logFile;

  /// Initialize the logger service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create log file
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('${logDir.path}/app_$dateString.log');

      // Initialize logger with multiple outputs
      _logger = Logger(
        filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
        printer: PrettyPrinter(
          methodCount: 1,
          errorMethodCount: 20,
          lineLength: 120,
          colors: true,
          printEmojis: false,
          dateTimeFormat: DateTimeFormat.dateAndTime,
        ),
        output: MultiOutput([
          ConsoleOutput(), // Console output
          FileOutput(file: _logFile!), // File output
        ]),
      );

      _isInitialized = true;
      
      // Test log
      _logger.i('Logger service initialized successfully');
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize logger: $e');
      }
    }
  }

  /// Get the logger instance
  Logger get logger {
    if (!_isInitialized) {
      // Create a basic logger if not initialized
      return Logger(
        printer: SimplePrinter(),
        output: ConsoleOutput(),
      );
    }
    return _logger;
  }

  /// Log debug messages (only in debug mode)
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info messages
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error messages
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal error messages
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log with custom level
  void log(Level level, String message, [dynamic error, StackTrace? stackTrace]) {
    logger.log(level, message, error: error, stackTrace: stackTrace);
  }

}

/// Custom file output for logger
class FileOutput extends LogOutput {
  final File file;
  
  FileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final buffer = StringBuffer();
      
      for (final line in event.lines) {
        // Remove ANSI color codes for file output
        final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
        buffer.writeln('[$timestamp] $cleanLine');
      }
      
      file.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to write to log file: $e');
      }
    }
  }
}