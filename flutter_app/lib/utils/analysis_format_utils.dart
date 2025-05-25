// lib/utils/analysis_format_utils.dart
import 'package:flutter/material.dart';

/// Utility class for formatting analysis results across the app
class AnalysisFormatUtils {
  /// Maps for gender codes to display labels
  static const Map<String, String> genderLabels = {
    'M': 'Male',
    'F': 'Female',
    'Unknown': 'Unknown',
  };

  /// Maps for nationality codes to display labels
  static const Map<String, String> nationalityLabels = {
    'IT': 'Italian',
    'FR': 'French',
    'EN': 'English',
    'ES': 'Spanish',
    'DE': 'German',
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
  /// e.g. { 'M': 85.0, 'F': 15.0 } → 'Male'
  static String parseGenderResult(Map<String, double>? genderResult) {
    if (genderResult == null || genderResult.isEmpty) return '--';

    // Find the Map entry with the maximum value
    final topEntry = genderResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    // Return mapped label or raw key
    return genderLabels[topEntry.key] ?? topEntry.key;
  }

  /// Parse nationality result map and return the most likely one
  /// e.g. { 'IT': 80.0, 'FR': 12.0 } → 'Italian'
  static String parseNationalityResult(Map<String, double>? natResult) {
    if (natResult == null || natResult.isEmpty) return '--';

    // Find the Map entry with the maximum value
    final topEntry = natResult.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    // Return mapped label or raw key
    return nationalityLabels[topEntry.key] ?? topEntry.key;
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

  /// Get icon for gender code
  static IconData getGenderIcon(String genderCode) {
    if (genderCode.contains('F') || genderCode.toLowerCase() == 'female') {
      return Icons.female;
    } else if (genderCode.contains('M') || genderCode.toLowerCase() == 'male') {
      return Icons.male;
    }
    return Icons.person;
  }

  /// Get icon for nationality code
  static IconData getNationalityIcon(String code) {
    return Icons.public;
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