// lib/utils/analysis_format_utils.dart
import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/utils/language_map.dart';

/// Utility class for formatting analysis results
class AnalysisFormatUtils {
  static const Map<String, String> genderLabels = {
    'M': 'Male',
    'F': 'Female',
    'MALE': 'Male',
    'FEMALE': 'Female',
    'Unknown': 'Unknown',
  };

  static const Map<String, String> emotionLabels = {
    'angry': 'Angry',
    'disgust': 'Disgust',
    'fear': 'Fear',
    'happy': 'Happy',
    'neutral': 'Neutral',
    'sad': 'Sad',
    'surprise': 'Surprise',
    'Unknown': 'Unknown',
  };

  /// Get display color for status
  static Color getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'pending':
        // Use amber/orange which is more visible than yellow
        return colorScheme.tertiary;
      case 'completed':
        return colorScheme.primary;
      case 'failed':
        return colorScheme.error;
      default:
        return colorScheme?.onSurfaceVariant ?? Colors.grey;
    }
  }

  /// Parse age result and return formatted string
  /// e.g. 25.5 → "26 years old"
  static String parseAgeResult(double? ageResult) {
    if (ageResult == null) return '--';
    return '${ageResult.round()} years old';
  }

  /// Parse gender result map and return the most likely one
  /// Handles various data formats and key variations
  static String parseGenderResult(Map<String, double>? genderResult) {
    if (genderResult == null || genderResult.isEmpty) {
      print('Gender result is null or empty');
      return '--';
    }

    print('Gender result data: $genderResult');

    // Find the Map entry with the maximum value
    final topEntry = genderResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    print('Top gender entry: ${topEntry.key} = ${topEntry.value}');

    // Handle different key formats and normalize them
    String normalizedKey = _normalizeGenderKey(topEntry.key);
    
    print('Normalized gender key: $normalizedKey');

    // Return mapped label or normalized key
    final result = genderLabels[normalizedKey] ?? normalizedKey;
    print('Final gender result: $result');
    
    return result;
  }

  /// Normalize gender keys to handle various formats
  static String _normalizeGenderKey(String key) {
    final normalizedKey = key.trim().toUpperCase();
    
    // Handle various gender key formats
    if (normalizedKey == 'M' || normalizedKey == 'MALE' || normalizedKey == 'MAN') {
      return 'M';
    } else if (normalizedKey == 'F' || normalizedKey == 'FEMALE' || normalizedKey == 'WOMAN') {
      return 'F';
    } else {
      // Return the original key if no match found
      return normalizedKey;
    }
  }

  /// Parse nationality result map and return the most likely one with expanded language name
  /// e.g. { 'ita': 80.0, 'fra': 12.0 } → 'Italian'
  static String parseNationalityResult(Map<String, double>? natResult) {
    if (natResult == null || natResult.isEmpty) return '--';

    print('Nationality result data: $natResult');

    // Find the Map entry with the maximum value
    final topEntry = natResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    print('Top nationality entry: ${topEntry.key} = ${topEntry.value}');

    // Use the language mapping to get the expanded name
    final result = LanguageMap.getLanguageNameWithFallback(
      topEntry.key, 
      fallback: '--'
    );
    
    print('Final nationality result: $result');
    
    return result;
  }

  /// Parse emotion result map and return the most likely one
  /// e.g. { 'happy': 0.8, 'neutral': 0.15 } → 'Happy'
  static String parseEmotionResult(Map<String, double>? emotionResult) {
    if (emotionResult == null || emotionResult.isEmpty) {
      print('Emotion result is null or empty');
      return '--';
    }

    print('Emotion result data: $emotionResult');

    // Find the Map entry with the maximum value
    final topEntry = emotionResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    print('Top emotion entry: ${topEntry.key} = ${topEntry.value}');

    // Normalize the emotion key and get the display label
    final normalizedKey = topEntry.key.trim().toLowerCase();
    final result = emotionLabels[normalizedKey] ?? topEntry.key;
    
    print('Final emotion result: $result');
    
    return result;
  }

  /// Parse combined age and gender for display
  /// Returns a formatted string like "26 years old, Male"
  static String parseAgeGenderResult(double? ageResult, Map<String, double>? genderResult) {
    final age = parseAgeResult(ageResult);
    final gender = parseGenderResult(genderResult);
    
    if (age == '--' && gender == '--') return '--';
    if (age == '--') return gender;
    if (gender == '--') return age;
    
    return '$age, $gender';
  }

  /// Get the top N nationality results with expanded names
  /// Returns a list of language names sorted by confidence
  static List<MapEntry<String, double>> getTopNationalityResults(
    Map<String, double>? natResult, 
    {int topN = 3}
  ) {
    if (natResult == null || natResult.isEmpty) return [];

    // Sort by confidence (descending) and take top N
    final sortedEntries = natResult.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries.take(topN).toList();
  }

  /// Get the top N emotion results sorted by confidence
  static List<MapEntry<String, double>> getTopEmotionResults(
    Map<String, double>? emotionResult,
    {int topN = 3}
  ) {
    if (emotionResult == null || emotionResult.isEmpty) return [];

    // Sort by confidence (descending) and take top N
    final sortedEntries = emotionResult.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries.take(topN).toList();
  }

  /// Get nationality result with confidence percentage
  /// e.g. "Italian (85.2%)"
  static String parseNationalityResultWithConfidence(Map<String, double>? natResult) {
    if (natResult == null || natResult.isEmpty) return '--';

    final topEntry = natResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final languageName = LanguageMap.getLanguageNameWithFallback(
      topEntry.key, 
      fallback: '--'
    );
    
    final confidence = (topEntry.value).toStringAsFixed(1);
    return '$languageName ($confidence%)';
  }

  /// Get emotion result with confidence percentage
  static String parseEmotionResultWithConfidence(Map<String, double>? emotionResult) {
    if (emotionResult == null || emotionResult.isEmpty) return '--';

    final topEntry = emotionResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final normalizedKey = topEntry.key.trim().toLowerCase();
    final emotionName = emotionLabels[normalizedKey] ?? topEntry.key;
    
    final confidence = (topEntry.value * 100).toStringAsFixed(1);
    return '$emotionName ($confidence%)';
  }

  /// Format date in a user-friendly way
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      // Today, show time
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 2) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // Within a week
      const List<String> weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final weekday = weekdays[date.weekday - 1];
      return weekday;
    } else {
      // Older than a week
      return '${date.day} ${getMonthName(date.month)} ${date.year}';
    }
  }

  /// Get month name abbreviation from month number (1-12)
  static String getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Get icon for gender code or display text
  /// Handles both codes (M/F) and display text (Male/Female)
  static IconData getGenderIcon(String genderText) {
    final normalized = genderText.toUpperCase();
    
    if (normalized.contains('F') || normalized.contains('FEMALE') || normalized.contains('WOMAN')) {
      return Icons.female;
    } else if (normalized.contains('M') || normalized.contains('MALE') || normalized.contains('MAN')) {
      return Icons.male;
    }
    return Icons.person;
  }

  /// Get icon for nationality/language code
  static IconData getNationalityIcon(String code) {
    return Icons.public;
  }

  /// Get icon for emotion
  static IconData getEmotionIcon(String emotion) {
    final normalized = emotion.toLowerCase();
    
    switch (normalized) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_very_dissatisfied;
      case 'angry':
        return Icons.sentiment_dissatisfied;
      case 'fear':
        return Icons.sentiment_neutral;
      case 'surprise':
        return Icons.sentiment_satisfied;
      case 'disgust':
        return Icons.sentiment_dissatisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.mood;
    }
  }

  /// Convert sendStatus code to display string
  static String getStatusText(int sendStatus) {
    switch (sendStatus) {
      case 0: // PENDING
        return 'Pending';
      case 1: // SENT/COMPLETED
        return 'Completed';
      case 2: // ERROR
        return 'Failed';
      default:
        return 'Unknown';
    }
  }
}