import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/services.dart';
import 'package:mobile_speech_recognition/data/repositories/audio_analysis_repository.dart';
import 'package:mobile_speech_recognition/data/repositories/tag_repository.dart';
import 'package:mobile_speech_recognition/data/services/audio_analysis_local_service.dart';
import 'package:mobile_speech_recognition/services/exception_handler_service.dart';
import 'package:mobile_speech_recognition/services/logger_service.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/widgets/home_page_screen.dart';
import 'package:mobile_speech_recognition/ui/core/themes/theme.dart';
import 'package:mobile_speech_recognition/utils/util.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  await initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioAnalysisRepository>(
          create: (_) => AudioAnalysisRepository(),
        ),

        ChangeNotifierProvider<TagRepository>(
          create: (_) => TagRepository(),
        ),
      ],
      child: DevicePreview(
        enabled: kDebugMode,
        builder: (context) => const MyApp(),
      ),
    ),
  );
}

Future<void> initializeApp() async {
  final logger = LoggerService();
  
  try {
    // Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Initialize audio analysis local service
    final inferenceService = LocalInferenceService();
    await inferenceService.initialize();
  
    // Initialize logger first
    await logger.initialize();
    logger.info('🚀 Starting Speech Recognition App');

    // Initialize global exception handler
    GlobalExceptionHandler().initialize();

    // Initialize database
    try {
      final dbService = DatabaseService();
      await dbService.database;
      logger.info('✅ Database initialized successfully');
    } catch (e, stackTrace) {
      logger.error('❌ Error initializing database', e, stackTrace);
      rethrow; // Critical error - app cannot function without database
    }

    logger.info('✅ App initialization completed successfully');
  } catch (e, stackTrace) {
    logger.fatal('💥 Critical error during app initialization', e, stackTrace);
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context), // Add the locale
      useInheritedMediaQuery: true,
      title: 'Speech Recognition App',
      theme: _buildTheme(context), // Use our custom theme function
      home: const HomePage(),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);

    // Use with Google Fonts package to use downloadable fonts
    TextTheme textTheme = createTextTheme(context, "Montserrat", "Montserrat");

    MaterialTheme theme = MaterialTheme(textTheme);

    // Use the light or dark theme based on platform brightness
    return theme.light();
  }
}
