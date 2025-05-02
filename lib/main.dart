import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/widgets/home_page_screen.dart';
import 'package:mobile_speech_recognition/ui/core/themes/theme.dart';
import 'package:mobile_speech_recognition/utils/util.dart';

void main() => runApp(
  DevicePreview(
    enabled: true,
    builder: (context) => const MyApp(), // Wrap your app
  ),
);

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