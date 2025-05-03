import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/widgets/home_page_screen.dart';
import 'package:mobile_speech_recognition/ui/core/themes/theme.dart';
import 'package:mobile_speech_recognition/utils/util.dart';
import 'package:mobile_speech_recognition/data/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  // This line is crucial - it ensures that platform channels are initialized

  await initializeApp();

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(), // Wrap your app
    ),
  );
}

Future<void> initializeApp() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  try {
    final dbService = DatabaseService();
    await dbService.database;
  } catch (e) {
    print('Error initializing database: $e');
  }

  print('App initialization completed');
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
    return brightness == Brightness.light ? theme.light() : theme.dark();
  }
}
