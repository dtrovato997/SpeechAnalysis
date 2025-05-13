// lib/utils/analysis_format_utils.dart
import 'package:flutter/material.dart';

/// Utility class for formatting analysis results across the app
class AnalysisFormatUtils {
  /// Maps for age and gender codes to display labels
  static const Map<String, String> ageGenderLabels = {
    'YF': 'Young Female',
    'YM': 'Young Male',
    'F': 'Female',
    'M': 'Male',
    'C': 'Child',
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

  /// Common helper to pick the top entry from a Map and map its key via [labels].
  static String _parseTopFromMap(
    Map<String, double>? results,
    Map<String, String> labels,
  ) {
    if (results == null || results.isEmpty) return '--';

    // Find the Map entry with the maximum value
    final topEntry = results.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    // Return mapped label or raw key
    return labels[topEntry.key] ?? topEntry.key + topEntry.value.toStringAsFixed(2);
  }

  /// Parse age/gender result map and return the most likely one
  /// e.g. { 'YF': 85.0, 'YM': 15.0 } → 'Young Female'
  static String parseAgeGenderResult(Map<String, double>? ageResult) {
    return _parseTopFromMap(ageResult, ageGenderLabels);
  }

  /// Parse nationality result map and return the most likely one
  /// e.g. { 'IT': 80.0, 'FR': 12.0 } → 'Italy'
  static String parseNationalityResult(Map<String, double>? natResult) {
    return _parseTopFromMap(natResult, nationalityLabels);
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

  /// Get icon for age/gender code
  static IconData getAgeGenderIcon(String code) {
    if (code.contains('F')) {
      return Icons.female;
    } else if (code.contains('M')) {
      return Icons.male;
    } else if (code.contains('C')) {
      return Icons.child_care;
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
